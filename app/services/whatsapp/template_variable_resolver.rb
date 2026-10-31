# frozen_string_literal: true

# ================================================================================
# feat/plantillas_variables_resolver F9.2 — DE UNA VARIABLE CON NOMBRE A SU DATO
# ================================================================================
# Plan: docs/plantillas_whatsapp_mejoras_plan.md §7.11 y §7.16. {{nombre}} es un campo reservado
# (D9a); cualquier otro nombre es la clave de un atributo personalizado, primero del contacto y
# luego de la conversación. Un reservado sin dato no busca atributos: el reservado gana siempre.
#
# Solo lee: no toca la base ni manda nada. Con un dato que no existe, la variable queda en
# `missing`, y quien la use decide (en automático no se manda, D9c). Las variables numeradas
# ({{1}}) no se reconocen por nombre: siempre salen en `missing`.
#
# Réplica en el navegador: dashboard/helper/whatsappTemplateVariables.js. Las dos pasan los mismos
# casos: spec/fixtures/whatsapp_template_variables.json.
# ================================================================================
class Whatsapp::TemplateVariableResolver
  RESERVED = {
    'nombre' => :full_name,
    'primer_nombre' => :first_name,
    'apellido' => :last_name,
    'correo' => :email,
    'telefono' => :phone,
    'empresa' => :company,
    'agente' => :agent_name,
    'conversacion' => :conversation_number,
    'bandeja' => :inbox_name,
    'fecha_hoy' => :today
  }.freeze
  DATE_FORMAT = '%d/%m/%Y'
  ONLY_DATE = /\A(\d{4})-(\d{2})-(\d{2})\z/
  DATE_TIME = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})\z/

  # Todo es opcional: una campaña puede no tener conversación todavía. La bandeja, si no se da,
  # es la de la conversación; el agente, el asignado.
  def initialize(contact: nil, conversation: nil, inbox: nil, agent: nil, now: Time.current)
    @contact = contact
    @conversation = conversation
    @inbox = inbox || conversation&.inbox
    @agent = agent || conversation&.assignee
    @now = now
  end

  # { values: { 'edad' => '34' }, missing: ['plan'] }, cada variable una vez.
  def resolve(keys)
    keys.uniq.each_with_object({ values: {}, missing: [] }) do |key, result|
      valor = value(key)
      valor.present? ? result[:values][key] = valor : result[:missing] << key
    end
  end

  # El texto que va en el mensaje, o nil si no hay dato.
  def value(key)
    return unless key.to_s.match?(Whatsapp::TemplateVariables::NAME)

    texto = RESERVED.key?(key) ? plain_text(send(RESERVED[key])) : attribute(key)
    texto.presence
  end

  private

  def attribute(key)
    [@contact, @conversation].lazy.map { |dueno| plain_text(dueno&.custom_attributes.to_h[key]) }.find(&:present?)
  end

  # Meta rechaza saltos de línea, tabuladores y varios espacios seguidos en una variable.
  def plain_text(value)
    case value
    when true then 'Sí'
    when false then 'No'
    when String, Numeric then date_text(value.to_s.squish)
    end
  end

  # Los atributos de tipo fecha se guardan como 2026-10-31T06:00:00.000Z.
  def date_text(text)
    return text.sub(ONLY_DATE, '\3/\2/\1') unless text.match?(DATE_TIME)

    Time.iso8601(text).in_time_zone(timezone).strftime(DATE_FORMAT)
  rescue ArgumentError
    text
  end

  # Sin letras (el nombre que quedó como teléfono) no es un nombre: no se le saluda con eso.
  def full_name
    nombre = @contact&.name.to_s.squish
    nombre if nombre.match?(/\p{L}/)
  end

  def first_name
    full_name&.split&.first
  end

  def last_name
    palabras = full_name.to_s.split
    palabras.last if palabras.size > 1
  end

  def email
    @contact&.email
  end

  def phone
    @contact&.phone_number
  end

  def company
    @contact&.additional_attributes.to_h['company_name']
  end

  def agent_name
    @agent&.available_name
  end

  def conversation_number
    @conversation&.display_id
  end

  def inbox_name
    @inbox&.name
  end

  def today
    @now.in_time_zone(timezone).strftime(DATE_FORMAT)
  end

  def timezone
    @inbox&.timezone.presence || 'UTC'
  end
end
