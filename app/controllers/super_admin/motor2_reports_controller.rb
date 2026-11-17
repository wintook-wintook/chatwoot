# frozen_string_literal: true

# Super Admin › Motor 2.0 — lo que el entrenador de los agentes 2.0 no pudo corregir (falta una
# habilidad o el motor no obedeció) en todas las empresas. Al marcar «corregido» se le avisa a
# quien lo reportó y se vuelven a correr las pruebas de ese agente.
#
#   GET   /super_admin/motor2_reports?status=&kind=
#   PATCH /super_admin/motor2_reports/:id   { status: new|reviewing|fixed|rejected }
class SuperAdmin::Motor2ReportsController < SuperAdmin::ApplicationController
  PER_PAGE = 50

  def index
    @status = params[:status].presence_in(Motor2Report::STATUSES) || 'new'
    @kind = params[:kind].presence_in(Motor2Report::KINDS)
    @counts = Motor2Report.group(:status).count
    scope = Motor2Report.where(status: @status)
    scope = scope.where(kind: @kind) if @kind
    @reports = scope.includes(:account, :user, :tracking_template).order(created_at: :desc).page(params[:page]).per(PER_PAGE)
    @same = Motor2Report.where(status: %w[new reviewing]).group(:diagnosis).count
  end

  def update
    report = Motor2Report.find(params[:id])
    status = params[:status].presence_in(Motor2Report::STATUSES)
    report.update!(status: status) if status
    redirect_back(fallback_location: super_admin_motor2_reports_path)
  end
end
