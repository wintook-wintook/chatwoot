# frozen_string_literal: true

# Motor 2.0 — avisos de los reportes del entrenador: a Kontrolya cuando llega uno
# (MOTOR2_REPORTS_EMAIL) y a quien lo reportó cuando se marca «corregido».
class Motor2ReportMailer < ApplicationMailer
  def reported
    @report = params[:report]
    mail(to: ENV.fetch('MOTOR2_REPORTS_EMAIL'), subject: "[Motor 2.0] #{@report.account.name}: #{@report.diagnosis.to_s.first(80)}")
  end

  def fixed
    @report = params[:report]
    return if @report.user&.email.blank?

    mail(to: @report.user.email, subject: "Ya quedó lo que reportaste del agente #{@report.tracking_template&.name}")
  end
end
