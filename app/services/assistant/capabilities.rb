# frozen_string_literal: true

# Asistente (Dali) — su alcance PARA ESTE USUARIO, según sus permisos (Access::Grant):
#   · `lines`: lo que puede pedir, para que el modelo conteste «¿en qué me ayudas?»;
#   · `starters`: preguntas de ejemplo para el saludo del panel;
#   · `shortcuts`: los botones fijos del portal de Dali en el teléfono (abren la plática ya encaminada).
# «Aprender a usar la plataforma» (guías de uso) va para todos.
# Ventas solo si tiene el área; con «solo lo suyo», dicho como «tus números».
module Assistant::Capabilities
  module_function

  def for(grant)
    keys = %w[consult record] + work_keys(grant)
    keys << (grant.own?(:sales) ? 'sales_own' : 'sales') if grant.allowed?(:sales)
    keys << 'quotes' if grant.writable?(:sales)
    keys << 'guide'
    { lines: keys.map { |k| I18n.t("assistant.capabilities.#{k}") } << I18n.t('assistant.capabilities.limits'),
      starters: starters(grant) }
  end

  # Casos, contestar, delegar y campo, según el rol.
  def work_keys(grant)
    keys = []
    keys << 'cases' if grant.case_area_allowed?
    keys << 'reply' if grant.writable?(:conversations)
    keys << 'delegate'
    keys << 'field' if grant.allowed?(:agenda)
    keys << 'client_tasks' if grant.case_area_allowed?
    keys << 'nfc' if grant.allowed?(:campaigns)
    keys
  end

  def starters(grant)
    list = [I18n.t('assistant.starters.today')]
    list << I18n.t('assistant.starters.sales_month') << I18n.t('assistant.starters.closing') if grant.allowed?(:sales)
    list << I18n.t('assistant.starters.how_to') if grant.allowed?(:agenda)
    list << I18n.t('assistant.starters.help')
    list
  end

  def shortcuts(grant)
    keys = %w[today]
    keys << 'reply' if grant.writable?(:conversations)
    keys << 'quote' if grant.writable?(:sales)
    keys << 'route' if grant.allowed?(:agenda)
    keys.push('meeting', 'note')
    keys << 'sales' if grant.allowed?(:sales)
    keys.map { |k| { key: k, label: I18n.t("assistant.shortcuts.#{k}.label"), prompt: I18n.t("assistant.shortcuts.#{k}.prompt") } }
  end
end
