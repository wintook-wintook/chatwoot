# frozen_string_literal: true

# ================================================================================
# proyecto@diagrama_agente_ia — F3: LA PILA GUARDADA DE UN AGENTE
# ================================================================================
# Plan: docs/diagrama_agente_ia_plan.md §6 y §9.1 (D5). Lo que antes era una corrida
# suelta en la caché (TestBattery) ahora es la pila del agente (TrackingTestCase):
#
#   generate     las de ruta y de regla que falten (TestBatteryScenarios); generar otra
#                vez no duplica (source_key)
#   run_dry      TODA la pila en seco contra un texto (TestCasesDryJob): ruta, fuente,
#                fragmentos. Sin redactar. Es lo que corre solo al publicar.
#   run_live     las elegidas en vivo (TestBatteryJob con case_ids): el agente guardado
#                contesta en el canal de pruebas y el resultado vuelve a cada prueba.
#
# EL AVANCE DE LA CORRIDA EN SECO vive en la caché por agente (`dry_key`): la pantalla
# del agente se vuelve a montar al publicar, así que el panel la retoma al abrirse.
#
# AL PUBLICAR (D5): en seco siempre y sobre todo; en vivo solo lo que se ofrece
# (`live_candidates`: cambió de camino, ya estaba en rojo o está fijada), con OK.
# ================================================================================

module ContactTrackings::Assistant::TestCases
  TTL = 2.days
  # Tope de pruebas que se ofrecen en vivo de una vez al publicar (D5: tope por publicación).
  MAX_LIVE_OFFER = 10

  module_function

  def dry_key(template_id) = "assistant/test_cases/#{template_id}/dry"

  def generate(account, template, brief: nil)
    escenarios = ContactTrackings::Assistant::TestBatteryScenarios.new(account, template: template, brief: brief).call
    existentes = template.test_cases.where.not(source_key: nil).pluck(:source_key)
    posicion = template.test_cases.maximum(:position).to_i
    nuevos = escenarios.reject { |e| existentes.include?(e.id) }
    nuevos.each_with_index.map { |e, i| from_scenario(account, template, e, posicion + i + 1) }.select(&:persisted?)
  end

  def from_scenario(account, template, escenario, posicion)
    template.test_cases.create(account: account, message: escenario.message.to_s.truncate(500), kind: escenario.kind,
                               source_key: escenario.id, expected_route: escenario.route, rule: escenario.rule,
                               check_text: escenario.check, position: posicion)
  end

  def add_own(account, template, message)
    template.test_cases.create(account: account, message: message.to_s.strip.truncate(500), kind: 'propia',
                               check_text: 'Que conteste bien y según su Entrenamiento.',
                               position: template.test_cases.maximum(:position).to_i + 1)
  end

  # La firma del camino en seco: dos corridas con la misma firma tomaron el mismo camino.
  # Se mira si trajo fragmentos, no cuáles ni con qué similitud: eso cambia con cualquier
  # edición del corpus y no es «otro camino».
  def dry_path(informe)
    informe = informe.deep_stringify_keys
    fuente = informe['source'] || {}
    [informe.dig('routes', 'chosen'), fuente['mode'], fuente['source_name'], fuente['reason'],
     Array(fuente['items']).any?, informe.dig('case', 'creates') == true, informe['tag']].map(&:to_s).join('|')
  end

  def run_dry(account, template, draft:, inbox: nil, trigger: 'manual')
    casos = template.test_cases.ordered.pluck(:id)
    return nil if casos.empty?

    estado = { 'status' => 'queued', 'trigger' => trigger, 'total' => casos.size, 'done' => 0, 'changed' => [],
               'started_at' => Time.current.iso8601 }
    Rails.cache.write(dry_key(template.id), estado, expires_in: TTL)
    ContactTrackings::Assistant::TestCasesDryJob.perform_later(account.id, template.id, draft.to_s, inbox&.id, trigger)
    estado
  end

  def dry_status(template)
    Rails.cache.read(dry_key(template.id))
  end

  # Al publicar: en seco toda la pila, contra lo que se acaba de guardar. Sin pila, nada.
  def after_publish(account, template)
    run_dry(account, template, draft: template.complementary_prompt, inbox: template.inbox, trigger: 'publish')
  rescue StandardError => e
    Rails.logger.warn "[TestCases] no se pudo correr la pila al publicar: #{e.message}"
    nil
  end

  def run_live(account, template, case_ids:)
    ids = template.test_cases.where(id: Array(case_ids)).ordered.pluck(:id)
    return nil if ids.empty?

    ContactTrackings::Assistant::TestBattery.start(account, template, case_ids: ids)
  end

  # Lo que vale la pena correr en vivo después de publicar: cambió de camino en seco, ya
  # estaba en rojo, o está fijada. Las que cambiaron primero.
  def live_candidates(template)
    casos = template.test_cases.ordered.to_a
    elegidos = casos.select(&:dry_changed?) + casos.select(&:live_failed?) + casos.select(&:pinned)
    elegidos.uniq.first(MAX_LIVE_OFFER)
  end

  # Tokens estimados para correr `casos` en vivo: lo que costó cada una la última vez o, si
  # nunca corrió, el promedio de las que sí.
  def estimate_tokens(template, casos)
    medidos = template.test_cases.filter_map { |c| c.last_live['tokens'].to_i.nonzero? }
    promedio = medidos.any? ? (medidos.sum / medidos.size) : nil
    total = casos.sum { |c| c.last_live['tokens'].to_i.nonzero? || promedio.to_i }
    total.positive? ? total : nil
  end

  # El resultado en vivo de una prueba de la pila (lo llama TestBatteryJob).
  def store_live(account, id, fila)
    caso = TrackingTestCase.find_by(id: id, account_id: account.id)
    return if caso.nil?

    traza = fila[:traza] || fila['traza']
    caso.store_live!(fila.stringify_keys.slice('reply', 'cumple', 'motivo', 'fallas', 'ruta_ok', 'conversation', 'cases')
                         .merge('traza' => traza, 'tokens' => traza.is_a?(Hash) ? traza.dig('uso', 'tokens').to_i : 0))
  end

  def as_json_for(caso)
    { id: caso.id, message: caso.message, kind: caso.kind, expected_route: caso.expected_route, rule: caso.rule,
      pinned: caso.pinned, last_dry: caso.last_dry, previous_dry: caso.previous_dry, last_live: caso.last_live,
      previous_live: caso.previous_live, dry_changed: caso.dry_changed? }
  end
end
