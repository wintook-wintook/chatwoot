# frozen_string_literal: true

# Agenda — cada 5 minutos: a los participantes de las tareas agendadas que empiezan en la próxima media hora, el aviso
# de que está por empezar (una vez por tarea; si cambia la hora, se vuelve a avisar). Cases::Meetings::Participants.
class Cases::MeetingParticipantsReminderJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Cases::Meetings::Participants.remind_due!
  end
end
