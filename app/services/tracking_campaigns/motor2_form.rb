# frozen_string_literal: true

# Campaña con Vendedor IA — guardar lo que llega del asistente (Motor2CampaignWizard) en una TrackingCampaign
# engine '2'. Nace Guardada (saved); ponerla en curso es TrackingCampaigns::Launch, como la 1.0.
#
#   params: name, tracking_template_id (un «Vendedor de campaña»), inbox_id (WhatsApp o correo), mode batch|continuous,
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
    error = seller_error || inbox_error
    return { error: error } if error

    @campaign.assign_attributes(attributes)
    return { error: @campaign.errors.full_messages.to_sentence } unless @campaign.save

    { campaign: @campaign }
  end

  def self.sellers(account)
    account.tracking_templates.where(agent_function: Motor2::Functions::CampaignSeller::KEY, archived_at: nil).order(:name)
  end

  def self.inboxes(account) = account.inboxes.where(channel_type: CHANNELS).order(:name)

  private

  def seller
    @seller ||= self.class.sellers(@account).find_by(id: @params[:tracking_template_id])
  end

  def inbox
    @inbox ||= self.class.inboxes(@account).find_by(id: @params[:inbox_id])
  end

  def seller_error = seller ? nil : 'Elige el Vendedor de campaña que va a atender.'

  def inbox_error = inbox ? nil : 'Elige el canal: una bandeja de WhatsApp o de correo.'

  def attributes
    brief = TrackingCampaigns::Motor2Brief.brief(@params[:brief])
    { name: @params[:name].to_s.strip.presence || 'Campaña sin nombre', tracking_template: seller, inbox: inbox,
      objective: seller.objective, mode: @params[:mode].to_s.presence_in(TrackingCampaign::MODES) || 'batch',
      purpose: 'prospecting', brief: brief, touches: TrackingCampaigns::Motor2Brief.touches(@params[:touches]),
      audience: audience }.merge(window, event(brief), subjects)
  end

  def audience
    raw = Motor2::Sanitizer.plain(@params[:audience])
    { 'source' => raw['source'].presence, 'filter_payload' => Array(@params.dig(:audience, :filter_payload)).map { |c| c.to_h.deep_stringify_keys },
      'excluded_contact_ids' => Array(raw['excluded_contact_ids']).map(&:to_i).uniq,
      'contact_ids' => Array(raw['contact_ids']).map(&:to_i).uniq.first(ContactTrackings::BulkAssignService::MAX_BULK_ASSIGN),
      'skip_active' => true }.compact
  end

  def window
    { scheduled_for: time(@params[:scheduled_for]) || Time.current, ends_at: time(@params[:ends_at]),
      entry_delay_minutes: @params[:entry_delay_minutes].to_i.clamp(0, 10_080),
      respect_working_hours: ActiveModel::Type::Boolean.new.cast(@params.fetch(:respect_working_hours, true)),
      daily_cap: @params[:daily_cap].presence&.to_i&.clamp(1, 10_000),
      stop_when_not_interested: true, stop_when_wrong_person: true, retry_not_now: true }
  end

  # Invitar: el evento de la oferta es también el de la campaña (sus asistentes, la audiencia).
  def event(brief)
    return { event_id: nil, event_status: nil } unless brief['kind'] == 'invite' && brief['event_id']

    Events::CampaignEvent.attributes(@account, { event_id: brief['event_id'], event_status: @params[:event_status] })
  end

  def subjects
    return { email_subject: nil, email_subject_b: nil } unless inbox.email?

    { email_subject: @params[:email_subject].to_s.strip.first(TrackingCampaigns::EmailSubject::MAX_LENGTH).presence,
      email_subject_b: @params[:email_subject_b].to_s.strip.first(TrackingCampaigns::EmailSubject::MAX_LENGTH).presence }
  end

  def time(value)
    value.present? ? Time.zone.parse(value.to_s) : nil
  rescue ArgumentError, TypeError
    nil
  end
end
