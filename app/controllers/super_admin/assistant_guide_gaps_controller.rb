# frozen_string_literal: true

# Super Admin › Preguntas sin respuesta — lo que el asistente (Dali) no supo contestar
# en TODAS las empresas: sin guía o guía incompleta. Solo lo ve el equipo de
# Kontrolya; con esto se escriben o corrigen las guías de config/assistant/guides.
# También se leen y se cierran con `rake assistant:guide_gaps`.
#
#   GET   /super_admin/assistant_guide_gaps?status=&reason=&account_id=&q=
#   PATCH /super_admin/assistant_guide_gaps/:id   { status: resolved|discarded|pending, note }
class SuperAdmin::AssistantGuideGapsController < SuperAdmin::ApplicationController
  PER_PAGE = 50

  def index
    read_filters
    @counts = AssistantGuideGap.group(:status).count
    @accounts = Account.where(id: AssistantGuideGap.select(:account_id)).order(:name).pluck(:name, :id)
    @gaps = filtered.includes(:account, :user).by_relevance.page(params[:page]).per(PER_PAGE)
  end

  def update
    gap = AssistantGuideGap.find(params[:id])
    status = params[:status].presence_in(AssistantGuideGap::STATUSES)
    gap.update!(status: status, resolution_note: params[:note].presence) if status
    redirect_back(fallback_location: super_admin_assistant_guide_gaps_path)
  end

  private

  def read_filters
    @status = AssistantGuideGap::STATUSES.include?(params[:status]) ? params[:status] : 'pending'
    @reason = params[:reason].presence_in(AssistantGuideGap::REASONS)
    @account_id = params[:account_id].presence&.to_i
    @query = params[:q].to_s.strip
  end

  def filtered
    scope = AssistantGuideGap.where(status: @status)
    scope = scope.where(reason: @reason) if @reason
    scope = scope.where(account_id: @account_id) if @account_id
    scope = scope.where('question ILIKE ?', "%#{AssistantGuideGap.sanitize_sql_like(@query)}%") if @query.present?
    scope
  end
end
