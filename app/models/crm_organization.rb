# == Schema Information
#
# Table name: crm_organizations
#
#  id                :bigint           not null, primary key
#  cfdi_use          :string(4)
#  charge_taxes      :boolean          default(TRUE), not null
#  converted_at      :datetime
#  credit_limit      :decimal(14, 2)   default(0.0), not null
#  email             :string
#  invoice_email     :string
#  key               :string(20)
#  legal_name        :string(100)      not null
#  notes             :text
#  organization_type :integer          default("prospect"), not null
#  phone             :string(35)
#  respect_seller    :boolean          default(FALSE), not null
#  sat_payment_form  :string(3)
#  status            :string(1)        default("active"), not null
#  suspended_on      :date
#  suspension_reason :string(250)
#  trade_name        :string(100)      not null
#  withholds_taxes   :boolean          default(FALSE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  collector_id      :bigint
#  created_by_id     :bigint
#  currency_id       :bigint
#  customer_type_id  :bigint
#  industry_id       :bigint
#  origin_id         :bigint
#  payment_term_id   :bigint
#  rating_id         :bigint
#  seller_id         :bigint
#  tax_id            :string(18)
#  updated_by_id     :bigint
#  zone_id           :bigint
#
# Indexes
#
#  index_crm_organizations_on_account_id                        (account_id)
#  index_crm_organizations_on_account_id_and_organization_type  (account_id,organization_type)
#  index_crm_organizations_on_collector_id                      (collector_id)
#  index_crm_organizations_on_created_by_id                     (created_by_id)
#  index_crm_organizations_on_currency_id                       (currency_id)
#  index_crm_organizations_on_customer_type_id                  (customer_type_id)
#  index_crm_organizations_on_industry_id                       (industry_id)
#  index_crm_organizations_on_origin_id                         (origin_id)
#  index_crm_organizations_on_payment_term_id                   (payment_term_id)
#  index_crm_organizations_on_rating_id                         (rating_id)
#  index_crm_organizations_on_seller_id                         (seller_id)
#  index_crm_organizations_on_updated_by_id                     (updated_by_id)
#  index_crm_organizations_on_zone_id                           (zone_id)
#  index_crm_organizations_unique_key                           (account_id, lower((key)::text)) UNIQUE WHERE (key IS NOT NULL)
#  index_crm_organizations_unique_legal_name                    (account_id, lower((legal_name)::text)) UNIQUE
#  index_crm_organizations_unique_trade_name                    (account_id, lower((trade_name)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (collector_id => crm_lookups.id) ON DELETE => nullify
#  fk_rails_...  (created_by_id => users.id) ON DELETE => nullify
#  fk_rails_...  (currency_id => crm_currencies.id) ON DELETE => nullify
#  fk_rails_...  (customer_type_id => crm_lookups.id) ON DELETE => nullify
#  fk_rails_...  (industry_id => crm_lookups.id) ON DELETE => nullify
#  fk_rails_...  (origin_id => crm_lookups.id) ON DELETE => nullify
#  fk_rails_...  (payment_term_id => crm_payment_terms.id) ON DELETE => nullify
#  fk_rails_...  (rating_id => crm_lookups.id) ON DELETE => nullify
#  fk_rails_...  (seller_id => crm_sellers.id) ON DELETE => nullify
#  fk_rails_...  (updated_by_id => users.id) ON DELETE => nullify
#  fk_rails_...  (zone_id => crm_lookups.id) ON DELETE => nullify
#

