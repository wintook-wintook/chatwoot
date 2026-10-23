# frozen_string_literal: true

# ================================================================================
# diag/llamadas_whatsapp (F6) — LA PESTAÑA «LLAMADAS» DE UNA BANDEJA DE WHATSAPP
# ================================================================================
#   GET   inboxes/:inbox_id/whatsapp_call_settings   lo que hay + estado en Meta
#   PATCH inboxes/:inbox_id/whatsapp_call_settings   { enabled, direction, ring_strategy, ringtone,
#           recording_enabled, recording_notice, call_permission_request_body,
#           missed_call_actions[], missed_call_label, missed_call_case_type_id,
#           missed_call_campaign_id, missed_call_auto_reply }   (F8)
#
# Solo administradores y solo bandejas whatsapp_cloud. Prender (o cambiar el tipo, que
# cambia si el cliente ve el botón de llamar) habla con Meta — o con la Meta simulada —
# por Channel::Whatsapp#enable_voice_calling!; si Meta lo rechaza: 422 con su mensaje.
# Lo demás se guarda en provider_config sin tocar Meta.
# ================================================================================
class Api::V1::Accounts::Inboxes::WhatsappCallSettingsController < Api::V1::Accounts::BaseController
  RING_STRATEGIES = %w[cascade all_online].freeze
  # Tonos del timbre (helper/whatsappCallRingtone.js); el primero es el de omisión.
  RINGTONES = %w[marimba classic digital bell].freeze
  MAX_TEXT = 1024

  before_action :set_channel, :ensure_administrator, :ensure_supported

  def show
    render json: settings_json(meta_status: meta_status)
  end

  def update
    apply_enabled_and_direction
    @channel.update_columns(provider_config: @channel.provider_config.merge(other_settings)) # rubocop:disable Rails/SkipsModelValidations
    render json: settings_json
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_channel
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    @channel = @inbox.channel
  end

  def ensure_administrator
    render json: { error: I18n.t('errors.unauthorized') }, status: :unauthorized unless Current.account_user&.administrator?
  end

  def ensure_supported
    return if @channel.is_a?(Channel::Whatsapp) && @channel.voice_calling_supported?

    render json: { error: I18n.t('errors.whatsapp.calls.not_supported') }, status: :unprocessable_entity
  end

  # Prender, apagar, o cambiar el tipo estando prendidas (cambia el botón en Meta).
  def apply_enabled_and_direction
    prendidas = @channel.provider_config['calling_enabled'] == true
    quiere = params.key?(:enabled) ? ActiveModel::Type::Boolean.new.cast(params[:enabled]) : prendidas

    if quiere && (!prendidas || requested_direction != @channel.calling_direction)
      @channel.enable_voice_calling!(direction: requested_direction)
    elsif !quiere && prendidas
      @channel.disable_voice_calling!
    end
    @channel.reload
  end

  def requested_direction
    Channel::Whatsapp::CALLING_DIRECTIONS.include?(params[:direction]) ? params[:direction] : @channel.calling_direction
  end

  def other_settings
    cambios = choice_settings
    cambios['recording_enabled'] = ActiveModel::Type::Boolean.new.cast(params[:recording_enabled]) if params.key?(:recording_enabled)
    %w[recording_notice call_permission_request_body missed_call_label missed_call_auto_reply].each do |llave|
      cambios[llave] = params[llave].to_s.strip.first(MAX_TEXT) if params.key?(llave)
    end
    cambios.merge(missed_call_settings)
  end

  # Las que solo aceptan un valor de su lista.
  def choice_settings
    { 'ring_strategy' => RING_STRATEGIES, 'ringtone' => RINGTONES }.each_with_object({}) do |(llave, validos), cambios|
      cambios[llave] = params[llave] if validos.include?(params[llave])
    end
  end

  # F8: qué hacer con una llamada perdida (Calls::MissedCallService).
  def missed_call_settings
    cambios = {}
    if params.key?(:missed_call_actions)
      cambios['missed_call_actions'] = Calls::MissedCallService::ACTIONS & Array(params[:missed_call_actions]).map(&:to_s)
    end
    { 'missed_call_case_type_id' => Current.account.case_types, 'missed_call_campaign_id' => Current.account.tracking_campaigns }
      .each do |llave, opciones|
      cambios[llave] = opciones.find_by(id: params[llave])&.id if params.key?(llave)
    end
    cambios
  end

  # Lo que se puede elegir en la pestaña para la llamada perdida.
  def missed_call_options
    {
      labels: Current.account.labels.order(:title).pluck(:title),
      case_types: Current.account.case_types.order(:position).map { |tipo| { id: tipo.id, name: tipo.name } },
      campaigns: Current.account.tracking_campaigns.order(created_at: :desc).map { |c| { id: c.id, name: c.name, status: c.status } }
    }
  end

  # Lo que dice Meta del número (o la simulada). nil si no se pudo leer.
  def meta_status
    @channel.calls_provider.calling_settings
  rescue StandardError => e
    Rails.logger.warn "[WHATSAPP CALL] no se pudo leer la configuración en Meta: #{e.message}"
    nil
  end

  def settings_json(meta_status: nil)
    config = @channel.provider_config
    {
      feature_enabled: Current.account.feature_enabled?('whatsapp_calls'),
      enabled: config['calling_enabled'] == true,
      direction: @channel.calling_direction,
      ring_strategy: RING_STRATEGIES.include?(config['ring_strategy']) ? config['ring_strategy'] : 'cascade',
      ringtone: RINGTONES.include?(config['ringtone']) ? config['ringtone'] : RINGTONES.first,
      recording_enabled: @channel.recording_enabled?,
      recording_notice: config['recording_notice'].to_s,
      call_permission_request_body: config['call_permission_request_body'].to_s,
      default_permission_body: I18n.t('conversations.messages.whatsapp.call_permission_request_body'),
      default_recording_notice: I18n.t('conversations.messages.whatsapp.call_recording_notice'),
      calls_webhook: config['calls_webhook'],
      simulator: Whatsapp::Providers::CallsSimulator.enabled?,
      meta_status: meta_status
    }.merge(missed_call_json(config))
  end

  def missed_call_json(config)
    {
      missed_call_actions: Array(config['missed_call_actions']),
      missed_call_label: config['missed_call_label'].to_s,
      missed_call_case_type_id: config['missed_call_case_type_id'],
      missed_call_campaign_id: config['missed_call_campaign_id'],
      missed_call_auto_reply: config['missed_call_auto_reply'].to_s,
      default_missed_call_label: Calls::MissedCallService::DEFAULT_LABEL,
      default_missed_call_auto_reply: I18n.t('conversations.messages.whatsapp.missed_call_auto_reply'),
      missed_call_options: missed_call_options
    }
  end
end
