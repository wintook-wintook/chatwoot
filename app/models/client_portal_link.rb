# frozen_string_literal: true

# Portal del cliente — el enlace sin usuario (/cliente/:token) con el que una
# organización (o un contacto sin organización) ve sus casos y proyectos y trabaja las
# tareas que le tocan. No caduca; se renueva (el anterior deja de servir) o se desactiva.
class ClientPortalLink < ApplicationRecord
  belongs_to :account
  belongs_to :organization, optional: true
  belongs_to :contact, optional: true

  before_validation :assign_token, on: :create

  validates :token, presence: true, uniqueness: true
  validate :one_owner

  scope :active, -> { where(active: true) }

  # El enlace vigente de la organización o del contacto (lo crea si no hay).
  def self.for!(account:, organization: nil, contact: nil, user: nil)
    owner = organization ? { organization: organization } : { contact: contact }
    account.client_portal_links.active.find_by(owner) ||
      account.client_portal_links.create!(owner.merge(created_by_id: user&.id))
  end

  def owner
    organization || contact
  end

  def url
    "#{ENV.fetch('FRONTEND_URL', '')}/cliente/#{token}"
  end

  # Renovar: el enlace anterior deja de servir.
  def renew!(user = nil)
    transaction do
      update!(active: false)
      self.class.create!(account: account, organization: organization, contact: contact, created_by_id: user&.id)
    end
  end

  # Quiénes pueden firmar lo que hacen en el portal.
  def people
    organization ? account.contacts.where(organization_id: organization.id).order(:name) : Contact.where(id: contact_id)
  end

  # Los casos que ve: los de la organización (o de sus contactos) o los del contacto.
  # Sin oportunidades (son de ventas, internas).
  def cases
    scope = account.case_tickets.where.not(case_type_id: CaseType.where(case_class: :commercial).select(:id))
    return scope.where(contact_id: contact_id) if organization.nil?

    scope.where('case_tickets.organization_id = :org OR case_tickets.contact_id IN (:people)',
                org: organization.id, people: people.select(:id))
  end

  private

  def assign_token
    self.token ||= SecureRandom.urlsafe_base64(18)
  end

  def one_owner
    errors.add(:base, 'Necesita una organización o un contacto') if organization_id.blank? && contact_id.blank?
  end
end
