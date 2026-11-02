# frozen_string_literal: true

# Asistente (Dali) — el nombre lo pone cada cuenta (Ajustes); por defecto «Dali».
module Assistant::Settings
  DEFAULT_NAME = 'Dali'
  MAX_NAME = 30

  def self.name_for(account)
    account.custom_attributes&.dig('assistant_name').presence || DEFAULT_NAME
  end

  def self.update_name!(account, name)
    clean = name.to_s.squish.first(MAX_NAME)
    account.custom_attributes = (account.custom_attributes || {}).merge('assistant_name' => clean.presence)
    account.save!
    name_for(account)
  end
end
