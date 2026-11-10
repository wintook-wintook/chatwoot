# Plan-Organizaciones O2 — registros del cliente (casos, cotizaciones, contratos, equipos,
# mantenimientos) con su organización. Si no se elige, al crearlo toma la del contacto;
# después se queda aunque el contacto cambie de empresa.
module OrganizationLinked
  extend ActiveSupport::Concern

  included do
    belongs_to :organization, optional: true
    before_validation :fill_organization_from_contact, on: :create
    validate :organization_in_account, if: :will_save_change_to_organization_id?
  end

  private

  def fill_organization_from_contact
    self.organization_id ||= contact&.organization_id
  end

  def organization_in_account
    return if organization.nil? || organization.account_id == account_id

    errors.add(:organization_id, 'no es de la cuenta')
  end
end
