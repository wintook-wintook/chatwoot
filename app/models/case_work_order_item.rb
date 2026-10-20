# frozen_string_literal: true

# == Schema Information
#
# Table name: case_work_order_items
#
#  id             :bigint           not null, primary key
#  description    :string           not null
#  position       :integer          default(0), not null
#  quantity       :decimal(10, 2)   default(1.0), not null
#  unit           :string
#  unit_cost      :decimal(14, 2)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#  case_ticket_id :bigint           not null
#
# Indexes
#
#  index_case_work_order_items_on_case_ticket_id  (case_ticket_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (case_ticket_id => case_tickets.id) ON DELETE => cascade
#

# @tickets_cases — Plan-Clase-Orden-de-Trabajo F2a: un material de una orden de
# trabajo (concepto, cantidad, unidad y costo unitario opcional).
class CaseWorkOrderItem < ApplicationRecord
  belongs_to :account
  belongs_to :case_ticket

  validates :description, presence: true, length: { maximum: 200 }
  validates :unit,        length: { maximum: 30 }, allow_blank: true
  validates :quantity,    numericality: { greater_than: 0 }
  validates :unit_cost,   numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate  :ticket_is_work_order

  scope :ordered, -> { order(:position, :id) }

  # Sin costo unitario no hay importe (el material se registra igual).
  def total
    unit_cost && (quantity * unit_cost)
  end

  private

  def ticket_is_work_order
    errors.add(:case_ticket, 'no es una orden de trabajo') unless case_ticket&.work_order?
  end
end
