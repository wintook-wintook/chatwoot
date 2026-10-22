# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Plan-Plantilla-Tareas-Etapa: avisos en la campanita
# ================================================================================
# tasks_created — al entrar a una etapa, UN aviso por persona con sus tareas nuevas
#   («3 tareas nuevas · etapa Propuesta»). Una tarea de equipo sin persona avisa a
#   todo el equipo, para que alguien la tome.
# stage_ready   — se terminaron las obligatorias: avisa al responsable del caso que
#   puede pasar (o que hay que documentar para pasar).
# Nunca se avisa a quien hizo el movimiento: ya lo está viendo. Si falla, no rompe
# nada (el aviso es un extra).
# ================================================================================

class Cases::StageNotifier
  def initialize(ticket)
    @ticket = ticket
  end

  def tasks_created(column, tasks)
    recipients(tasks).each do |user_id, own|
      notify('case_stage_tasks', user_id, stage: column.label, column_id: column.id, count: own.size,
                                          task_title: tasks_summary(own, column))
    end
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] aviso de tareas nuevas del caso #{@ticket.id}: #{e.message}")
  end

  def stage_ready(stage, next_column, needs_doc:)
    return if @ticket.assignee_id.nil?

    key = needs_doc ? 'stage_ready_doc' : 'stage_ready'
    notify('case_stage_ready', @ticket.assignee_id,
           stage: stage.label, next: next_column.label, needs_doc: needs_doc,
           task_title: text(key, stage: stage.label, next: next_column.label))
  rescue StandardError => e
    Rails.logger.error("[GestorTickets] aviso de etapa lista del caso #{@ticket.id}: #{e.message}")
  end

  private

  # { user_id => [tareas] }: la persona asignada o, si es de equipo sin persona, cada
  # integrante del equipo.
  def recipients(tasks)
    tasks.each_with_object(Hash.new { |h, k| h[k] = [] }) do |task, acc|
      ids = task.assignee_id ? [task.assignee_id] : team_member_ids(task.team_id)
      ids.each { |id| acc[id] << task }
    end
  end

  def team_member_ids(team_id)
    team_id ? TeamMember.where(team_id: team_id).pluck(:user_id) : []
  end

  def tasks_summary(tasks, column)
    text('tasks', count: tasks.size, stage: column.label, titles: tasks.map(&:title).first(3).join(', '))
  end

  # El texto queda guardado en el aviso: va en el idioma de la cuenta, no en el del
  # proceso que lo generó (un job o una regla no traen idioma).
  def text(key, **params)
    I18n.with_locale(@ticket.account.locale.presence || I18n.default_locale) do
      I18n.t("notifications.case_stages.#{key}", **params)
    end
  end

  def notify(type, user_id, meta)
    return if user_id == Current.user&.id

    user = @ticket.account.users.find_by(id: user_id)
    return unless user

    NotificationBuilder.new(notification_type: type, user: user, account: @ticket.account,
                            primary_actor: @ticket, meta: meta).perform
  end
end
