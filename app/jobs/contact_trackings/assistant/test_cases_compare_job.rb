# frozen_string_literal: true

# ================================================================================
# proyecto@diagrama_agente_ia — F5: LA MISMA PILA CONTRA DOS VERSIONES
# ================================================================================
# Cada prueba de la pila en seco contra el texto de una versión guardada del agente
# (TrackingTemplateVersion#snapshot) y contra el borrador actual: qué pruebas toman otro
# camino entre las dos. Solo en seco: en vivo siempre contesta el agente guardado, así que
# «la v11 en vivo» no existe sin restaurarla.
#
# No toca last_dry/previous_dry de las pruebas: es una consulta, no una corrida de la
# pila. El resultado vive en la caché (TestCases.compare_key), como el avance en seco.
# ================================================================================

class ContactTrackings::Assistant::TestCasesCompareJob < ApplicationJob
  queue_as :low

  TestCases = ContactTrackings::Assistant::TestCases

  def perform(account_id, template_id, version_id, draft, inbox_id = nil)
    @account = Account.find(account_id)
    @template = @account.tracking_templates.find(template_id)
    @inbox = inbox_id && @account.inboxes.find_by(id: inbox_id)
    viejo = @template.versions.find(version_id).snapshot['complementary_prompt'].to_s
    resultados = compare_all(viejo, draft.to_s)
    save!('status' => 'done', 'results' => resultados, 'finished_at' => Time.current.iso8601)
  rescue StandardError => e
    Rails.logger.error "[TestCasesCompare] #{e.class}: #{e.message}"
    save!('status' => 'failed') if @template
  end

  private

  def compare_all(viejo, actual)
    casos = @template.test_cases.ordered.to_a
    casos.each_with_index.with_object({}) do |(caso, i), resultados|
      antes = summary(caso, viejo)
      ahora = summary(caso, actual)
      resultados[caso.id.to_s] = { 'version' => antes, 'draft' => ahora, 'same' => antes['path'] == ahora['path'] }
      save!('status' => 'running', 'done' => i + 1, 'total' => casos.size, 'results' => resultados)
    end
  end

  def summary(caso, texto)
    pregunta, contexto = TestCases.dry_inputs(caso)
    resultado = ContactTrackings::Assistant::DryRunService.new(@account, draft: texto, question: pregunta, inbox: @inbox,
                                                                         recent_context: contexto).call
    return { 'path' => 'error' } unless resultado.success?

    informe = resultado.payload.deep_stringify_keys
    { 'path' => TestCases.dry_path(informe), 'route' => informe.dig('routes', 'chosen'), 'informe' => informe }
  rescue StandardError => e
    Rails.logger.warn "[TestCasesCompare] prueba ##{caso.id}: #{e.message}"
    { 'path' => 'error' }
  end

  def save!(cambios)
    clave = TestCases.compare_key(@template.id)
    Rails.cache.write(clave, (Rails.cache.read(clave) || {}).merge(cambios), expires_in: TestCases::TTL)
  end
end
