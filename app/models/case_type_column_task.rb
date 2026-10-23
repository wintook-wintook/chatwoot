# frozen_string_literal: true

# == Schema Information
#
# Table name: case_type_column_tasks
#
#  id                  :bigint           not null, primary key
#  assignee_mode       :integer          default("case_assignee"), not null
#  description         :text
#  due_after_hours     :integer
#  estimated_minutes   :integer
#  position            :integer          default(0), not null
#  priority            :integer          default("medium"), not null
#  required            :boolean          default(TRUE), not null
#  title               :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  assignee_id         :bigint
#  case_type_column_id :bigint           not null
#  team_id             :bigint
#
# Indexes
#
#  index_case_type_column_tasks_on_account_id           (account_id)
#  index_case_type_column_tasks_on_case_type_column_id  (case_type_column_id)
#  index_column_tasks_on_column_and_position            (case_type_column_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (case_type_column_id => case_type_columns.id) ON DELETE => cascade
#

# @tickets_cases — Plan-Plantilla-Tareas-Etapa T1: tarea plantilla de una etapa
# (columna) de un tipo de caso. Al entrar el caso a la etapa se crea como tarea
# del caso (T2), con vencimiento `due_after_hours` después de la entrada. Las
# `required` son las que deciden cuándo se sugiere pasar a la siguiente etapa (T3).
class CaseTypeColumnTask < ApplicationRecord
  belongs_to :account
  belongs_to :case_type_column, inverse_of: :task_templates
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :team, optional: true

  # Mismos valores que CaseTask#priority, para copiarla tal cual.
  enum priority: { low: 0, medium: 1, high: 2, urgent: 3 }, _prefix: :priority
  # Quién la hace: el responsable del caso (defecto), una persona fija o un equipo.
  enum assignee_mode: { case_assignee: 0, user: 1, team: 2 }, _prefix: :assigned_to

  validates :title, presence: true, length: { maximum: 255 }
  validates :due_after_hours, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :estimated_minutes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :assignee_matches_mode

  scope :ordered, -> { order(:position, :id) }

  ASSIGNEE_MESSAGE = 'Elige la persona o el equipo que hace la tarea'

  private

  def assignee_matches_mode
    return errors.add(:assignee_id, ASSIGNEE_MESSAGE) if assigned_to_user? && !account_member?(assignee_id)

    errors.add(:team_id, ASSIGNEE_MESSAGE) if assigned_to_team? && !account.teams.exists?(id: team_id)
  end

  def account_member?(user_id)
    user_id.present? && account.account_users.exists?(user_id: user_id)
  end
end