# CrmZeus O0 — organización: cliente o prospecto (CLIENTES / PROSPECTOS +
# CLIENTES_COMPLEMENTOS de CRMZeus). Un solo registro para los dos; convertir un
# prospecto en cliente cambia el tipo y conserva el id, como TIPO_ORGANIZACION_ID.
class CrmOrganization < ApplicationRecord
  DUPLICATE_MESSAGE = 'ya está dado de alta en otro cliente o prospecto'.freeze
  LOOKUP_REFERENCES = %i[customer_type rating industry origin zone collector].freeze

  belongs_to :account
  LOOKUP_REFERENCES.each { |name| belongs_to name, class_name: 'CrmLookup', optional: true }
  belongs_to :seller, class_name: 'CrmSeller', optional: true
  belongs_to :payment_term, class_name: 'CrmPaymentTerm', optional: true
  belongs_to :currency, class_name: 'CrmCurrency', optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  has_many :addresses, -> { order(is_primary: :desc, id: :asc) }, class_name: 'CrmOrganizationAddress',
                                                                  foreign_key: :organization_id, inverse_of: :organization,
                                                                  dependent: :destroy
  # Domicilio (pestaña «Dirección») y consignatarios (las demás direcciones).
  has_one :home_address, -> { where(is_primary: true) }, class_name: 'CrmOrganizationAddress', foreign_key: :organization_id,
                                                         inverse_of: :organization, dependent: nil # las borra :addresses
  has_many :consignees, -> { consignees.order(:consignee_name) }, class_name: 'CrmOrganizationAddress',
                                                                  foreign_key: :organization_id, inverse_of: :organization,
                                                                  dependent: nil # las borra :addresses
  accepts_nested_attributes_for :home_address, update_only: true
  # Contactos de Wintook ligados a la organización; borrarla solo los desliga.
  has_many :contact_links, class_name: 'CrmOrganizationContact', foreign_key: :organization_id,
                           inverse_of: :organization, dependent: :destroy
  has_many :contacts, through: :contact_links

  # Mismos valores que TIPO_ORGANIZACION_ID de CRMZeus.
  enum organization_type: { customer: 1, prospect: 2 }
  # Mismas letras que ESTATUS de Microsip.
  enum status: { active: 'A', credit_suspended: 'C', sales_suspended: 'V', delinquent: 'M', inactive: 'B' }, _prefix: :status

  before_validation :normalize

  validates :organization_type, :status, presence: true
  validates :legal_name, presence: true, length: { maximum: 100 }
  validates :trade_name, presence: true, length: { maximum: 100 }
  validates :key, length: { maximum: 20 }
  validates :legal_name, :trade_name, uniqueness: { scope: :account_id, case_sensitive: false, message: DUPLICATE_MESSAGE }
  validates :key, uniqueness: { scope: :account_id, case_sensitive: false, message: DUPLICATE_MESSAGE }, allow_nil: true
  validates :tax_id, length: { maximum: 18 }
  validates :credit_limit, numericality: { greater_than_or_equal_to: 0 }
  validates :suspension_reason, length: { maximum: 250 }
  validate :lookups_match_kind
  validate :references_belong_to_account

  scope :search, lambda { |term|
    next all if term.blank?

    like = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where('crm_organizations.legal_name ILIKE :q OR crm_organizations.trade_name ILIKE :q OR crm_organizations.key ILIKE :q', q: like)
  }

  # Prospecto → cliente. Conserva el id (las tareas y cotizaciones que lo apunten siguen ligadas).
  def convert_to_customer!(user = nil)
    raise ActiveRecord::RecordInvalid.new(self), 'ya es cliente' if customer?

    update!(organization_type: :customer, converted_at: Time.current, updated_by: user || updated_by)
  end

  private

  def normalize
    clean(%i[legal_name trade_name], &:squish)
    clean(%i[phone cfdi_use sat_payment_form]) { |value| value.strip.presence }
    clean(%i[key tax_id]) { |value| value.strip.upcase.presence }
    clean(%i[email invoice_email]) { |value| value.strip.downcase.presence }
    clear_suspension if status_active?
  end

  def clean(fields)
    fields.each { |field| self[field] = yield(self[field].to_s) }
  end

  # Fecha y causa de suspensión solo aplican si no está activo (como el formulario de CRMZeus).
  def clear_suspension
    self.suspended_on = nil
    self.suspension_reason = nil
  end

  def lookups_match_kind
    LOOKUP_REFERENCES.each do |name|
      lookup = public_send(name)
      errors.add(name, 'no corresponde a ese catálogo') if lookup && lookup.kind != name.to_s
    end
  end

  def references_belong_to_account
    (LOOKUP_REFERENCES + %i[seller payment_term currency]).each do |name|
      record = public_send(name)
      errors.add(name, 'no pertenece a la cuenta') if record && record.account_id != account_id
    end
  end
end
