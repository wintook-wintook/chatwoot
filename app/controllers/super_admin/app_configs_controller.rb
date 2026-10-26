class SuperAdmin::AppConfigsController < SuperAdmin::ApplicationController
  before_action :set_config
  before_action :allowed_configs
  def show
    # ref: https://github.com/rubocop/rubocop/issues/7767
    # rubocop:disable Style/HashTransformValues
    @app_config = InstallationConfig.where(name: @allowed_configs)
                                    .pluck(:name, :serialized_value)
                                    .map { |name, serialized_value| [name, serialized_value['value']] }
                                    .to_h
    # rubocop:enable Style/HashTransformValues
    @installation_configs = ConfigLoader.new.general_configs.each_with_object({}) do |config_hash, result|
      result[config_hash['name']] = config_hash.except('name')
    end
  end

  def create
    params['app_config'].each do |key, value|
      next unless @allowed_configs.include?(key)

      i = InstallationConfig.where(name: key).first_or_create(value: value, locked: false)
      i.value = value
      i.save!
    end
    redirect_to super_admin_settings_path, notice: "App Configs - #{@config.titleize} updated successfully"
  end

  private

  def set_config
    @config = params[:config] || 'general'
  end

  # Como en Chatwoot 4.19: una tabla en vez de un `case` que crece con cada canal.
  ALLOWED_CONFIGS = {
    'facebook' => %w[FB_APP_ID FB_VERIFY_TOKEN FB_APP_SECRET IG_VERIFY_TOKEN FACEBOOK_API_VERSION ENABLE_MESSENGER_CHANNEL_HUMAN_AGENT],
    # Canal de TikTok. Grupo aparte: sus credenciales no tienen nada que ver con las de Meta.
    'tiktok' => %w[TIKTOK_APP_ID TIKTOK_APP_SECRET TIKTOK_API_VERSION],
    # Canal nativo de Instagram. Grupo aparte para no tocar el de facebook.
    # IG_VERIFY_TOKEN y ENABLE_MESSENGER_CHANNEL_HUMAN_AGENT aparecen en ambos
    # grupos a propósito: son la misma fila de InstallationConfig y gobiernan
    # las dos rutas, así que no pueden desincronizarse.
    'instagram' => %w[INSTAGRAM_APP_ID INSTAGRAM_APP_SECRET INSTAGRAM_VERIFY_TOKEN IG_VERIFY_TOKEN INSTAGRAM_API_VERSION
                      ENABLE_MESSENGER_CHANNEL_HUMAN_AGENT],
    'microsoft' => %w[AZURE_APP_ID AZURE_APP_SECRET],
    'email' => ['MAILER_INBOUND_EMAIL_DOMAIN'],
    'unoapi' => %w[UNOAPI_AUTH_TOKEN],
    # proyecto@waba_chatwoot
    'whatsapp_embedded' => %w[WHATSAPP_EMBEDDED_FACEBOOK_APP_ID WHATSAPP_EMBEDDED_FACEBOOK_APP_SECRET
                              WHATSAPP_EMBEDDED_FACEBOOK_CONFIG_ID WHATSAPP_EMBEDDED_FACEBOOK_API_VERSION
                              WABA_EMBEDDED_SIGNUP]
  }.freeze
  GENERAL_CONFIGS = %w[ENABLE_ACCOUNT_SIGNUP FIREBASE_PROJECT_ID FIREBASE_CREDENTIALS].freeze

  def allowed_configs
    @allowed_configs = ALLOWED_CONFIGS.fetch(@config, GENERAL_CONFIGS)
  end
end

SuperAdmin::AppConfigsController.prepend_mod_with('SuperAdmin::AppConfigsController')
