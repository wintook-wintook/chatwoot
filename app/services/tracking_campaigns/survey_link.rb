# frozen_string_literal: true

# Campaña con IA — Encuesta por CORREO: en el correo va la primera pregunta con botones (0 a 10 si la pregunta es
# de calificación; si no, «Contestar la encuesta»). Cada botón abre /encuesta/:token (Public::CampaignSurveysController):
# ahí confirma y contesta las demás (abrir la liga no guarda nada: los antivirus las abren solos).
# El token va firmado: lleva el seguimiento y la calificación elegida.
module TrackingCampaigns::SurveyLink
  SCORE = /\b[01]\s*(al|a|-)\s*(10|5)\b/i

  # De dónde a dónde va la calificación de esa pregunta: 0..10, 1..10 o 1..5 (nil si no es de calificación).
  def self.range(question)
    match = question.to_s.match(SCORE)
    return unless match

    match[0].start_with?('1') ? 1..match[2].to_i : 0..match[2].to_i
  end

  module_function

  def append(campaign, tracking, text)
    return text unless survey_email?(campaign, tracking)

    question = Array(campaign.brief.to_h['survey_questions']).first.to_s
    return text if question.blank? || host.blank?

    "#{text}\n\n#{buttons(question, tracking)}"
  end

  def survey_email?(campaign, tracking) = campaign&.motor2? && campaign.brief.to_h['kind'] == 'survey' && tracking.inbox&.email?

  def buttons(question, tracking)
    scale = range(question)
    return "**#{question}**\n\n[Contestar la encuesta](#{url(tracking, nil)})" unless scale

    "**#{question}**\n\n#{scale.map { |n| "[#{n}](#{url(tracking, n)})" }.join(' · ')}"
  end

  def url(tracking, score) = "#{host}/encuesta/#{verifier.generate([tracking.id, score])}"

  # [tracking_id, score] o nil si el token no es válido.
  def read(token) = verifier.verified(token.to_s)

  def verifier = Rails.application.message_verifier(:campaign_survey)

  def host = ENV.fetch('FRONTEND_URL', '').chomp('/')
end
