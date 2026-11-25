# frozen_string_literal: true

# Campaña con Vendedor IA — guardar lo que llega del asistente (Motor2CampaignWizard) en una TrackingCampaign
# engine '2'. Nace Guardada (saved); ponerla en curso es TrackingCampaigns::Launch, como la 1.0.
#
#   params: name, attend { … } (cómo atiende: la campaña arma su agente, TrackingCampaigns::CampaignAgent),
#           inbox_id (WhatsApp o correo), mode batch|continuous,
#           brief {…}, touches {…} (TrackingCampaigns::Motor2Brief), audience { source, filter_payload,
#           excluded_contact_ids, contact_ids }, event_status, scheduled_for, ends_at, entry_delay_minutes,
#           respect_working_hours, daily_cap, email_subject, email_subject_b
#
#   TrackingCampaigns::Motor2Form.new(account, user, params, campaign: nil).save → { campaign: } | { error: }
class TrackingCampaigns::Motor2Form
  CHANNELS = %w[Channel::Whatsapp Channel::Email].freeze

  def initialize(account, user, params, campaign: nil)
    @account = account
    @user = user
    @params = params.to_h.with_indifferent_access
    @campaign = campaign || account.tracking_campaigns.new(engine: '2', user: user, status: 'saved')
  end

  def save
    error = inbox_error
    return { error: error } if error

    ActiveRecord::Base.transaction do
      @campaign.assign_attributes(attributes)
      raise ActiveRecord::Rollback unless @campaign.save

      save_agent
    end
    return { error: @campaign.errors.full_messages.to_sentence } if @campaign.errors.any? || !@campaign.persisted?

    { campaign: @campaign }
  end

  def self.sellers(account)
    account.tracking_templates.where(agent_function: Motor2::Functions::CampaignSeller::KEY, archived_at: nil).order(:name)
  end

  def self.inboxes(account) = account.inboxes.where(channel_type: CHANNELS).order(:name)

  private

  # «Cómo atiende»: lo que llegó o, si no llegó (campaña nueva sin tocar ese paso), lo de la última campaña.
  def save_agent
    return if @params[:attend].blank? && @campaign.tracking_template&.campaign_owned?

    TrackingCampaigns::CampaignAgent.new(@campaign, @user).save!(@params[:attend].presence&.to_h)
  end

  def inbox
    @inbox ||= self.class.inboxes(@account).find_by(id: @params[:inbox_id])
  end

  # Sin canal se guarda igual (la revisión antes de lanzar lo pide); uno que no es WhatsApp ni correo, no.
  def inbox_error
    return nil if @params[:inbox_id].blank? || inbox

    'Elige el canal: una bandeja de WhatsApp o de correo.'
  end

  def attributes
    brief = TrackingCampaigns::Motor2Brief.brief(@params[:brief])
    { name: @params[:name].to_s.strip.presence || 'Campaña sin nombre', inbox: inbox,
      mode: brief['renew_source'] ? 'continuous' : (@params[:mode].to_s.presence_in(TrackingCampaign::MODES) || 'batch'),
      purpose: 'prospecting', brief: brief, touches: TrackingCampaigns::Motor2Brief.touches(@params[:touches]),
      audience: audience }.merge(window(brief), event(brief), subjects)
  end

  def audience
    # Lista fría subida (ProspectLists::Import): sus contactos se quedan como los dejó la importación.
    return @campaign.audience if @campaign.audience.to_h.dig('source', 'type') == 'list' && list_source?

    raw = Motor2::Sanitizer.plain(@params[:audience])
    { 'source' => raw['source'].presence, 'filter_payload' => Array(@params.dig(:audience, :filter_payload)).map { |c| c.to_h.deep_stringify_keys },
      'excluded_contact_ids' => Array(raw['excluded_contact_ids']).map(&:to_i).uniq,
      'contact_ids' => Array(raw['contact_ids']).map(&:to_i).uniq.first(ContactTrackings::BulkAssignService::MAX_BULK_ASSIGN),
      'skip_active' => true }.compact
  end

  def list_source? = @params.dig(:audience, :source, :type).to_s == 'list'

  def window(brief)
    { scheduled_for: time(@params[:scheduled_for]) || Time.current, ends_at: time(@params[:ends_at]) || event_start(brief) || offer_end(brief),
      entry_delay_minutes: @params[:entry_delay_minutes].to_i.clamp(0, 10_080),
      respect_working_hours: ActiveModel::Type::Boolean.new.cast(@params.fetch(:respect_working_hours, true)),
      daily_cap: @params[:daily_cap].presence&.to_i&.clamp(1, 10_000),
      stop_when_not_interested: true, stop_when_wrong_person: true, retry_not_now: true }
  end

  # Invitar: el evento al que se invita es el de la campaña. El estado de asistentes solo cuenta si la audiencia son
  # los de ESE evento (si son los de otro evento —p. ej. los que fueron a la expo pasada— va en audience.source).
  def event(brief)
    return { event_id: nil, event_status: nil } unless brief['kind'] == 'invite' && brief['event_id']

    audience_event = @params.dig(:audience, :source, :event_id).presence
    status = audience_event.nil? || audience_event.to_i == brief['event_id'].to_i ? @params[:event_status] : nil
    Events::CampaignEvent.attributes(@account, { event_id: brief['event_id'], event_status: status })
  end

  # Ofrecer y Reactivar: sin fecha de fin, termina cuando vence la promoción.
  def offer_end(brief)
    TrackingCampaigns::OfferProducts.ends_at(brief['valid_until']) if %w[offer reactivate].include?(brief['kind'])
  end

  # Invitar: sin fecha de fin, termina cuando empieza el evento.
  def event_start(brief)
    return unless brief['kind'] == 'invite' && brief['event_id']

    @account.events.find_by(id: brief['event_id'])&.starts_at
  end

  def subjects
    return { email_subject: nil, email_subject_b: nil } unless inbox&.email?

    { email_subject: @params[:email_subject].to_s.strip.first(TrackingCampaigns::EmailSubject::MAX_LENGTH).presence,
      email_subject_b: @params[:email_subject_b].to_s.strip.first(TrackingCampaigns::EmailSubject::MAX_LENGTH).presence }
  end

  def time(value)
    value.present? ? Time.zone.parse(value.to_s) : nil
  rescue ArgumentError, TypeError
    nil
  end
end
