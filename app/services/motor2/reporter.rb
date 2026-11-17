# frozen_string_literal: true

# Motor 2.0 — lo que el entrenador no puede corregir le llega a Kontrolya: queda en la lista de
# Super Admin (Motor 2.0 › Reportes) y, si hay correo configurado (MOTOR2_REPORTS_EMAIL), se manda.
# Si ya hay uno igual abierto del mismo agente, se suma a ese.
class Motor2::Reporter
  def initialize(template, user)
    @template = template
    @user = user
  end

  # data: kind:, turns:, reply:, expected:, diagnosis:, trace:
  def call(**data)
    report = Motor2Report.create!(account: @template.account, tracking_template: @template, user: @user, kind: data[:kind],
                                  turns: Array(data[:turns]).last(30), reply: data[:reply].to_s.first(4000),
                                  expected: data[:expected].to_s.first(2000), diagnosis: data[:diagnosis].to_s.first(1000),
                                  trace: data[:trace].to_h.slice('tools', 'sources', 'events'))
    Motor2ReportMailer.with(report: report).reported.deliver_later if ENV['MOTOR2_REPORTS_EMAIL'].present?
    report
  end
end
