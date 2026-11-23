# Reporte de cierre — ninguna tarea se concluye a mano sin decir qué se hizo.
module TaskReportGuard
  private

  # Al concluir (pendiente → done), igual que missing_task_report?, salvo el punto de una orden de
  # trabajo palomeado en la lista de verificación (Mi ruta o el reporte de servicio; service_checklist): la orden cierra con su
  # reporte de servicio. Desde Tareas, Mi día o el caso sí se pide.
  def missing_close_report?(task, was_done, new_status)
    return false if was_done || new_status.to_s != 'done'
    return false if ActiveModel::Type::Boolean.new.cast(params[:service_checklist]) && task.checklist_item?

    missing_task_report?(task)
  end

  # true si ya respondió: al front le dice que falta el reporte.
  def missing_task_report?(item)
    return false if item.report_ready?

    render json: { error: I18n.t('task_reports.required'), report_required: true }, status: :unprocessable_entity
    true
  end
end
