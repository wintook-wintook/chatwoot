# == Schema Information
#
# Table name: crm_quotes
#
#  id                     :bigint           not null, primary key
#  cfdi_use               :string(4)
#  delivery_date          :date
#  discount_total         :decimal(15, 2)   default(0.0), not null
#  exchange_rate          :decimal(18, 6)   default(1.0), not null
#  extra_discount_amount  :decimal(15, 2)   default(0.0), not null
#  extra_discount_percent :decimal(9, 6)    default(0.0), not null
#  extra_discount_type    :string(1)        default("percent"), not null
#  extra_discount_value   :decimal(15, 6)   default(0.0), not null
#  folio                  :string(20)       not null
#  footer_notes           :text
#  freight                :decimal(15, 2)   default(0.0), not null
#  header_notes           :text
#  net_amount             :decimal(15, 2)   default(0.0), not null
#  number                 :integer          not null
#  other_charges          :decimal(15, 2)   default(0.0), not null
#  purchase_order         :string(35)
#  purchase_order_date    :date
#  quote_date             :date             not null
#  sat_payment_method     :string(3)
#  series                 :string(8)        not null
#  status                 :string(1)        default("pending"), not null
#  status_changed_at      :datetime
#  subtotal               :decimal(15, 2)   default(0.0), not null
#  tax_total              :decimal(15, 2)   default(0.0), not null
#  total                  :decimal(15, 2)   default(0.0), not null
#  valid_until            :date
#  withholding_total      :decimal(15, 2)   default(0.0), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  contact_id             :integer
#  created_by_id          :bigint
#  currency_id            :bigint
#  organization_id        :bigint           not null
#  payment_term_id        :bigint
#  seller_id              :bigint
#  shipping_address_id    :bigint
#  status_changed_by_id   :bigint
#  updated_by_id          :bigint
#
# Indexes
#
#  index_crm_quotes_on_account_id                            (account_id)
#  index_crm_quotes_on_account_id_and_folio                  (account_id,folio) UNIQUE
#  index_crm_quotes_on_account_id_and_status_and_quote_date  (account_id,status,quote_date)
#  index_crm_quotes_on_contact_id                            (contact_id)
#  index_crm_quotes_on_created_by_id                         (created_by_id)
#  index_crm_quotes_on_currency_id                           (currency_id)
#  index_crm_quotes_on_organization_id                       (organization_id)
#  index_crm_quotes_on_payment_term_id                       (payment_term_id)
#  index_crm_quotes_on_seller_id                             (seller_id)
#  index_crm_quotes_on_shipping_address_id                   (shipping_address_id)
#  index_crm_quotes_on_status_changed_by_id                  (status_changed_by_id)
#  index_crm_quotes_on_updated_by_id                         (updated_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => nullify
#  fk_rails_...  (created_by_id => users.id) ON DELETE => nullify
#  fk_rails_...  (currency_id => crm_currencies.id) ON DELETE => nullify
#  fk_rails_...  (organization_id => crm_organizations.id)
#  fk_rails_...  (payment_term_id => crm_payment_terms.id) ON DELETE => nullify
#  fk_rails_...  (seller_id => crm_sellers.id) ON DELETE => nullify
#  fk_rails_...  (shipping_address_id => crm_organization_addresses.id) ON DELETE => nullify
#  fk_rails_...  (status_changed_by_id => users.id) ON DELETE => nullify
#  fk_rails_...  (updated_by_id => users.id) ON DELETE => nullify
#

