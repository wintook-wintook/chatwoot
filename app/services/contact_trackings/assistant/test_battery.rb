# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LA PILA DE PRUEBAS: ARRANCAR, LEER, INFORMAR (M5 de docs/importar_prompt_extenso_plan.md)
# ================================================================================
# El botón «Probar el agente» del Asistente (decisión D4: con botón, por costo). Arranca
# TestBatteryJob, lee su avance de la caché y arma el informe .md (la «evidencia», como la
# de las pruebas de Grúas).
# ================================================================================

module ContactTrackings::Assistant::TestBattery
  TTL = 2.days
  ID_RE = /\A[a-z0-9]{12,32}\z/

  module_function

  def key(id) = "assistant/test_battery/#{id}"

  # El canal donde se puede probar: API y sin webhook (un mensaje ahí no sale a ninguna parte).
  def sandbox_inbox(account)
    account.inboxes.where(channel_type: 'Channel::Api').find { |i| i.channel.webhook_url.blank? }
  end

  def start(account, template, brief: nil)
    id = SecureRandom.alphanumeric(16).downcase
    Rails.cache.write(key(id), { 'status' => 'queued', 'template' => template.name, 'template_id' => template.id,
                                 'started_at' => Time.current.iso8601 }, expires_in: TTL)
    ContactTrackings::Assistant::TestBatteryJob.perform_later(id, account.id, template.id, brief&.id)
    id
  end

  def read(id)
    return nil unless id.to_s.match?(ID_RE)

    Rails.cache.read(key(id))
  end

  def report(estado)
    resultados = Array(estado['results'])
    buenos = resultados.count { |r| r['cumple'] || r[:cumple] }
    lineas = ["# Pila de pruebas — #{estado['template']}", '',
              "#{estado['started_at']} · #{buenos} de #{resultados.size} cumplen", '',
              '| Prueba | Conv. | Cliente | Agente | Ruta | Cumple | Por qué |', '|---|---|---|---|---|---|---|']
    lineas + resultados.map { |r| row(r.stringify_keys) }
  end

  def row(fila)
    ruta = { true => '✅', false => '❌' }.fetch(fila['ruta_ok'], '—')
    celdas = [fila['id'], fila['conversation'], fila['message'], fila['reply'], ruta, fila['cumple'] ? '✅' : '❌',
              [fila['motivo'], *Array(fila['fallas'])].compact_blank.join(' · ')]
    "| #{celdas.map { |c| c.to_s.gsub(/\s+/, ' ').gsub('|', '\\|').truncate(400) }.join(' | ')} |"
  end
end
