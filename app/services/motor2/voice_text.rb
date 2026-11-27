# frozen_string_literal: true

# Motor 2.0 — los mensajes que arma el código (recordatorio de la cita, «¿pudiste revisar la cotización?», «te
# comunico con Ana…») con la voz de la empresa o del agente (Motor2::Config#voice: tono, palabras, firma, nunca).
# Solo reescribe la forma: mismos datos, misma pregunta, nada nuevo. Sin voz (o si falla), el texto tal cual.
#
#   Motor2::VoiceText.call(config, '¡Hola! Te recuerdo tu cita…') → el mismo mensaje con su tono y firma
class Motor2::VoiceText < Cases::Ai::BaseService
  USED = %w[tone signature words never].freeze
  SYSTEM = <<~TEXT
    Reescribes un mensaje corto de una empresa a su cliente por WhatsApp para que suene como ASÍ HABLA LA EMPRESA:
    su tono, sus palabras y su firma (si la tiene). No cambies datos (fechas, horas, folios, nombres, montos), no quites
    la pregunta y no agregues nada nuevo. Devuelve solo el mensaje.
  TEXT

  def self.call(config, text)
    voice = config.voice.slice(*USED).compact_blank
    return text if voice.empty? || text.blank?

    new(account: config.account).rewrite(text, voice).presence || text
  end

  def rewrite(text, voice)
    style = voice.map { |k, v| "- #{AgentBase::CompanyVoice::FIELDS[k]}: #{v}" }.join("\n")
    chat(system: SYSTEM, user: "ASÍ HABLA LA EMPRESA:\n#{style}\n\nMENSAJE:\n#{text}", temperature: 0.2, max_tokens: 300).to_s.strip
  rescue StandardError => e
    Rails.logger.warn("[Motor2::VoiceText] #{e.class}: #{e.message}")
    nil
  end

  private

  def model = AiModels::REVIEW
end
