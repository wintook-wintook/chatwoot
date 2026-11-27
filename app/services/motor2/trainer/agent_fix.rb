# frozen_string_literal: true

# Motor 2.0 — el entrenador corrige la ficha del agente (instrucciones, «nunca», bienvenida o
# datos del negocio). Antes de aplicar corre las pruebas que pasaban con el cambio; si alguna se
# rompe, no lo aplica y lo dice. Si aplica, deja versión (para Deshacer).
class Motor2::Trainer::AgentFix
  TEXT_FIELDS = %w[instructions never welcome].freeze

  def initialize(template, user, cause)
    @template = template
    @user = user
    @cause = cause
  end

  def call
    return { message: skill_message } if @cause['field'] == 'skill'

    motor2 = changed_motor2
    return nil unless motor2

    draft = Motor2::AgentForm.new(@template.account, { 'motor2' => motor2 }, user: @user, template: @template.dup).build
    broken = Motor2::TestRunner.new(@template).broken_by(draft)
    return { message: broken_message(broken) } if broken.any?

    before = Motor2Version.where(tracking_template_id: @template.id).ordered.first
    Motor2::AgentForm.new(@template.account, { 'motor2' => motor2 }, user: @user, template: @template, source: 'trainer',
                                                                     note: @cause['summary']).save
    { message: applied_message(before), agent: Motor2::AgentJson.call(@template.reload) }
  end

  private

  # Un agente de función (Atención a prospectos…) se edita con su asistente, que solo enseña
  # «Indicaciones»: todo lo que corrige el entrenador va ahí (un dato del negocio, como un renglón).
  def field
    key = @cause['field'].to_s.presence_in(TEXT_FIELDS + ['business'])
    key && @template.try(:function_title) ? 'instructions' : key
  end

  def changed_motor2
    motor2 = @template.motor2.to_h.deep_dup
    return nil unless field
    return add_business(motor2) if field == 'business'

    business_as_text if @cause['field'] == 'business'
    edit_text(motor2)
  end

  def business_as_text
    @cause = @cause.merge('find' => '', 'replace' => [@cause['label'], @cause['value']].map { |v| v.to_s.strip }.compact_blank.join(': '))
  end

  def edit_text(motor2)
    text = motor2[field].to_s
    find = @cause['find'].to_s
    replace = @cause['replace'].to_s.strip
    return nil if replace.blank?

    @before = text
    motor2[field] = replace?(text, find) ? text.sub(find, replace) : [text.presence, replace].compact.join("\n")
    @after = motor2[field]
    motor2
  end

  # Solo se reemplaza una frase concreta; si lo que quiere reemplazar es casi todo el campo, se
  # agrega (para no perder las demás indicaciones).
  def replace?(text, find)
    find.present? && text.include?(find) && find.length < text.length * 0.6
  end

  def add_business(motor2)
    label = @cause['label'].to_s.strip
    value = @cause['value'].to_s.strip
    return nil if label.blank? || value.blank?

    same, rows = Array(motor2['business']).partition { |r| r.to_h['label'].to_s.casecmp?(label) }
    @before = same.first&.dig('value').to_s
    @after = value
    motor2.merge('business' => rows + [{ 'label' => label, 'value' => value }])
  end

  def applied_message(before)
    { kind: 'agent', field: field, before: @before, after: @after, summary: @cause['summary'],
      undo_version_id: before&.id,
      text: "Ya lo corregí#{": #{summary}" if summary.present?}. Pruébalo de nuevo." }
  end

  def summary
    @cause['summary'].to_s.strip.sub(/[.\s]+\z/, '')
  end

  # La habilidad existe pero está apagada o sin datos: eso lo prende el usuario en «Qué hace».
  def skill_message
    key = @cause['skill'].to_s.presence_in(Motor2::Skills::CATALOG.keys)
    { kind: 'skill', skill: key,
      text: "Esto lo hace una habilidad del agente#{": #{summary}" if summary.present?}. Se arregla en Qué hace." }
  end

  def broken_message(broken)
    { kind: 'agent_blocked', field: field, after: @after,
      text: "Tenía un cambio, pero rompe #{broken.size == 1 ? 'la prueba' : 'las pruebas'} " \
            "#{broken.map { |t| "«#{t.name}»" }.join(', ')}, que ya pasaban, así que no lo apliqué." }
  end
end
