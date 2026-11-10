# == Schema Information
#
# Table name: customer_assets
#
#  id              :bigint           not null, primary key
#  active          :boolean          default(TRUE), not null
#  brand           :string
#  installed_on    :date
#  location        :string
#  model           :string
#  name            :string           not null
#  notes           :text
#  serial          :string
#  warranty_until  :date
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  contact_id      :bigint           not null
#  organization_id :bigint
#
# Indexes
#
#  index_customer_assets_on_account_id       (account_id)
#  index_customer_assets_on_contact_id       (contact_id)
#  index_customer_assets_on_organization_id  (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (organization_id => organizations.id) ON DELETE => nullify
#

# Plan-Trabajo-Campo R4 — un equipo del cliente (p. ej. un minisplit): marca,
# modelo, serie y dónde está. Sus órdenes de trabajo son su historial.
class CustomerAsset < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  include OrganizationLinked # Plan-Organizaciones O2
  has_many :case_tickets, dependent: :nullify
  has_many :maintenance_plans, dependent: :nullify

  validates :name, presence: true, length: { maximum: 200 }
  validate :contact_in_account

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name, :id) }

  def under_warranty?
    warranty_until.present? && warranty_until >= Date.current
  end

  private

  def contact_in_account
    errors.add(:contact, 'no es de la cuenta') if contact && contact.account_id != account_id
  end
end
