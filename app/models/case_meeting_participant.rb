# frozen_string_literal: true

# Agenda: un usuario del equipo que participa en una tarea agendada (además del responsable, organizer). La ve en su
# Agenda, «Mi día», Dali y, si es visita, en «Mi ruta»; puede decir «No puedo ir» (declined, con su nota) y le llega al
# responsable. Solo el responsable la concluye y marca la llegada. Ver Cases::Meetings::Participants.
class CaseMeetingParticipant < ApplicationRecord
  STATUSES = %w[invited declined].freeze

  belongs_to :account
  belongs_to :case_meeting
  belongs_to :user

  validates :status, inclusion: { in: STATUSES }
  validates :user_id, uniqueness: { scope: :case_meeting_id }
end
