# frozen_string_literal: true

# Asistente (Dali) — su alcance PARA ESTE USUARIO, según sus permisos (Access::Grant):
#   · `lines`: lo que puede pedir, para que el modelo conteste «¿en qué me ayudas?»;
#   · `starters`: preguntas de ejemplo para el saludo del panel.
# «Aprender a usar la plataforma» (guías de uso) va para todos.
# Ventas solo si tiene el área; con «solo lo suyo», dicho como «tus números».
module Assistant::Capabilities
  module_function

  def for(grant)
    keys = %w[consult record]
    keys << 'cases' if grant.case_area_allowed?
    keys << 'delegate'
    keys << (grant.own?(:sales) ? 'sales_own' : 'sales') if grant.allowed?(:sales)
    keys << 'guide'
    { lines: keys.map { |k| I18n.t("assistant.capabilities.#{k}") } << I18n.t('assistant.capabilities.limits'),
      starters: starters(grant) }
  end

  def starters(grant)
    list = [I18n.t('assistant.starters.today')]
    list << I18n.t('assistant.starters.sales_month') << I18n.t('assistant.starters.closing') if grant.allowed?(:sales)
    list << I18n.t('assistant.starters.how_to') if grant.allowed?(:agenda)
    list << I18n.t('assistant.starters.help')
    list
  end
end
