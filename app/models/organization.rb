# == Schema Information
#
# Table name: organizations
#
#  id                 :bigint           not null, primary key
#  address            :text
#  became_customer_at :datetime
#  became_prospect_at :datetime
#  custom_attributes  :jsonb            not null
#  email_domain       :string
#  industry           :string
#  kind               :integer          default("company"), not null
#  name               :string           not null
#  notes              :text
#  phone_number       :string
#  stage              :integer          default("prospect"), not null
#  website            :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  owner_id           :bigint
#  tax_id             :string
#
# Indexes
#
#  index_organizations_on_account_id             (account_id)
#  index_organizations_on_account_id_and_stage   (account_id,stage)
#  index_organizations_on_account_id_and_tax_id  (account_id,tax_id) UNIQUE WHERE (tax_id IS NOT NULL)
#  index_organizations_on_owner_id               (owner_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (owner_id => users.id) ON DELETE => nullify
#
# Plan-Organizaciones O1 — la empresa o el público en general detrás de los contactos.
#
# Dos cosas aparte:
#   stage  prospecto o cliente: lo que cambia con el tiempo. Pasar a cliente solo cambia
#          esto (y la fecha); lo demás queda igual.
#   kind   empresa (se le factura: RFC y datos fiscales; incluye persona física con RFC) o
#          público en general (sin factura).
# El contacto apunta a una sola organización (contacts.organization_id); sin ella es
# «contacto», como siempre.
class Organization < ApplicationRecord
  belongs_to :account
  belongs_to :owner, class_name: 'User', optional: true
  has_many :contacts, dependent: :nullify
  has_many :events, class_name: 'OrganizationEvent', dependent: :destroy

  enum stage: { prospect: 0, customer: 1 }
  enum kind: { company: 0, general_public: 1 }

  before_validation :normalize

  validates :name, presence: true, length: { maximum: 200 }
  validates :tax_id, uniqueness: { scope: :account_id, case_sensitive: false }, allow_nil: true
  validate :owner_in_account

  scope :ordered, -> { order(:name) }

  def self.search(term)
    return all if term.blank?

    like = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where('organizations.name ILIKE :q OR organizations.tax_id ILIKE :q OR organizations.email_domain ILIKE :q', q: like)
  end

  # Nueva desde un contacto: su empresa escrita o, sin ella, público en general con su nombre.
  def self.build_for(contact, attrs = {})
    company = contact.additional_attributes.to_h['company_name'].to_s.strip.presence
    new({ account: contact.account, name: company || contact.name, kind: company ? :company : :general_public,
          email_domain: contact.email.to_s.split('@')[1] }.merge(attrs.compact))
  end

  # reason: la regla automática que lo hizo (Organizations::StageRules); sin ella, a mano.
  def change_stage!(new_stage, user, reason: nil)
    return if stage == new_stage.to_s

    from = stage
    self.stage = new_stage
    self.became_customer_at ||= Time.current if customer?
    transaction do
      save!
      events.create!(user: user, action: 'stage', data: { from: from, to: stage, reason: reason }.compact)
    end
  end

  private

  def normalize
    self.name = name.to_s.strip
    %i[website email_domain industry phone_number].each { |field| self[field] = self[field].to_s.strip.presence }
    self.email_domain = email_domain&.downcase
    # Público en general no factura: sin RFC.
    self.tax_id = general_public? ? nil : tax_id.to_s.strip.upcase.presence
    stamp_stage
  end

  def stamp_stage
    self.became_prospect_at ||= Time.current
    self.became_customer_at ||= Time.current if customer?
  end

  def owner_in_account
    return if owner_id.nil? || account.account_users.exists?(user_id: owner_id)

    errors.add(:owner_id, 'no es un usuario de la cuenta')
  end
end
