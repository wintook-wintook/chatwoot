# frozen_string_literal: true

# Campaña con IA — Encuesta por CORREO: en el correo va la primera pregunta con botones (0 a 10 si la pregunta es
# de calificación; si no, «Contestar la encuesta»). Cada botón abre /encuesta/:token (Public::CampaignSurveysController):
# ahí confirma y contesta las demás (abrir la liga no guarda nada: los antivirus las abren solos).
# El token va firmado: lleva el seguimiento y la calificación elegida.
module TrackingCampaigns::SurveyLink
  SCORE = /\b[01]\s*(al|a|-)\s*10\b/i

  module_function

  def append(campaign, tracking, text)
    return text unless survey_email?(campaign, tracking)

    question = Array(campaign.brief.to_h['survey_questions']).first.to_s
    return text if question.blank? || host.blank?

    "#{text}\n\n#{buttons(question, tracking)}"
  end

  def survey_email?(campaign, tracking) = campaign&.motor2? && campaign.brief.to_h['kind'] == 'survey' && tracking.inbox&.email?

  def buttons(question, tracking)
    return "**#{question}**\n\n[Contestar la encuesta](#{url(tracking, nil)})" unless question.match?(SCORE)

    from = question.match?(/\b1\s*(al|a|-)\s*10\b/i) ? 1 : 0
    "**#{question}**\n\n#{(from..10).map { |n| "[#{n}](#{url(tracking, n)})" }.join(' · ')}"
  end

  def url(tracking, score) = "#{host}/encuesta/#{verifier.generate([tracking.id, score])}"

  # [tracking_id, score] o nil si el token no es válido.
  def read(token) = verifier.verified(token.to_s)

  def verifier = Rails.application.message_verifier(:campaign_survey)

  def host = ENV.fetch('FRONTEND_URL', '').chomp('/')
end
