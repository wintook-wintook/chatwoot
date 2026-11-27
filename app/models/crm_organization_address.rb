# == Schema Information
#
# Table name: crm_organization_addresses
#
#  id              :bigint           not null, primary key
#  consignee_name  :string(100)      not null
#  contact_name    :string(100)
#  email           :string
#  exterior_number :string(10)
#  for_billing     :boolean          default(FALSE), not null
#  interior_number :string(10)
#  is_primary      :boolean          default(FALSE), not null
#  neighborhood    :string(100)
#  phone           :string(35)
#  phone2          :string(35)
#  postal_code     :string(10)
#  reference       :string(100)
#  street          :string(100)
#  town            :string(100)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  city_id         :bigint
#  organization_id :bigint           not null
#  tax_id          :string(18)
#
# Indexes
#
#  index_crm_organization_addresses_on_account_id       (account_id)
#  index_crm_organization_addresses_on_city_id          (city_id)
#  index_crm_organization_addresses_on_organization_id  (organization_id)
#  index_crm_organization_addresses_one_billing         (organization_id) UNIQUE WHERE for_billing
#  index_crm_organization_addresses_one_primary         (organization_id) UNIQUE WHERE is_primary
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (city_id => crm_cities.id) ON DELETE => nullify
#  fk_rails_...  (organization_id => crm_organizations.id) ON DELETE => cascade
#

# CrmZeus O0 — dirección de una organización (DIRS_CLIENTES de Microsip). La principal es
# el domicilio (pestaña «Dirección» del formulario); las demás son consignatarios, que las
# cotizaciones eligen. Como en CRMZeus: un consignatario nunca pasa a ser el domicilio y
# solo una dirección de la organización es «para facturar».
class CrmOrganizationAddress < ApplicationRecord
  belongs_to :account
  belongs_to :organization, class_name: 'CrmOrganization', inverse_of: :addresses
  belongs_to :city, class_name: 'CrmCity', optional: true

  before_validation :normalize
  before_save :clear_other_billing, if: -> { for_billing? && organization_id.present? }
  before_destroy :keep_home_address, if: :is_primary?

  validates :consignee_name, presence: true, length: { maximum: 100 }
  validates :street, :neighborhood, :town, :reference, :contact_name, length: { maximum: 100 }
  validates :exterior_number, :interior_number, :postal_code, length: { maximum: 10 }
  validates :phone, :phone2, length: { maximum: 35 }
  validates :tax_id, length: { maximum: 18 }
  validate :single_home_address
  validate :city_belongs_to_account

  scope :consignees, -> { where(is_primary: false) }

  # «Calle 123 Int 4, Colonia, Población, Torreón, COA, México, CP 27000» (lo que CRMZeus guarda en CALLE).
  def full_address
    numbers = [exterior_number, interior_number.presence && "Int #{interior_number}"].compact.join(' ')
    line = [street, numbers.presence].compact.join(' ')
    [line.presence, neighborhood, town, city&.full_name, postal_code.presence && "CP #{postal_code}"].compact.join(', ')
  end

  private

  def normalize
    clean(%i[street exterior_number interior_number neighborhood town reference postal_code phone phone2 contact_name]) do |value|
      value.strip.presence
    end
    clean([:tax_id]) { |value| value.strip.upcase.presence }
    clean([:email]) { |value| value.strip.downcase.presence }
    self.account_id ||= organization&.account_id
    self.consignee_name = consignee_name.to_s.squish.presence || organization&.legal_name
  end

  def clean(fields)
    fields.each { |field| self[field] = yield(self[field].to_s) }
  end

  def single_home_address
    return unless is_primary? && organization_id.present?
    return unless self.class.where(organization_id: organization_id, is_primary: true).where.not(id: id).exists?

    errors.add(:is_primary, 'la organización ya tiene domicilio')
  end

  def clear_other_billing
    siblings = self.class.where(organization_id: organization_id, for_billing: true).where.not(id: id)
    siblings.update_all(for_billing: false) # rubocop:disable Rails/SkipsModelValidations
  end

  # El domicilio solo se va junto con la organización.
  def keep_home_address
    return if destroyed_by_association

    errors.add(:base, 'el domicilio no se puede borrar, solo editar')
    throw :abort
  end

  def city_belongs_to_account
    errors.add(:city, 'no pertenece a la cuenta') if city && city.account_id != account_id
  end
end
