# frozen_string_literal: true

# Asistente (Dali) — el nombre y los modelos los pone cada cuenta (Ajustes); por defecto «Dali».
module Assistant::Settings
  DEFAULT_NAME = 'Dali'
  MAX_NAME = 30

  def self.name_for(account)
    account.custom_attributes&.dig('assistant_name').presence || DEFAULT_NAME
  end

  # Modelo de OpenAI de Dali: uno general (entender y proponer) y otro para ANÁLISIS (cuando explica
  # cifras de ventas). Desde el 2026-11-19 los define el código para todas las cuentas (AiModels): ya
  # no se eligen por cuenta (lo guardado en assistant_model / assistant_analysis_model se ignora).
  def self.model_for(_account, kind = :general)
    kind.to_s == 'analysis' ? AiModels::DALI_ANALYSIS : AiModels::DALI
  end

  # La tabla informativa de Ajustes: qué modelo usa cada grupo.
  def self.models(_account) = { groups: AiModels.table }

  def self.update_name!(account, name)
    clean = name.to_s.squish.first(MAX_NAME)
    account.custom_attributes = (account.custom_attributes || {}).merge('assistant_name' => clean.presence)
    account.save!
    name_for(account)
  end
end
