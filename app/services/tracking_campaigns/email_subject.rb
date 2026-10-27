# frozen_string_literal: true

# ================================================================================
# prospeccion F1 — EL ASUNTO DEL CORREO QUE ABRE EL AGENTE IA
# ================================================================================
# Plan: docs/prospeccion_estudio.md (§9, F1).
#
#   «{{contacto}}, una idea para {{empresa}}»  →  «Juan, una idea para Grúas del Norte»
#
#   {{contacto}} = primer nombre del contacto · {{empresa}} = su empresa.
#   Si falta un dato, la variable desaparece sin dejar «, ,» ni espacios dobles.
#   (No se usa {{nombre}}: en los agentes ya significa «adjunta el archivo».)
#
# Solo aplica en bandejas de correo y solo al ABRIR la conversación: si el contacto ya
# tenía hilo, se conserva su asunto y el mailer responde con «Re: …».
# ================================================================================
class TrackingCampaigns::EmailSubject
  MAX_LENGTH = 150

  def self.render(template, contact)
    new(template, contact).render
  end

  def initialize(template, contact)
    @template = template.to_s
    @contact = contact
  end

  def render
    text = @template.gsub(/\{\{\s*contacto\s*\}\}/i, first_name).gsub(/\{\{\s*empresa\s*\}\}/i, company)
    tidy(text).presence
  end

  private

  def first_name
    @contact&.name.to_s.strip.split(/\s+/).first.to_s
  end

  def company
    attrs = @contact&.additional_attributes || {}
    (attrs['company_name'].presence || attrs['company'].presence).to_s.strip
  end

  # «Hola , una idea» → «Hola, una idea» · «, una idea» → «Una idea»
  def tidy(text)
    text = text.gsub(/\s+([,.;:!?])/, '\1').gsub(/([,;:])(?=[,;:])/, '').squeeze(' ').strip
    stripped = text.sub(/\A[,.;:]+\s*/, '')
    text = stripped.sub(/\A./, &:upcase) if stripped != text
    text.truncate(MAX_LENGTH)
  end
end
