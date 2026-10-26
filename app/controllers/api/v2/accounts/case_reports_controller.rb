# proyecto@metricas_casos — Informes de Casos (seguimiento de oportunidades por
# vendedor). Vive aparte de Api::V2::Accounts::ReportsController porque el dominio
# (CaseTicket) no tiene reporting_events ni comparte builders con Conversation.
class Api::V2::Accounts::CaseReportsController < Api::V1::Accounts::BaseController
  SUMMARY_ACTIONS = %i[business_summary business_summary_ai business_summary_conversations_ai].freeze
  # Plan-Roles-Permisos — de qué área es cada dashboard (el resto son de Ventas).
  SERVICE_ACTIONS = %i[work_orders projects].freeze

  before_action :check_authorization, except: SUMMARY_ACTIONS
  # «Resumen del negocio»: administradores y los agentes que ellos autoricen.
  before_action :check_summary_access, only: SUMMARY_ACTIONS

  def funnel
    render json: distribution_builder.funnel
  end

  def outcome
    render json: distribution_builder.outcome
  end

  def timeseries
    render json: timeseries_builder.timeseries
  end

  def assignees
    render json: assignee_summary_builder.build
  end

  def velocity
    render json: stage_duration_builder.velocity
  end

  def stalled
    render json: stage_duration_builder.stalled(threshold_days: threshold_days_param)
  end

  # Plan-Clase-Comercial F5 — métricas del embudo comercial (solo clase Comercial).
  def pipeline
    render json: V2::Reports::Cases::PipelineBuilder.new(account: Current.account, params: permitted_params).build
  end

  # Plan-Metricas-Comercial — a pedido (botón «Calcular»): estancadas (M2) y mes a mes (M3).
  def pipeline_stale
    render json: V2::Reports::Cases::PipelineStaleBuilder.new(account: Current.account, params: permitted_params).build
  end

  def pipeline_monthly
    render json: V2::Reports::Cases::PipelineMonthlyBuilder.new(account: Current.account, params: permitted_params).build
  end

  # Plan-Clase-Orden-de-Trabajo F3 — métricas de órdenes de trabajo (solo esa clase).
  def work_orders
    render json: V2::Reports::Cases::WorkOrderBuilder.new(account: Current.account, params: permitted_params).build
  end

  # Plan-Clase-Proyecto P3 — métricas de proyectos (solo esa clase).
  def projects
    render json: V2::Reports::Cases::ProjectBuilder.new(account: Current.account, params: permitted_params).build
  end

  # «Resumen del negocio» — todas las clases en una pantalla.
  def business_summary
    render json: business_summary_data
  end

  # «Explícame la semana»: la IA cuenta el resumen (no decide ni inventa cifras).
  def business_summary_ai
    return render_ai_error('La IA del «Resumen del negocio» está desactivada.') unless ai_active?(:business_summary)

    narrator = Cases::Ai::BusinessSummaryNarrator.new(account: Current.account)
    return render_ai_error('Configura la integración de OpenAI para usar la IA.') unless narrator.available?

    story = narrator.narrate(summary: business_summary_data, period: params[:period_label], compare: params[:compare_label])
    story ? render(json: { story: story }) : render_ai_error('No se pudo generar el resumen. Intenta de nuevo.')
  end

  # Análisis de conversaciones con IA (a pedido): muestra de las del período.
  def business_summary_conversations_ai
    return render_ai_error('La IA de «Análisis de conversaciones» está desactivada.') unless ai_active?(:conversation_analysis)

    analyst = Cases::Ai::ConversationAnalyst.new(account: Current.account)
    return render_ai_error('Configura la integración de OpenAI para usar la IA.') unless analyst.available?

    since, till = params.values_at(:since, :until)
    range = since.present? && till.present? ? Time.zone.at(since.to_i)..Time.zone.at(till.to_i) : nil
    analysis = analyst.analyze(range: range)
    analysis ? render(json: { analysis: analysis }) : render_ai_error('No se pudo analizar. Intenta de nuevo.')
  end

  private

  def distribution_builder
    @distribution_builder ||= V2::Reports::Cases::DistributionBuilder.new(account: Current.account, params: permitted_params)
  end

  def timeseries_builder
    @timeseries_builder ||= V2::Reports::Cases::TimeseriesBuilder.new(account: Current.account, params: timeseries_params)
  end

  def assignee_summary_builder
    @assignee_summary_builder ||= V2::Reports::Cases::AssigneeSummaryBuilder.new(account: Current.account, params: permitted_params)
  end

  def stage_duration_builder
    @stage_duration_builder ||= V2::Reports::Cases::StageDurationBuilder.new(account: Current.account, params: permitted_params)
  end

  def threshold_days_param
    params[:threshold_days].presence || V2::Reports::Cases::StageDurationBuilder::DEFAULT_THRESHOLD_DAYS
  end

  def permitted_params
    params.permit(:case_type_id, :assignee_id, :team_id, :since, :until, :threshold_days,
                  :currency, :close, # Plan-Clase-Comercial — pestaña Embudo
                  :prev_since, :prev_until, :span) # Plan-Metricas-Comercial — comparación y Mes a mes
          .merge(own_numbers_only)
  end

  def timeseries_params
    params.permit(:case_type_id, :assignee_id, :team_id, :since, :until, :group_by, :timezone_offset)
          .merge(own_numbers_only)
  end

  # Plan-Roles-Permisos — entra quien tiene Informes o el área del dashboard
  # (Ventas o Servicio); el que solo ve lo suyo, ve solo sus números.
  def check_authorization
    return if access_grant.allowed?(:reports) || access_grant.allowed?(dashboard_area)

    render_access_denied
  end

  def dashboard_area
    SERVICE_ACTIONS.include?(action_name.to_sym) ? :service : :sales
  end

  def own_numbers_only
    sees_all = %w[all view].include?(access_grant.level(:reports)) || !access_grant.own?(dashboard_area)
    sees_all ? {} : { assignee_id: current_user.id }
  end

  def check_summary_access
    return if CaseSetting.for_account(Current.account).business_summary_visible_to?(current_user)

    render json: { error: 'No tienes acceso al Resumen del negocio.' }, status: :forbidden
  end

  def business_summary_data
    @business_summary_data ||= V2::Reports::Cases::BusinessSummaryBuilder.new(account: Current.account,
                                                                              params: permitted_params).build
  end

  def ai_active?(action)
    CaseAiConfig.for_account(Current.account).active?(action)
  end

  def render_ai_error(message)
    render json: { error: message }, status: :unprocessable_entity
  end
end
