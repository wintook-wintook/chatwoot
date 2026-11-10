# Plan-Agenda — de quién es una tarea o tarea agendada. Con caso, su cliente es el del caso.
# Sin caso guarda contacto u organización (la del contacto manda), o nada: es interna.
module AgendaLink
  extend ActiveSupport::Concern

  included do
    belongs_to :contact, optional: true
    belongs_to :organization, optional: true

    scope :without_case, -> { where(case_ticket_id: nil) }

    before_validation :sync_agenda_client
  end

  def client_contact
    case_ticket ? case_ticket.contact : contact
  end

  def client_organization
    case_ticket ? case_ticket.organization : organization
  end

  private

  def sync_agenda_client
    if case_ticket
      self.contact = nil
      self.organization = nil
    elsif contact&.organization_id && (new_record? || contact_id_changed?)
      self.organization_id = contact.organization_id
    end
  end
end
