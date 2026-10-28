# Responsable fijo del contacto (contacts.owner_id): sus conversaciones van
# siempre con esa persona, por encima de la asignación por turnos, las
# automatizaciones, las reglas y los Agentes IA.
#
# - Al abrirse (nueva y abierta, o reabierta) se asigna al responsable fijo.
# - Si algo automático cambia el responsable de una conversación abierta, se
#   regresa al responsable fijo.
# - Una persona sí puede cambiarlo a mano en ESA conversación: los caminos
#   humanos (asignar desde la conversación y la asignación en lote) marcan
#   `manual_assignment`. La siguiente vez que se abra vuelve al responsable fijo.
# - Solo aplica en las bandejas donde el responsable es miembro (si no, no la
#   vería); ahí siguen las reglas normales.
# - En pendiente (la atiende un bot) no se toca: se asigna cuando pasa a abierta.
module ContactOwnerAssignment
  extend ActiveSupport::Concern

  included do
    attr_accessor :manual_assignment

    before_save :keep_contact_owner
    after_commit :note_contact_owner, if: -> { @contact_owner_note.present? }
  end

  private

  def keep_contact_owner
    @contact_owner_note = nil
    return unless contact_owner_applies?

    owner_id = contact_owner_id_for_inbox
    return if owner_id.nil? || assignee_id == owner_id || (new_record? && starts_with_bot?)

    @contact_owner_note = contact_owner_opening? ? :contact_owner : :contact_owner_kept
    self.assignee_id = owner_id
  end

  # Abierta, y abriéndose o con un cambio de responsable que no fue a mano.
  def contact_owner_applies?
    return false unless open?
    return true if contact_owner_opening?

    will_save_change_to_assignee_id? && !manual_assignment
  end

  def contact_owner_opening?
    new_record? || will_save_change_to_status?
  end

  # Igual que Conversation#determine_conversation_status (corre después): la
  # nueva nace pendiente con un bot activo, o resuelta si el contacto está bloqueado.
  def starts_with_bot?
    contact.blocked? || (campaign.blank? && inbox.active_bot?)
  end

  def contact_owner_id_for_inbox
    owner_id = contact&.effective_owner_id # el suyo o el de su organización (Plan-Organizaciones O3)
    return if owner_id.nil?

    owner_id if inbox.inbox_members.exists?(user_id: owner_id)
  end

  def note_contact_owner
    key = @contact_owner_note
    @contact_owner_note = nil
    content = I18n.t("conversations.activity.assignee.#{key}", assignee_name: assignee&.name)
    ::Conversations::ActivityMessageJob.perform_later(self, activity_message_params(content))
  end
end
