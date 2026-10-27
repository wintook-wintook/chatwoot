# == Schema Information
#
# Table name: maintenance_plans
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE), not null
#  every             :integer          default(3), not null
#  last_generated_at :datetime
#  lead_days         :integer          default(7), not null
#  next_due_on       :date             not null
#  notes             :text
#  notify_customer   :boolean          default(TRUE), not null
#  title             :string           not null
#  unit              :integer          default("month"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  assignee_id       :bigint
#  case_type_id      :bigint           not null
#  contact_id        :bigint           not null
#  customer_asset_id :bigint
#
# Indexes
#
#  index_maintenance_plans_on_account_id              (account_id)
#  index_maintenance_plans_on_active_and_next_due_on  (active,next_due_on)
#  index_maintenance_plans_on_assignee_id             (assignee_id)
#  index_maintenance_plans_on_case_type_id            (case_type_id)
#  index_maintenance_plans_on_contact_id              (contact_id)
#  index_maintenance_plans_on_customer_asset_id       (customer_asset_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (assignee_id => users.id) ON DELETE => nullify
#  fk_rails_...  (case_type_id => case_types.id)
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (customer_asset_id => customer_assets.id) ON DELETE => nullify
#

# Plan-Trabajo-Campo R4 — mantenimiento recurrente de un cliente (un contrato):
# cada N semanas o meses genera solo una orden de trabajo del tipo elegido,
# `lead_days` antes de la fecha, y avisa al cliente (MaintenancePlans::Generator).
class MaintenancePlan < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :customer_asset, optional: true
  belongs_to :case_type
  belongs_to :assignee, class_name: 'User', optional: true
  has_many :case_tickets, dependent: :nullify

  enum unit: { week: 0, month: 1 }

  validates :title, presence: true, length: { maximum: 200 }
  validates :every, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 60 }
  validates :lead_days, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 60 }
  validates :next_due_on, presence: true
  validate :work_order_type
  validate :links_in_account

  scope :active, -> { where(active: true) }
  scope :due, ->(today = Date.current) { active.where('next_due_on - lead_days <= ?', today) }

  def interval
    week? ? every.weeks : every.months
  end

  def advance!
    update!(next_due_on: next_due_on + interval, last_generated_at: Time.current)
  end

  private

  def work_order_type
    errors.add(:case_type, 'debe ser un tipo de orden de trabajo') if case_type && !case_type.class_work_order?
  end

  def links_in_account
    errors.add(:contact, 'no es de la cuenta') if contact && contact.account_id != account_id
    errors.add(:customer_asset, 'no es del cliente') if customer_asset && customer_asset.contact_id != contact_id
  end
end
