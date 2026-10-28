# == Schema Information
#
# Table name: contracts
#
#  id                 :bigint           not null, primary key
#  auto_renew         :boolean          default(TRUE), not null
#  cancel_reason      :string
#  cancelled_on       :date
#  currency           :string(3)        default("MXN"), not null
#  custom_attributes  :jsonb            not null
#  ends_on            :date
#  every              :integer          default(1), not null
#  last_paid_on       :date
#  next_charge_on     :date
#  notes              :text
#  price              :decimal(14, 2)   default(0.0), not null
#  price_from_catalog :boolean          default(FALSE), not null
#  quantity           :decimal(12, 2)   default(1.0), not null
#  starts_on          :date             not null
#  status             :integer          default("active"), not null
#  term_months        :integer
#  title              :string           not null
#  unit               :integer          default("month"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  assignee_id        :bigint
#  catalog_item_id    :bigint
#  contact_id         :bigint           not null
#  contract_type_id   :bigint           not null
#  customer_asset_id  :bigint
#  organization_id    :bigint
#
# Indexes
#
#  index_contracts_on_account_id                                (account_id)
#  index_contracts_on_account_id_and_ends_on                    (account_id,ends_on)
#  index_contracts_on_account_id_and_status_and_next_charge_on  (account_id,status,next_charge_on)
#  index_contracts_on_assignee_id                               (assignee_id)
#  index_contracts_on_catalog_item_id                           (catalog_item_id)
#  index_contracts_on_contact_id                                (contact_id)
#  index_contracts_on_contract_type_id                          (contract_type_id)
#  index_contracts_on_customer_asset_id                         (customer_asset_id)
#  index_contracts_on_organization_id                           (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (assignee_id => users.id) ON DELETE => nullify
#  fk_rails_...  (catalog_item_id => catalog_items.id) ON DELETE => nullify
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (contract_type_id => contract_types.id)
#  fk_rails_...  (customer_asset_id => customer_assets.id) ON DELETE => nullify
#  fk_rails_...  (organization_id => organizations.id) ON DELETE => nullify
#
class Contract < ApplicationRecord
  RENEWAL_NOTICE_DAYS = 30
  STATES = %w[active renewal_due overdue ended suspended cancelled].freeze

  belongs_to :account
  belongs_to :contact
  include OrganizationLinked # Plan-Organizaciones O2
  # Plan-Organizaciones O3 — contrato nuevo → cliente (si la regla está encendida).
  after_create_commit -> { Organizations::StageRules.call(:customer_on_contract, self) }
  belongs_to :contract_type
  belongs_to :catalog_item, optional: true
  belongs_to :customer_asset, optional: true
  belongs_to :assignee, class_name: 'User', optional: true

  enum unit: { day: 0, week: 1, month: 2, year: 3 }, _prefix: :every
  enum status: { active: 0, suspended: 1, cancelled: 2 }

  before_validation :fill_defaults

  validates :title, presence: true, length: { maximum: 200 }
  validates :quantity, numericality: { greater_than: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :every, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 365 }
  validates :term_months, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 240 }, allow_nil: true
  validates :starts_on, presence: true
  validate :links_in_account
  validate :asset_and_assignee

  scope :ordered, -> { order(Arel.sql('next_charge_on IS NULL, next_charge_on'), :id) }

  # Mismas reglas que #state, en SQL, para filtrar la lista (sin fecha = no aplica).
  def self.in_state(state, today = Date.current)
    ended = sanitize_sql(['COALESCE(contracts.ends_on < ? AND NOT contracts.auto_renew, false)', today])
    overdue = sanitize_sql(['COALESCE(contracts.next_charge_on < ?, false)', today])
    renewal = sanitize_sql(['COALESCE(contracts.ends_on <= ?, false)', today + RENEWAL_NOTICE_DAYS])
    case state.to_s
    when 'suspended', 'cancelled' then where(status: state)
    when 'ended' then active.where(ended)
    when 'overdue' then active.where("NOT #{ended} AND #{overdue}")
    when 'renewal_due' then active.where("NOT #{ended} AND NOT #{overdue} AND #{renewal}")
    when 'active' then active.where("NOT #{ended} AND NOT #{overdue} AND NOT #{renewal}")
    else all
    end
  end

  def state(today = Date.current)
    active? ? date_state(today) : status
  end

  def amount
    quantity * price
  end

  # El pago del periodo: la fecha de cobro avanza un periodo. Si con eso pasa del fin
  # del plazo y se renueva solo, se renueva.
  def register_payment!(today = Date.current)
    self.next_charge_on = advance(next_charge_on || starts_on)
    self.last_paid_on = today
    extend_term if auto_renew && ends_on && next_charge_on > ends_on
    save!
  end

  # Un plazo más (el mismo número de meses).
  def renew!
    return false unless term_months && ends_on

    extend_term
    save!
  end

  def cancel!(reason, today = Date.current)
    update!(status: :cancelled, cancelled_on: today, cancel_reason: reason.to_s.strip.presence)
  end

  def reactivate!
    update!(status: :active, cancelled_on: nil, cancel_reason: nil)
  end

  def advance(date)
    date.advance(unit.pluralize.to_sym => every)
  end

  private

  def extend_term
    self.ends_on = ends_on.advance(months: term_months)
  end

  def date_state(today)
    return 'ended' if term_over?(today) && !auto_renew
    return 'overdue' if next_charge_on.present? && next_charge_on < today
    return 'renewal_due' if ends_on.present? && ends_on <= today + RENEWAL_NOTICE_DAYS

    'active'
  end

  def term_over?(today)
    ends_on.present? && ends_on < today
  end

  def fill_defaults
    fill_catalog_price
    self.currency = currency.to_s.upcase.presence || 'MXN'
    self.title = catalog_item&.name if title.blank?
    self.next_charge_on ||= starts_on
    fill_ends_on
    self.custom_attributes = (custom_attributes || {}).to_h.slice(*Array(contract_type&.custom_fields).pluck('key'))
  end

  def fill_catalog_price
    self.price_from_catalog = false unless catalog_item
    return unless price_from_catalog

    self.price = catalog_item.price
    self.currency = catalog_item.currency
  end

  # El fin del plazo sale del inicio + los meses; «Renovar» lo recorre sin tocar el plazo.
  def fill_ends_on
    if term_months.nil?
      self.ends_on = nil
    elsif starts_on && (ends_on.blank? || will_save_change_to_term_months? || will_save_change_to_starts_on?)
      self.ends_on = starts_on.advance(months: term_months)
    end
  end

  def links_in_account
    %i[contact contract_type catalog_item].each do |link|
      record = public_send(link)
      errors.add(link, 'no es de la cuenta') if record && record.account_id != account_id
    end
  end

  def asset_and_assignee
    errors.add(:customer_asset, 'no es del cliente') if customer_asset && customer_asset.contact_id != contact_id
    errors.add(:assignee, 'no es de la cuenta') if assignee && !account.users.exists?(assignee.id)
  end
end
