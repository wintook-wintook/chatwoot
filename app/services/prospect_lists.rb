# frozen_string_literal: true

# Listas frías de correo de las Campañas con Vendedor IA (ProspectList, ProspectLists::Import, ProspectLists::CleanupJob).
module ProspectLists
  module_function

  # Contestó o dio clic: deja la cuarentena y ya es un contacto normal (sale en Contactos).
  def promote!(contact)
    return unless contact&.list_quarantine?

    contact.update_columns(list_quarantine: false, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end
end
