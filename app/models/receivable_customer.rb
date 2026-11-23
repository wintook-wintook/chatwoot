# frozen_string_literal: true

# == Schema Information
#
# Table name: receivable_customers
#
#  id                :bigint           not null, primary key
#  contact_name      :string
#  email             :string
#  external_key      :string           not null
#  last_contacted_at :datetime
#  link_status       :string           default("pending"), not null
#  name              :string           not null
#  phone             :string
#  rfc               :string
#  touches           :integer          default(0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  collector_id      :bigint
#  contact_id        :bigint
#  organization_id   :bigint
#
# Indexes
#
#  index_receivable_customers_on_account_id                   (account_id)
#  index_receivable_customers_on_account_id_and_external_key  (account_id,external_key) UNIQUE
#  index_receivable_customers_on_account_id_and_link_status   (account_id,link_status)
#  index_receivable_customers_on_contact_id                   (contact_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
# Cobranza — un cliente de la cartera, como lo nombra el sistema administrativo (external_key: su clave, o su RFC, o
# su nombre si no hay más), ligado a su organización y al contacto al que se le cobra (Receivables::Linker).
#   link_status: pending (por ligar) | linked | ignored (no se le cobra)
class ReceivableCustomer < ApplicationRecord
  LINK_STATUSES = %w[pending linked ignored].freeze

  belongs_to :account
  belongs_to :organization, optional: true
  belongs_to :contact, optional: true
  belongs_to :collector, class_name: 'User', optional: true
  has_many :receivables, dependent: :destroy
  has_many :payment_promises, dependent: :destroy
  has_many :payment_claims, dependent: :destroy

  validates :external_key, :name, presence: true
  validates :link_status, inclusion: { in: LINK_STATUSES }

  scope :linked, -> { where(link_status: 'linked') }
  scope :pending, -> { where(link_status: 'pending') }

  def open_receivables = receivables.where(status: 'open')
end
