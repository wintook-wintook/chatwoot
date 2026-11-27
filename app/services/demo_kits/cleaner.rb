# frozen_string_literal: true

# Ajustes › Demostraciones — después de la demo:
#   clean   «Limpiar lo de la demo»: borra lo que salió mientras se probaba — las pláticas de las bandejas que creó la
#           demo y las que atendieron sus agentes desde que se importó, sus seguimientos, cotizaciones, oportunidades y
#           citas (la cita se cancela y su evento de Google se borra) y los contactos que solo existen por esas pláticas.
#           La configuración (agentes, catálogo, bandejas) se queda.
#   remove  «Quitar la demo»: lo anterior y además lo que creó la importación (agentes, bandejas, productos que nada
#           más usa, categorías vacías). Lo que la cuenta ya tenía y la demo solo actualizó no se borra.
#
#   DemoKits::Cleaner.new(demo_import).clean → { conversations:, contacts:, quotes:, meetings: }
class DemoKits::Cleaner
  def initialize(demo_import)
    @demo = demo_import
    @account = demo_import.account
  end

  def clean
    conversations = demo_conversations.to_a
    contact_ids = conversations.map(&:contact_id).uniq
    counts = { conversations: conversations.size, quotes: 0, meetings: 0, contacts: 0 }
    ActiveRecord::Base.transaction do
      counts[:meetings] = cancel_meetings(contact_ids)
      counts[:quotes] = destroy_quotes(contact_ids)
      ContactTracking.where(conversation_id: conversations.map(&:id)).delete_all
      conversations.each(&:destroy!)
      counts[:contacts] = destroy_lonely_contacts(contact_ids)
    end
    counts
  end

  def remove
    counts = clean
    ActiveRecord::Base.transaction do
      remove_agents
      @account.inboxes.where(id: @demo.ids(:inbox_ids)).find_each(&:destroy!)
      remove_catalog
      @demo.destroy!
    end
    counts
  end

  private

  def since = @demo.created_at

  def demo_conversations
    by_inbox = @account.conversations.where(inbox_id: @demo.ids(:inbox_ids))
    by_agent = @account.conversations.where(created_at: since..)
                       .where(id: ContactTracking.where(tracking_template_id: @demo.ids(:tracking_template_ids)).select(:conversation_id))
    by_inbox.or(by_agent)
  end

  # Las citas de esos contactos desde la demo: se cancelan (su evento de Google se borra) y se quitan.
  def cancel_meetings(contact_ids)
    meetings = CaseMeeting.where(account_id: @account.id, contact_id: contact_ids, created_at: since..)
    meetings.each do |meeting|
      Cases::Meetings::GoogleMirrorService.new(meeting).cancel if meeting.google_event_id.present?
    rescue StandardError => e
      Rails.logger.warn("[DemoKits::Cleaner] Google #{meeting.id}: #{e.message}")
    end
    meetings.destroy_all.size
  end

  # Cotizaciones de la demo y su oportunidad (si no tiene otras cotizaciones).
  def destroy_quotes(contact_ids)
    quotes = @account.quotes.where(contact_id: contact_ids, created_at: since..)
    opportunity_ids = quotes.filter_map(&:opportunity_id).uniq
    count = quotes.destroy_all.size
    CaseTicket.where(id: opportunity_ids).where.not(id: @account.quotes.select(:opportunity_id)).destroy_all
    CaseTicket.where(account_id: @account.id, contact_id: contact_ids, created_at: since..).destroy_all
    count
  end

  # Los contactos que nacieron en la demo y ya no tienen otra plática.
  def destroy_lonely_contacts(contact_ids)
    lonely = @account.contacts.where(id: contact_ids, created_at: since..).where.not(id: @account.conversations.select(:contact_id))
    lonely.destroy_all.size
  end

  # En uso (campañas, versiones) se archiva; si no, se borra.
  # Sus versiones las creó la demo: se van con él. Si algo más lo usa, se archiva y suelta sus bandejas (para poder
  # borrarlas).
  def remove_agents
    @account.tracking_templates.where(id: @demo.ids(:tracking_template_ids)).find_each do |template|
      Motor2Version.where(tracking_template_id: template.id).delete_all unless template.in_use?
      template.in_use? ? archive(template) : destroy_quietly(template)
    rescue ActiveRecord::InvalidForeignKey
      archive(template)
    end
  end

  def archive(template)
    template.update_columns(archived_at: Time.current, attending: false, attend_inbox_ids: [], inbox_id: nil, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  # Con historia (versiones, pruebas) no se puede borrar: el error no debe tumbar lo demás (savepoint) y se archiva.
  def destroy_quietly(record)
    ActiveRecord::Base.transaction(requires_new: true) { record.destroy! }
  end

  # Los productos que creó y nada más usa (si ya están en una cotización, se desactivan) y las categorías vacías.
  def remove_catalog
    @account.catalog_items.where(id: @demo.ids(:catalog_item_ids)).find_each do |item|
      QuoteItem.exists?(catalog_item_id: item.id) ? item.update!(active: false) : destroy_quietly(item)
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
      item.update!(active: false)
    end
    @account.catalog_categories.where(id: @demo.ids(:catalog_category_ids)).order(parent_id: :desc).each do |category|
      category.destroy! unless category.in_use?
    end
  end
end
