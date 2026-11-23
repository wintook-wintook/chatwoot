# frozen_string_literal: true

# Campaña con Vendedor IA (Motor 2.0) — la pantalla nueva (Motor2CampaignWizard / Motor2CampaignDetail). La 1.0
# (CampaignForm, tracking_campaigns y contact_tracking_bulk_assigns) no cambia. Pausar y reanudar son los de siempre
# (tracking_campaigns/:id/pause|resume).
#
#   GET   motor2_campaigns/options              vendedores, bandejas (WhatsApp/correo, con sus plantillas) y eventos
#   POST  motor2_campaigns/preview              a quién le llega { payload, template_id, inbox_id, excluded_contact_ids }
#   POST  motor2_campaigns/test                 «Probar» { template_id, brief, messages, state }
#   POST  motor2_campaigns/test_email           «Enviarme una prueba» { subject, body, template_id }
#   GET   motor2_campaigns/:id                  para editarla
#   POST  motor2_campaigns  · PATCH :id          guardar (nace y sigue Guardada; solo se modifica Guardada)
#   POST  motor2_campaigns/:id/list             subir una lista fría de correos (CSV) { file, name, cleanup_days }
#   GET   motor2_campaigns/:id/check            la revisión antes de lanzar
#   POST  motor2_campaigns/:id/launch           revisa y la pone en curso (TrackingCampaigns::Launch)
#   GET   motor2_campaigns/:id/results          el tablero · GET :id/contacts?group=… los de un grupo
#   POST  motor2_campaigns/:id/insights         «Qué dicen los contactos» (IA)
#   POST  motor2_campaigns/:id/follow_up        otra campaña Guardada con los de un grupo { group }
#   POST  motor2_campaigns/:id/duplicate        copia Guardada
#   POST  motor2_campaigns/:id/simulate         «Simular» la campaña para un contacto { contact_id } (sin mandar nada)
#   GET   motor2_campaigns/:id/test_run         «Prueba real»: cómo va · POST la arranca { recipients, every_minutes }
#   DELETE motor2_campaigns/:id/test_run        la termina (cancela los toques que falten)
class Api::V1::Accounts::Motor2CampaignsController < Api::V1::Accounts::BaseController
  before_action :set_campaign, except: %i[options preview test test_email create]

  def options
    render json: { sellers: TrackingCampaigns::Motor2Form.sellers(Current.account).map { |t| seller_json(t) },
                   inboxes: TrackingCampaigns::Motor2Form.inboxes(Current.account).map { |i| inbox_json(i) },
                   events: upcoming_events, past_events: recent_events, users: names(Current.account.users), teams: names(Current.account.teams) }
  end

  def preview
    result = ContactTrackings::BulkAssignPreviewService.new(
      account: Current.account, current_user: current_user, filter_payload: params.permit!['payload'] || [],
      template_id: params[:template_id], inbox_id: params[:inbox_id], excluded_contact_ids: params[:excluded_contact_ids] || []
    ).call
    render json: result, status: result[:error] ? :unprocessable_entity : :ok
  end

  def test
    seller = TrackingCampaigns::Motor2Form.sellers(Current.account).find(params[:template_id])
    answers = TrackingCampaigns::Motor2Brief.seller_answers(TrackingCampaign.new(brief: TrackingCampaigns::Motor2Brief.brief(params[:brief])))
    result = Motor2::Probe.new(seller, messages: test_messages, state: Motor2::Sanitizer.plain(params[:state]), answers: answers).call
    render json: result.merge(tools: Array(result.dig(:trace, 'tools'))), status: result[:error] ? :unprocessable_entity : :ok
  end

  def test_email
    seller = TrackingCampaigns::Motor2Form.sellers(Current.account).find_by(id: params[:template_id])
    body = Motor2::CampaignTouch.fill(params[:body].to_s.first(6000), Contact.new(name: current_user.name))
    Motor2CampaignMailer.test_touch(to: current_user.email, subject: params[:subject].to_s, body: body,
                                    signature: seller&.email_signature).deliver_later
    render json: { sent_to: current_user.email }
  end

  def show = render(json: campaign_json(@campaign))

  def create = render_form(TrackingCampaigns::Motor2Form.new(Current.account, current_user, form_params).save)

  def update
    return render_error('Solo se puede modificar una campaña Guardada.') unless @campaign.saved?

    render_form(TrackingCampaigns::Motor2Form.new(Current.account, current_user, form_params, campaign: @campaign).save)
  end

  # Subir una lista fría de correos (CSV) a una campaña Guardada (ProspectLists::Import).
  def list
    return render_error('Solo se puede subir a una campaña Guardada.') unless @campaign.saved?
    return render_error('Sube un archivo CSV.') if params[:file].blank?

    result = ProspectLists::Import.new(@campaign, current_user, params[:file], name: params[:name],
                                                                               cleanup_days: params[:cleanup_days].presence || 30).call
    return render_error(result[:error]) if result[:error]

    render json: { list: result[:list].summary, campaign: campaign_json(@campaign.reload) }
  end

  def check = render(json: { items: TrackingCampaigns::Motor2Check.new(@campaign).call })

  def launch
    check = TrackingCampaigns::Motor2Check.new(@campaign)
    return render(json: { error: 'Revisa los puntos en rojo antes de lanzar.', items: check.call }, status: :unprocessable_entity) unless check.ready?

    result = TrackingCampaigns::Launch.new(@campaign, current_user).call
    return render_error(result[:error]) if result[:error]

    render json: campaign_json(@campaign.reload).merge(queued: result[:queued])
  end

  def results = render(json: TrackingCampaigns::Motor2Results.new(@campaign).call.merge(campaign: campaign_json(@campaign)))

  def contacts = render(json: { contacts: TrackingCampaigns::Motor2Results.new(@campaign).contacts(params[:group]) })

  def insights = render(json: TrackingCampaigns::Motor2Insights.new(@campaign).call)

  def follow_up
    ids = TrackingCampaigns::Motor2Results.new(@campaign).contact_ids(params[:group])
    return render_error('No hay contactos en ese grupo.') if ids.empty?

    copy = copy_of(@campaign, name: params[:name].presence || "#{@campaign.name} — seguimiento",
                              audience: { 'source' => { 'type' => 'campaign', 'campaign_id' => @campaign.id, 'group' => params[:group] },
                                          'contact_ids' => ids, 'skip_active' => true })
    render json: campaign_json(copy)
  end

  def duplicate = render(json: campaign_json(copy_of(@campaign, name: "#{@campaign.name} (copia)")))

  def simulate
    contact = Current.account.contacts.find_by(id: params[:contact_id]) ||
              Contact.new(account: Current.account, name: current_user.name, email: current_user.email)
    render json: TrackingCampaigns::Motor2Simulation.new(@campaign, contact).call
  end

  def test_run = render(json: test_runner.status)

  def start_test_run
    result = test_runner.start(recipients: params.permit(recipients: %i[contact_id email phone])[:recipients],
                               every_minutes: params[:every_minutes])
    return render_error(result[:error]) if result[:error]

    render json: test_runner.status
  end

  def stop_test_run
    test_runner.stop
    render json: test_runner.status
  end

  private

  def set_campaign
    @campaign = Current.account.tracking_campaigns.real.where(engine: '2').find(params[:id])
  end

  def upcoming_events
    Current.account.events.where(closed_at: nil).where('starts_at > ?', Time.current).order(:starts_at)
           .limit(50).map { |e| { id: e.id, name: e.name, starts_at: e.starts_at, capacity: e.capacity } }
  end

  # Para la audiencia «asistentes de un evento» después del evento (asistió, no se presentó): los de 90 días.
  def recent_events
    Current.account.events.where(starts_at: 90.days.ago..Time.current).order(starts_at: :desc)
           .limit(50).map { |e| { id: e.id, name: e.name, starts_at: e.starts_at, capacity: e.capacity } }
  end

  # Para «Si le interesa, pasa a» de la campaña.
  def names(scope) = scope.order(:name).map { |r| { id: r.id, name: r.name } }

  def test_runner = @test_runner ||= TrackingCampaigns::Motor2TestRun.new(@campaign, current_user)

  ROLES = %w[user assistant].freeze
  COPY_FIELDS = %i[tracking_template_id inbox_id objective mode purpose brief touches respect_working_hours daily_cap
                   entry_delay_minutes email_subject email_subject_b event_id event_status engine].freeze
  FORM_KEYS = %i[name tracking_template_id inbox_id mode event_status scheduled_for ends_at entry_delay_minutes
                 respect_working_hours daily_cap email_subject email_subject_b].freeze

  def form_params
    params.permit(*FORM_KEYS).to_h.merge(brief: params[:brief]&.permit!.to_h, touches: params[:touches]&.permit!.to_h,
                                         audience: params[:audience]&.permit!.to_h)
  end

  def render_form(result)
    return render_error(result[:error]) if result[:error]

    render json: campaign_json(result[:campaign])
  end

  def render_error(message) = render(json: { error: message }, status: :unprocessable_entity)

  def copy_of(campaign, name:, audience: nil)
    Current.account.tracking_campaigns.create!(
      campaign.slice(*COPY_FIELDS)
              .merge(name: name.first(120), status: 'saved', user: current_user, scheduled_for: Time.current,
                     audience: audience || campaign.audience, brief: campaign.brief.to_h.except('insights'))
    )
  end

  def test_messages
    Array(params[:messages]).last(30).filter_map do |m|
      role = m[:role].to_s
      content = m[:content].to_s.strip.first(1500)
      { role: role, content: content } if ROLES.include?(role) && content.present?
    end
  end

  def campaign_json(campaign)
    campaign.slice(*%i[id name status mode engine brief touches audience scheduled_for ends_at entry_delay_minutes
                       respect_working_hours daily_cap email_subject email_subject_b event_id event_status tracking_template_id
                       inbox_id paused_reason paused_at created_at])
            .merge(seller_name: campaign.tracking_template&.name, inbox_name: campaign.inbox&.name,
                   channel: campaign.inbox&.whatsapp? ? 'whatsapp' : 'email', stats: campaign.stats)
  end

  def seller_json(template)
    answers = template.motor2.to_h['answers'].to_h
    { id: template.id, name: template.name, display_name: template.customer_display_name, email_signature: template.email_signature,
      relay: answers['relay'] || 'agent', appointments: Array(answers['appointment_user_ids']).any? }
  end

  def inbox_json(inbox)
    { id: inbox.id, name: inbox.name, channel_type: inbox.channel_type,
      templates: inbox.whatsapp? ? approved_templates(inbox) : [] }
  end

  # Las plantillas aprobadas, con su texto (para la vista del teléfono).
  def approved_templates(inbox)
    Array(inbox.channel.try(:message_templates)).select { |t| t['status'].to_s.casecmp('approved').zero? }.map { |t| template_json(t) }
  end

  def template_json(template)
    parts = Array(template['components']).index_by { |c| c['type'] }
    { name: template['name'], language: template['language'], category: template['category'],
      header: parts.dig('HEADER', 'text'), body: parts.dig('BODY', 'text'), footer: parts.dig('FOOTER', 'text'),
      buttons: Array(parts.dig('BUTTONS', 'buttons')).pluck('text') }
  end
end
