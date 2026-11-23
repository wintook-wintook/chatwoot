# frozen_string_literal: true

# Listas frías de correo de las Campañas con Vendedor IA (ProspectList, ProspectLists::Import, ProspectLists::CleanupJob).
module ProspectLists
  module_function

  # Contestó o dio clic: deja la cuarentena y ya es un contacto normal (sale en Contactos). Si la lista traía su
  # empresa, se liga a esa organización (la que ya exista con ese nombre o una nueva, como prospecto).
  def promote!(contact)
    return unless contact&.list_quarantine?

    contact.update_columns(list_quarantine: false, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    link_organization(contact)
  end

  def link_organization(contact)
    company = contact.additional_attributes.to_h['company_name'].to_s.strip
    return if contact.organization_id || company.blank?

    organization = contact.account.organizations.where('LOWER(name) = ?', company.downcase).first || new_organization(contact)
    contact.update!(organization: organization)
  rescue StandardError => e
    Rails.logger.warn("[ProspectLists] organización del contacto #{contact.id}: #{e.class}: #{e.message}")
  end

  def new_organization(contact)
    organization = Organization.build_for(contact, stage: :prospect)
    organization.save!
    organization.events.create!(action: 'created', data: { to: 'prospect', reason: 'prospect_list' })
    organization
  end
end
