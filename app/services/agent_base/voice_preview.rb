# frozen_string_literal: true

# «Probar» de «Cómo habla tu empresa»: un mensaje de ejemplo con lo del formulario (sin guardar),
# como lo escribiría el Seguimiento IA o el agente de prospectos. No manda nada.
class AgentBase::VoicePreview < Cases::Ai::BaseService
  SCENES = {
    'follow_up' => ['Eres el asistente de seguimiento: le escribes a un cliente a nombre de la empresa. Breve (1 a 4 frases), ' \
                    'cordial, una sola pregunta.',
                    'Escribe el primer mensaje para saber si el cliente revisó la cotización que se le envió hace 3 días.'],
    'prospects' => ['Eres el agente que atiende a prospectos nuevos de la empresa por WhatsApp. Breve, cordial, una sola pregunta.',
                    'Un prospecto nuevo escribió: «Hola, vi su anuncio, ¿me dan informes?». Contéstale.']
  }.freeze

  def initialize(account, draft, kind: nil)
    super(account: account)
    @draft = draft
    @kind = SCENES.key?(kind.to_s) ? kind.to_s : 'follow_up'
  end

  def call
    role, task = SCENES[@kind]
    system = [role, AgentBase::CompanyVoice.block(@account, @draft), "La empresa se llama #{@account.name}."].compact_blank.join("\n\n")
    chat(system: system, user: task, temperature: 0.4, max_tokens: 300)
  end
end