# CrmZeus Q0 — cotización (DCDOCTOS_PDV de CRMZeus) a un cliente o prospecto de CrmZeus.
# Folio = serie del agente + consecutivo (CTFOLIOS_USUARIOS). Solo se edita en Pendiente.
# Los totales los calcula el servidor en cada guardado (Crm::QuoteTotals); lo que mande el
# navegador como total se ignora.
class CrmQuote < ApplicationRecord
  # Lo que se puede cambiar cuando ya no está Pendiente (el cambio de estatus).
  PURCHASE_ORDER_DATE_MESSAGE = 'es obligatoria si hay orden de compra'.freeze
  STATUS_COLUMNS = %w[status status_changed_at status_changed_by_id updated_by_id updated_at].freeze
  # setQStatus / menú de estatus de CRMZeus: a dónde se puede pasar desde cada estatus.
  TRANSITIONS = {
    'pending' => %w[won lost cancelled],
    'won' => %w[lost cancelled],
    'lost' => %w[pending cancelled],
    'cancelled' => %w[lost]
  }.freeze

  belongs_to :account
  belongs_to :organization, class_name: 'CrmOrganization'
  belongs_to :contact, optional: true
  belongs_to :shipping_address, class_name: 'CrmOrganizationAddress', optional: true
  belongs_to :seller, class_name: 'CrmSeller', optional: true
  belongs_to :currency, class_name: 'CrmCurrency', optional: true
  belongs_to :payment_term, class_name: 'CrmPaymentTerm', optional: true
  belongs_to :status_changed_by, class_name: 'User', optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  has_many :items, -> { order(:position, :id) }, class_name: 'CrmQuoteItem', foreign_key: :quote_id, inverse_of: :quote,
                                                 dependent: :destroy, autosave: true

  # Mismas letras que ESTATUS de CRMZeus.
  enum status: { pending: 'N', won: 'E', lost: 'P', cancelled: 'C' }, _prefix: :status
  # TIPO_DSCTO: el descuento extra es un porcentaje o un importe.
  enum extra_discount_type: { percent: 'P', amount: 'I' }, _prefix: :extra_discount

  before_validation :normalize
  before_validation :recalculate
  before_create :assign_folio

  validates :quote_date, :currency, :seller, :payment_term, :valid_until, :delivery_date, :cfdi_use, presence: true
  validates :exchange_rate, numericality: { greater_than: 0 }
  validates :extra_discount_value, :freight, :other_charges, numericality: { greater_than_or_equal_to: 0 }
  validates :extra_discount_value, numericality: { less_than_or_equal_to: 100 }, if: :extra_discount_percent?
  validates :cfdi_use, length: { maximum: 4 }
  validates :purchase_order, length: { maximum: 35 }
  validates :purchase_order_date, presence: { message: PURCHASE_ORDER_DATE_MESSAGE }, if: :purchase_order?
  validate :valid_until_after_quote_date
  validate :items_present
  validate :references_belong_to_account
  validate :contact_belongs_to_organization
  validate :shipping_address_belongs_to_organization
  validate :series_for_creator, on: :create
  validate :locked_unless_pending, on: :update

  scope :search, lambda { |term|
    next all if term.blank?

    like = "%#{sanitize_sql_like(term.to_s.strip)}%"
    joins(:organization).where('crm_quotes.folio ILIKE :q OR crm_organizations.trade_name ILIKE :q OR ' \
                               'crm_organizations.legal_name ILIKE :q', q: like)
  }

  # Defaults de una cotización nueva tomados del cliente o prospecto (como CRMZeus al elegirlo).
  def fill_from_organization
    return self unless organization

    self.seller ||= organization.seller
    self.payment_term ||= organization.payment_term
    self.currency ||= organization.currency || account.crm_currencies.active.find_by(is_default: true)
    self.cfdi_use ||= organization.cfdi_use
    self.exchange_rate = default_exchange_rate
    self
  end

  def can_change_status_to?(new_status)
    TRANSITIONS.fetch(status, []).include?(new_status.to_s)
  end

  def change_status!(new_status, user = nil)
    unless can_change_status_to?(new_status)
      errors.add(:status, "no puede pasar de #{status_label} a #{self.class.status_label(new_status)}")
      raise ActiveRecord::RecordInvalid, self
    end

    update!(status: new_status, status_changed_at: Time.current, status_changed_by: user, updated_by: user || updated_by)
  end

  def status_label
    self.class.status_label(status)
  end

  def self.status_label(value)
    { 'pending' => 'Pendiente', 'won' => 'Ganada', 'lost' => 'Perdida', 'cancelled' => 'Cancelada' }.fetch(value.to_s, value.to_s)
  end

  # Partidas que se cotizan (sin los componentes de los kits), en el orden en pantalla.
  def priced_items
    items.reject { |item| item.marked_for_destruction? || item.role_component? }.sort_by { |item| [item.position, item.id.to_i] }
  end

  # Un renglón por impuesto con su base y su importe (IMPUESTOS_DCDOCTOS_PDV).
  def tax_summary
    priced_items.flat_map(&:item_taxes).reject(&:marked_for_destruction?).group_by { |t| [t.tax_id, t.name, t.percent] }
                .map do |(tax_id, name, percent), rows|
      { tax_id: tax_id, name: name, percent: percent, tax_type: rows.first.tax_type,
        base_amount: rows.sum(&:base_amount), amount: rows.sum(&:amount).round(2) }
    end
  end

  private

  def normalize
    self.quote_date ||= Time.zone.today
    self.cfdi_use = cfdi_use.to_s.strip.upcase.presence
    self.purchase_order = purchase_order.to_s.strip.presence
    self.purchase_order_date = nil if purchase_order.blank?
    derive_values
  end

  # Moneda local = 1; método de pago SAT de la condición de pago (form.js:85-93: de contado PUE,
  # a plazos PPD); un prospecto no tiene consignatario.
  def derive_values
    self.exchange_rate = 1 if currency&.is_local?
    self.sat_payment_method = payment_term && (payment_term.credit_days.zero? ? 'PUE' : 'PPD')
    self.shipping_address = nil if organization&.prospect?
  end

  def default_exchange_rate
    return exchange_rate || 1 unless currency
    return 1 if currency.is_local?

    currency.fixed_exchange_rate || exchange_rate || 1
  end

  def recalculate
    Crm::QuoteTotals.new(self).apply
  end

  def assign_folio
    Crm::QuoteFolio.new(self).assign
  end

  def valid_until_after_quote_date
    return unless valid_until && quote_date && valid_until < quote_date

    errors.add(:valid_until, 'no puede ser anterior a la fecha de la cotización')
  end

  def items_present
    errors.add(:items, 'debe tener al menos una partida') if priced_items.empty?
  end

  def references_belong_to_account
    { organization: organization, seller: seller, currency: currency, payment_term: payment_term }.each do |name, record|
      errors.add(name, 'no pertenece a la cuenta') if record && record.account_id != account_id
    end
  end

  def contact_belongs_to_organization
    return unless contact && organization
    return if CrmOrganizationContact.exists?(organization_id: organization_id, contact_id: contact_id)

    errors.add(:contact, 'no está ligado a la organización')
  end

  def shipping_address_belongs_to_organization
    return unless shipping_address && shipping_address.organization_id != organization_id

    errors.add(:shipping_address, 'no es de la organización')
  end

  def series_for_creator
    return if created_by && CrmQuoteSeries.exists?(account_id: account_id, user_id: created_by_id)

    errors.add(:base, 'El agente no tiene serie de folios para cotizar')
  end

  def locked_unless_pending
    return if status_in_database == 'pending'
    return if (changed - STATUS_COLUMNS).empty? && items.none?(&:changed_for_autosave?)

    errors.add(:base, "Solo se puede editar una cotización Pendiente (esta está #{self.class.status_label(status_was)})")
  end
end
