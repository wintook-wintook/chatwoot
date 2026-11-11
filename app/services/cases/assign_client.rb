# frozen_string_literal: true

# «Ligar a un cliente»: un caso interno (se creó sin cliente) pasa a ser de un cliente.
# Toma el contacto y la organización (si no se elige, la del contacto); deja de ser interno
# (origen manual) y queda en la actividad. Quien lo pidió se queda como solicitante.
# Se puede también con el caso cerrado: es corregir de quién es, no trabajarlo.
#
#   Cases::AssignClient.new(ticket, user:).call(contact_id:, organization_id: nil) → ticket
class Cases::AssignClient
  class Error < StandardError; end

  def initialize(ticket, user:)
    @ticket = ticket
    @account = ticket.account
    @user = user
  end

  def call(contact_id:, organization_id: nil)
    fail_with('not_internal') unless @ticket.internal?
    contact = @account.contacts.find_by(id: contact_id) || fail_with('contact_required')
    organization = pick_organization(organization_id, contact)

    ActiveRecord::Base.transaction do
      @ticket.update!(contact: contact, organization: organization, origin: :manual)
      @ticket.case_events.create!(account: @account, event_type: :client_assigned, origin: @user ? :agent : :system,
                                  actor: @user, payload: { organization: organization&.name, contact: contact.name })
    end
    @ticket
  end

  private

  def pick_organization(organization_id, contact)
    return contact.organization if organization_id.blank?

    organization = @account.organizations.find_by(id: organization_id) || fail_with('organization_missing')
    fail_with('contact_other_organization') if contact.organization_id && contact.organization_id != organization.id
    organization
  end

  def fail_with(key)
    raise Error, I18n.with_locale(@account.locale.presence || I18n.default_locale) { I18n.t("assign_client.errors.#{key}") }
  end
end
