# frozen_string_literal: true

# Campaña con Vendedor IA — «Cómo atiende»: la campaña arma su propio agente (un «Vendedor de campaña» con
# campaign_owned, que no sale en las listas de agentes). Para el motor es un agente 2.0 como cualquier otro.
#
#   attend { display_name, sources [], email_signature,
#            settings { tone, voice, voice_mode, business_*, price_source, quote, follow_up, attend_hours,
#                       appointment_notice, appointment_user_ids, appointment_minutes, instructions } }
#   (la oferta, sus objeciones, a quién pasa el interesado y los archivos de la oferta son de la campaña: brief y files)
#
#   TrackingCampaigns::CampaignAgent.new(campaign, user).save!(attend) → el agente (y la campaña ya ligada)
#   TrackingCampaigns::CampaignAgent.attend(template)  → lo de «Cómo atiende» para la pantalla
#   TrackingCampaigns::CampaignAgent.defaults(account) → para una campaña nueva: lo de la última campaña o de inicio
class TrackingCampaigns::CampaignAgent
  KIND = Motor2::Functions::CampaignSeller::KEY
  SETTINGS = %w[tone voice voice_mode business_what business_who business_coverage business_why business_practical
                business_mode price_source quote follow_up attend_hours appointment_notice appointment_user_ids
                appointment_minutes instructions].freeze

  def initialize(campaign, user)
    @campaign = campaign
    @user = user
    @account = campaign.account
  end

  def save!(attend)
    attend = Motor2::Sanitizer.plain(attend.presence || self.class.defaults(@account))
    template = Motor2::Functions::Form.new(@account, form_params(attend), user: @user, template: own_template).save
    template.update_columns(campaign_owned: true) unless template.campaign_owned # rubocop:disable Rails/SkipsModelValidations
    @campaign.update_columns(tracking_template_id: template.id, objective: template.objective) if @campaign.tracking_template_id != template.id # rubocop:disable Rails/SkipsModelValidations
    template
  end

  # Lo de la pantalla puesto en una copia del agente, sin guardar (el chat «Probar» de la campaña).
  def draft(attend)
    current = @campaign.tracking_template
    base = current&.campaign_owned? ? current.dup.tap { |c| c.draft_of = current.id } : nil
    attend = Motor2::Sanitizer.plain(attend.presence || self.class.defaults(@account))
    Motor2::Functions::Form.new(@account, form_params(attend), user: @user, template: base).build
  end

  # Para «Duplicar» y «Otra campaña con…»: la copia arma el suyo con lo mismo (no comparten agente).
  def copy_from!(source)
    save!(source ? self.class.attend(source) : nil)
  end

  def self.attend(template)
    return nil unless template

    json = Motor2::Functions::AgentJson.call(template)
    { 'display_name' => json[:display_name].to_s, 'sources' => json[:sources], 'email_signature' => template.email_signature.to_s,
      'settings' => json[:settings].to_h.slice(*SETTINGS) }
  end

  # Lo de la última campaña de la cuenta; si no hay, lo de inicio (la voz de la empresa y todas sus fuentes).
  def self.defaults(account)
    last = account.tracking_campaigns.real.where(engine: '2').joins(:tracking_template)
                  .where(tracking_templates: { campaign_owned: true }).order(updated_at: :desc).first
    attend(last&.tracking_template) || starter(account)
  end

  def self.starter(account)
    sources = Motor2::SourceMap.new(account).available
    catalog = sources.any? { |s| s[:kind].to_s == 'catalog' || s['kind'].to_s == 'catalog' }
    { 'display_name' => '', 'email_signature' => '', 'sources' => sources.map { |s| s[:key] || s['key'] },
      'settings' => { 'tone' => 'empresa', 'voice_mode' => 'company', 'price_source' => catalog ? 'catalog' : 'canned',
                      'quote' => { 'mode' => catalog ? 'draft' : 'off', 'follow_days' => 3 },
                      'follow_up' => { 'nudges' => 2, 'templates' => [], 'template_days' => 2 }, 'attend_hours' => 1,
                      'appointment_notice' => { 'on' => true, 'template' => '' }, 'appointment_user_ids' => [],
                      'appointment_minutes' => 30 } }
  end

  private

  # El suyo; si la campaña no tiene, o el que tiene lo comparte con otra o es un vendedor de Agentes listos, uno nuevo.
  def own_template
    current = @campaign.tracking_template
    return nil unless current&.campaign_owned?
    return nil if TrackingCampaign.real.where(tracking_template_id: current.id).where.not(id: @campaign.id).exists?

    current
  end

  def form_params(attend)
    brief = @campaign.brief.to_h
    settings = attend['settings'].to_h.slice(*SETTINGS)
                                 .merge('purpose' => brief['kind'], 'relay' => brief['relay'].presence || 'agent',
                                        'user_id' => brief['relay_user_id'], 'team_id' => brief['relay_team_id'])
    { 'kind' => KIND, 'name' => "Campaña #{@campaign.id} · #{@campaign.name}".first(100), 'display_name' => attend['display_name'].to_s,
      'enabled' => false, 'sources' => Array(attend['sources']),
      'channel' => { 'inbox_id' => @campaign.inbox_id, 'email_signature' => attend['email_signature'].to_s }, 'settings' => settings }
  end
end
