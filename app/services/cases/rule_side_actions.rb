# frozen_string_literal: true

# Reglas de casos (Cases::RuleEngineService) — las acciones que actúan fuera del caso:
#
#   notify_agent     (correo, nombre o id del usuario) → aviso en su campanita
#   add_label        (nombre de la etiqueta)           → etiqueta a la conversación del caso
#   trigger_tracking (nombre o id de la plantilla)     → arranca ese seguimiento en la
#                                                         conversación del caso (si el contacto
#                                                         no tiene uno vivo en ese canal)
#
# Las de conversación usan ActionService, lo mismo que Automatización. Sin conversación
# ligada no hacen nada. Devuelven true si hicieron algo.
module Cases::RuleSideActions
  private

  def run_side_action(type, value)
    case type
    when 'notify_agent' then notify_rule_user(value)
    when 'add_label' then add_rule_label(value)
    when 'trigger_tracking' then start_rule_tracking(value)
    end
  end

  def notify_rule_user(value)
    user = find_rule_user(value)
    return false unless user

    title = @ticket.title.to_s.truncate(120)
    text = I18n.with_locale(@ticket.account.locale.presence || I18n.default_locale) do
      I18n.t('notifications.case_stages.rule_notice', rule: @rule&.name.to_s, title: title)
    end
    NotificationBuilder.new(notification_type: 'case_rule_notice', user: user, account: @ticket.account,
                            primary_actor: @ticket, meta: { task_title: text, rule_id: @rule&.id }).perform
    true
  end

  def add_rule_label(value)
    label = @ticket.account.labels.find_by('LOWER(title) = ?', value.to_s.strip.downcase)
    return false unless label && @ticket.conversation

    ActionService.new(@ticket.conversation).add_label([label.title])
    true
  end

  def start_rule_tracking(value)
    templates = @ticket.account.tracking_templates
    template = templates.find_by('LOWER(name) = ?', value.to_s.strip.downcase) || templates.find_by(id: value.to_s[/\A\d+\z/])
    return false unless template && @ticket.conversation

    ActionService.new(@ticket.conversation).assign_tracking_template([template.id])
    true
  end

  def find_rule_user(value)
    text = value.to_s.strip
    users = @ticket.account.users
    users.find_by('LOWER(email) = ?', text.downcase) || users.find_by(name: text) || users.find_by(id: text[/\A\d+\z/])
  end
end
