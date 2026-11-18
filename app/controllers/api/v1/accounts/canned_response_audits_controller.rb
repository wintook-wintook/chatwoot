# frozen_string_literal: true

# proyecto@auditoria_predefinidas — la pestaña «Auditoría» de Respuestas predefinidas.
#   GET   …/canned_response_audit?status=open|dismissed   resumen, tamaños, hallazgos, última corrida
#   POST  …/canned_response_audit                         «Auditar» toda la cuenta (en segundo plano)
#   PATCH …/canned_response_audit/findings/:id { status }  descartar (dismissed) o reabrir (open)
#   POST  …/canned_response_audit/findings/:id/keep { keep_id }
#         duplicadas: conservar una y eliminar la otra
class Api::V1::Accounts::CannedResponseAuditsController < Api::V1::Accounts::BaseController
  before_action :fetch_finding, only: [:update_finding, :keep]

  def show
    render json: CannedResponses::Audit::Report.new(Current.account).call(status: params[:status])
  end

  def create
    return render json: { error: 'no_key' }, status: :unprocessable_entity unless openai_key?

    audit = Current.account.canned_response_audits.running.last ||
            Current.account.canned_response_audits.create!(status: 'running').tap do |nueva|
              CannedResponses::AuditJob.perform_later(nueva.id)
            end
    render json: audit.as_audit_json
  end

  def update_finding
    estado = params.require(:status)
    return head :unprocessable_entity unless CannedResponseFinding::STATUSES.include?(estado)

    @finding.update!(status: estado)
    render json: @finding.as_audit_json
  end

  # Solo duplicadas: la otra se elimina (y con ella, por la FK, todos sus hallazgos).
  def keep
    return head :unprocessable_entity unless @finding.kind == 'duplicate' && @finding.ids.include?(params[:keep_id].to_i)

    borrar = (@finding.ids - [params[:keep_id].to_i]).first
    Current.account.canned_responses.find(borrar).destroy!
    head :ok
  end

  private

  def fetch_finding
    @finding = Current.account.canned_response_findings.find(params[:finding_id])
  end

  def openai_key?
    Current.account.hooks.exists?(app_id: 'openai', status: 'enabled')
  end
end
