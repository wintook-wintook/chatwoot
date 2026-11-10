# Fusiona dos contactos: todo lo del que se elimina (mergee) pasa al que se queda (base).
# Si los dos tienen el mismo dato, gana el del que se queda. Antes de borrarlo se
# mueven también los registros de Kontrolya (cotizaciones, contratos, casos, equipos…)
# para que no se pierdan con el contacto.
class ContactMergeAction
  include Events::Types

  # Tablas con contact_id que pasan completas al contacto que se queda.
  MOVED_RECORDS = %w[Quote CustomerAsset MaintenancePlan Contract CaseTicket CaseTask CaseMeeting TaskReport AiFollowUp
                     Call CsatSurveyResponse].freeze
  # Solo puede haber uno vivo por contacto y bandeja (index_unique_active_tracking_per_contact_inbox).
  ACTIVE_TRACKINGS = %w[pending scheduled active paused].freeze
  pattr_initialize [:account!, :base_contact!, :mergee_contact!]

  def perform
    # This case happens when an agent updates a contact email in dashboard,
    # while the contact also update his email via email collect box
    return @base_contact if base_contact.id == mergee_contact.id

    ActiveRecord::Base.transaction do
      validate_contacts
      merge_conversations
      merge_messages
      merge_contact_inboxes
      merge_contact_notes
      merge_platform_records
      merge_and_remove_mergee_contact
    end
    @base_contact
  end

  private

  def validate_contacts
    return if belongs_to_account?(@base_contact) && belongs_to_account?(@mergee_contact)

    raise StandardError, 'contact does not belong to the account'
  end

  def belongs_to_account?(contact)
    @account.id == contact.account_id
  end

  def merge_conversations
    Conversation.where(contact_id: @mergee_contact.id).update(contact_id: @base_contact.id)
  end

  def merge_contact_notes
    Note.where(contact_id: @mergee_contact.id, account_id: @mergee_contact.account_id).update(contact_id: @base_contact.id)
  end

  def merge_messages
    Message.where(sender: @mergee_contact).update(sender: @base_contact)
  end

  def merge_contact_inboxes
    ContactInbox.where(contact_id: @mergee_contact.id).update(contact_id: @base_contact.id)
  end

  # Mover en bloque sin callbacks: solo cambia de dueño, el resto del registro no se toca.
  # rubocop:disable Rails/SkipsModelValidations
  def merge_platform_records
    MOVED_RECORDS.each { |model| model.constantize.where(contact_id: @mergee_contact.id).update_all(contact_id: @base_contact.id) }
    move_unless_taken(EventAttendee, :event_id)
    move_unless_taken(TrackingCampaignEntry, :tracking_campaign_id)
    move_unless_taken(ContactTracking.where(status: ACTIVE_TRACKINGS), :inbox_id)
    ContactTracking.where(contact_id: @mergee_contact.id).where.not(status: ACTIVE_TRACKINGS)
                   .update_all(contact_id: @base_contact.id)
    move_budget_lines
  end

  # Lo que ya tiene el que se queda (mismo evento, misma campaña…) no se duplica: el del
  # contacto eliminado se va con él.
  def move_unless_taken(scope, column)
    taken = scope.where(contact_id: @base_contact.id).select(column)
    scope.where(contact_id: @mergee_contact.id).where.not(column => taken).update_all(contact_id: @base_contact.id)
  end

  def move_budget_lines
    dims = %i[period currency user_id organization_id product_line_id catalog_item_id]
    taken = SalesBudgetLine.where(contact_id: @base_contact.id).pluck(*dims)
    SalesBudgetLine.where(contact_id: @mergee_contact.id).find_each do |line|
      line.update_columns(contact_id: @base_contact.id) unless taken.include?(dims.map { |d| line[d] })
    end
  end
  # rubocop:enable Rails/SkipsModelValidations

  def merge_and_remove_mergee_contact
    mergable_attribute_keys = %w[identifier name email phone_number additional_attributes custom_attributes owner_id organization_id]
    base_contact_attributes = base_contact.attributes.slice(*mergable_attribute_keys).compact_blank
    mergee_contact_attributes = mergee_contact.attributes.slice(*mergable_attribute_keys).compact_blank

    # attributes in base contact are given preference
    merged_attributes = mergee_contact_attributes.deep_merge(base_contact_attributes)

    @mergee_contact.destroy!
    Rails.configuration.dispatcher.dispatch(CONTACT_MERGED, Time.zone.now, contact: @base_contact,
                                                                           tokens: [@base_contact.contact_inboxes.filter_map(&:pubsub_token)])
    @base_contact.update!(merged_attributes)
  end
end
