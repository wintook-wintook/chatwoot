# ================================================================================
# feat/licencias (F0) — EL INTERRUPTOR GENERAL
# ================================================================================
# «Aplicar licencias» en Super admin › Configuración › Licencias (InstallationConfig
# LICENSE_ENFORCEMENT_ENABLED). No va en .env (decisión 23/10/2026): se prende y apaga desde
# pantalla. Apagado = las licencias se registran pero no limitan ni suspenden nada, para poder
# desplegar cada fase sin que ninguna cuenta cambie.
#
# GlobalConfig lo guarda en caché; InstallationConfig la borra al guardar, así que el cambio
# surte efecto al momento.
# Plan: docs/licencias_plan_v1.md §8
# ================================================================================
module Licenses::Enforcement
  CONFIG_KEY = 'LICENSE_ENFORCEMENT_ENABLED'.freeze

  module_function

  def enabled?
    ActiveModel::Type::Boolean.new.cast(GlobalConfig.get(CONFIG_KEY)[CONFIG_KEY]) || false
  end
end
