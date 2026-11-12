# frozen_string_literal: true

# Base común de los agentes que le hablan a clientes (Seguimiento IA y Agentes listos; NO los
# Agentes a medida, que son otro motor): «Cómo habla tu empresa». Lo llena el administrador una
# vez y todos lo toman. Lo particular de cada agente o seguimiento manda sobre esto.
#
#   AgentBase::CompanyVoice.get(account)            → { 'who' => …, 'tone' => …, … }
#   AgentBase::CompanyVoice.update!(account, attrs)  → guarda (vacío = no se usa)
#   AgentBase::CompanyVoice.block(account, draft)    → el bloque para el prompt ('' si no hay nada)
#
# Vive en account.custom_attributes['ai_voice'].
module AgentBase::CompanyVoice
  FIELDS = {
    'who' => 'Quiénes somos',
    'tone' => 'Tono',
    'signature' => 'Cómo firmar o despedirse',
    'roles' => 'Quién es quién (contactos que no son clientes y cómo tratarlos)',
    'after_hours' => 'Fuera de horario, qué decir',
    'never' => 'Nunca',
    'words' => 'Palabras propias o a evitar'
  }.freeze
  MAX_CHARS = 600
  KEY = 'ai_voice'

  module_function

  def get(account)
    saved = account.custom_attributes.to_h[KEY].to_h
    FIELDS.keys.index_with { |key| saved[key].to_s }
  end

  def update!(account, attrs)
    clean = FIELDS.keys.index_with { |key| attrs.to_h.stringify_keys[key].to_s.strip.first(MAX_CHARS) }.compact_blank
    account.custom_attributes = account.custom_attributes.to_h.merge(KEY => clean)
    account.save!
    get(account)
  end

  # `draft`: lo que está en el formulario sin guardar (para «Probar»).
  def block(account, draft = nil)
    values = draft ? draft.to_h.stringify_keys : get(account)
    lines = FIELDS.filter_map { |key, label| "- #{label}: #{values[key].to_s.strip.first(MAX_CHARS)}" if values[key].present? }
    return '' if lines.empty?

    "CÓMO HABLA LA EMPRESA (general para todos sus agentes; lo particular de este agente o seguimiento manda):\n" \
      "#{lines.join("\n")}"
  end
end
