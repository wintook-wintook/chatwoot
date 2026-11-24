# frozen_string_literal: true

# Campaña con IA — la encuesta que se contesta desde el correo (TrackingCampaigns::SurveyLink), sin usuario.
#   GET  /encuesta/:token → las preguntas (la primera con la calificación del botón ya elegida)
#   POST /encuesta/:token → guarda las respuestas y cierra el seguimiento como en WhatsApp (nota, caso si es baja)
class Public::CampaignSurveysController < PublicController
  layout 'public_document'

  before_action :set_tracking
  around_action :use_account_locale

  def show; end

  def create
    answers = @questions.each_with_index.to_h do |_q, i|
      text = params.dig(:answers, i.to_s).to_s.strip.first(500)
      [(i + 1).to_s, { 'respuesta' => text, 'calificacion' => score_of(text) }.compact]
    end
    answers = answers.reject { |_k, v| v['respuesta'].blank? }
    return render(:show) if answers.empty?

    save!(answers)
    @done = true
    render :show
  end

  private

  def set_tracking
    tracking_id, @score = TrackingCampaigns::SurveyLink.read(params[:token])
    @tracking = ContactTracking.find_by(id: tracking_id) if tracking_id
    @campaign = @tracking&.tracking_campaign
    return render(plain: 'Not found', status: :not_found) unless @campaign&.motor2? && @campaign.brief.to_h['kind'] == 'survey'

    @account = @tracking.account
    @questions = Array(@campaign.brief.to_h['survey_questions'])
    @done = @tracking.motor2_state.to_h['survey'].present? && @tracking.status == 'objective_met'
  end

  def score_of(text) = text.match?(/\A\d{1,2}\z/) ? text.to_i.clamp(0, 10) : nil

  def save!(answers)
    state = @tracking.motor2_state.to_h.merge('survey' => answers)
    @tracking.update_columns(motor2_state: state, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    config = Motor2::Config.for(@tracking)
    function = config&.function
    return unless function.respond_to?(:outcomes)

    function.outcomes(@tracking, @tracking.conversation).apply('done', 'Contestó la encuesta (correo)')
  end

  def use_account_locale(&)
    I18n.with_locale(@account&.locale.presence || I18n.default_locale, &)
  end
end
