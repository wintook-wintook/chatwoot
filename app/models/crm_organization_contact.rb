# == Schema Information
#
# Table name: crm_organization_contacts
#
#  id              :bigint           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  contact_id      :integer          not null
#  organization_id :bigint           not null
#
# Indexes
#
#  index_crm_organization_contacts_on_account_id       (account_id)
#  index_crm_organization_contacts_on_contact_id       (contact_id) UNIQUE
#  index_crm_organization_contacts_on_organization_id  (organization_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (organization_id => crm_organizations.id) ON DELETE => cascade
#

# CrmZeus C0 — liga entre un contacto de Wintook y su organización. Solo ids, como los
# componentes de un kit. Un contacto pertenece a una sola organización. Borrar la liga
# o la organización no borra al contacto; borrar al contacto borra su liga (cascade en BD).
class CrmOrganizationContact < ApplicationRecord
  belongs_to :account
  belongs_to :organization, class_name: 'CrmOrganization', inverse_of: :contact_links
  belongs_to :contact

  before_validation { self.account_id ||= organization&.account_id }

  validate :contact_is_free
  validate :contact_belongs_to_account

  private

  def contact_is_free
    return if contact_id.nil?

    other = self.class.includes(:organization).where(contact_id: contact_id).where.not(id: id).first
    errors.add(:contact, "ya pertenece a «#{other.organization.trade_name}»") if other
  end

  def contact_belongs_to_account
    errors.add(:contact, 'no pertenece a la cuenta') if contact && contact.account_id != account_id
  end
end
