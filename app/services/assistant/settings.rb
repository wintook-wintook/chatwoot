# frozen_string_literal: true

# Asistente (Dali) — el nombre y los modelos los pone cada cuenta (Ajustes); por defecto «Dali».
module Assistant::Settings
  DEFAULT_NAME = 'Dali'
  MAX_NAME = 30

  def self.name_for(account)
    account.custom_attributes&.dig('assistant_name').presence || DEFAULT_NAME
  end

  # Modelo de OpenAI: uno general (entender y proponer) y otro para ANÁLISIS (cuando
  # Dali explica cifras de ventas). Sin elegir: el de siempre (OPENAI_GPT_MODEL o
  # gpt-4o-mini); el de análisis, sin elegir, usa el general.
  MODELS = %w[gpt-4o-mini gpt-4.1-mini gpt-4o gpt-4.1].freeze

  def self.model_for(account, kind = :general)
    attrs = account.custom_attributes || {}
    general = attrs['assistant_model'].presence || ENV.fetch('OPENAI_GPT_MODEL', Cases::Ai::BaseService::DEFAULT_MODEL)
    kind.to_s == 'analysis' ? attrs['assistant_analysis_model'].presence || general : general
  end

  def self.models(account)
    attrs = account.custom_attributes || {}
    { model: attrs['assistant_model'].presence, analysis_model: attrs['assistant_analysis_model'].presence,
      available: MODELS, default: ENV.fetch('OPENAI_GPT_MODEL', Cases::Ai::BaseService::DEFAULT_MODEL) }
  end

  # nil o '' = volver al de siempre. Un modelo fuera de la lista se rechaza.
  def self.update_models!(account, model:, analysis_model:)
    [model, analysis_model].compact_blank.each do |value|
      raise ArgumentError, "Modelo no disponible: #{value}" unless MODELS.include?(value)
    end
    account.custom_attributes = (account.custom_attributes || {})
                                .merge('assistant_model' => model.presence, 'assistant_analysis_model' => analysis_model.presence)
    account.save!
    models(account)
  end

  def self.update_name!(account, name)
    clean = name.to_s.squish.first(MAX_NAME)
    account.custom_attributes = (account.custom_attributes || {}).merge('assistant_name' => clean.presence)
    account.save!
    name_for(account)
  end
end
