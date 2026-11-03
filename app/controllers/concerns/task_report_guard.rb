# Reporte de cierre — ninguna tarea se concluye a mano sin decir qué se hizo.
module TaskReportGuard
  private

  # true si ya respondió: al front le dice que falta el reporte.
  def missing_task_report?(item)
    return false if item.report_ready?

    render json: { error: I18n.t('task_reports.required'), report_required: true }, status: :unprocessable_entity
    true
  end
end
