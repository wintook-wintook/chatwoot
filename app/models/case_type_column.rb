# frozen_string_literal: true

# == Schema Information
#
# Table name: case_type_columns
#
#  id           :bigint           not null, primary key
#  color        :string           default("#64748b"), not null
#  label        :string           not null
#  position     :integer          default(0), not null
#  statuses     :jsonb            not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  case_type_id :bigint           not null
#
# Indexes
#
#  index_case_type_columns_on_account_id         (account_id)
#  index_case_type_columns_on_type_and_position  (case_type_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (case_type_id => case_types.id) ON DELETE => cascade
#

# @tickets_cases — Columna del Kanban propia de un Tipo de Caso (Opción A+).
# Cada columna cubre uno o más `status` del enum global de CaseTicket. Varias
# columnas del mismo tipo PUEDEN cubrir el mismo estado (ej. tres etapas de un
# flujo comercial, todas `in_progress`): esa es la funcionalidad, no un error, por
# eso NO hay validación de solape. El ticket recuerda en cuál está vía
# `case_tickets.case_type_column_id`; `status` sigue siendo el estado canónico.
class CaseTypeColumn < ApplicationRecord
  belongs_to :account
  belongs_to :case_type
  has_many   :case_tickets, dependent: :nullify

  validates :label, presence: true, length: { maximum: 60 }
  validates :color, presence: true
  validate  :statuses_are_valid

  scope :ordered, -> { order(:position, :id) }

  before_validation :normalize_statuses

  private

  # `statuses` siempre array de strings únicos y no vacíos.
  def normalize_statuses
    self.statuses = Array(statuses).map { |s| s.to_s.strip }.reject(&:blank?).uniq
  end

  # Debe cubrir al menos un estado, y todos han de pertenecer al enum de CaseTicket.
  # (La cobertura TOTAL de los 13 estados se valida a nivel del tipo, en el
  # servicio de guardado — una columna suelta no sabe qué cubren sus hermanas.)
  def statuses_are_valid
    if statuses.blank?
      errors.add(:statuses, 'requiere al menos un estado')
      return
    end

    invalid = statuses - CaseTicket.statuses.keys
    errors.add(:statuses, "estados inválidos: #{invalid.join(', ')}") if invalid.any?
  end
end
