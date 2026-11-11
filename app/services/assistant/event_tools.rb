# frozen_string_literal: true

# Asistente (Dali) — captar en la expo «acercando el celular» desde el teléfono:
#   nfc_links(event)          → el evento (por nombre o id), sus enlaces NFC con lo captado,
#                               las bandejas de WhatsApp posibles y el mensaje sugerido
#   propose_nfc_link          → tarjeta (evento, WhatsApp, vendedor, mensaje); al confirmar crea
#                               el enlace o reutiliza el del mismo vendedor y bandeja, y la tarjeta
#                               ofrece «Grabar en etiqueta» (Assistant::EventRunner)
# Ver: área Campañas; crear: poder escribir en ella. Se incluye en Assistant::Tools.
module Assistant::EventTools
  EVENT_READ_TOOLS = %w[nfc_links].freeze
  EVENT_PROPOSAL_TOOLS = %w[propose_nfc_link].freeze
  EVENT_SCAN = 300

  def tool_nfc_links(args)
    raise ArgumentError, 'No tienes acceso a Campañas › Eventos.' unless @grant.allowed?(:campaigns)

    events = find_events(args)
    return { events: events.map { |e| { id: e.id, name: e.name, starts_at: local(e.starts_at) } }, note: 'Pregunta cuál.' } if events.size != 1

    event = events.first
    { event: { id: event.id, name: event.name }, whatsapp_inboxes: nfc_inboxes.map { |i| i.slice(:id, :name) },
      default_message: I18n.t('events.capture.default_message', event: event.name),
      links: event.capture_links.includes(:inbox, :user).map { |l| nfc_link_ref(l) } }
  rescue ArgumentError => e
    { error: e.message }
  end

  def prepare_nfc_link(args)
    raise ArgumentError, 'No tienes permiso para crear enlaces en Campañas.' unless @grant.writable?(:campaigns)

    event = @account.events.find(args['event_id'])
    inbox = nfc_inbox(args['inbox_id'])
    seller = nfc_seller(args['seller'])
    message = args['message'].presence || I18n.t('events.capture.default_message', event: event.name)
    [{ 'event_id' => event.id, 'inbox_id' => inbox.id, 'user_id' => seller&.id, 'message' => message.to_s.first(400) },
     { 'rows' => [['EVENT', event.name], ['INBOX', inbox.name], ['SELLER', seller&.name]].select(&:last) }]
  end

  def nfc_inbox(id)
    inboxes = nfc_inboxes
    raise ArgumentError, 'No hay una bandeja de WhatsApp con número para el enlace.' if inboxes.empty?

    inbox = id.present? ? inboxes.find { |i| i[:id] == id.to_i } : (inboxes.first if inboxes.one?)
    raise ArgumentError, "¿Qué WhatsApp recibe? #{inboxes.pluck(:name).join(', ')}" unless inbox

    @account.inboxes.find(inbox[:id])
  end

  # El vendedor por nombre (o parte de él), entre los usuarios de la cuenta.
  def nfc_seller(name)
    return if name.blank?

    found = @account.users.where('users.name ILIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(name.to_s.strip)}%").limit(3).to_a
    raise ArgumentError, "No encontré al vendedor «#{name}»." if found.empty?
    raise ArgumentError, "Hay varios: #{found.map(&:name).join(', ')}. ¿Cuál?" if found.size > 1

    found.first
  end

  private

  # Por palabras, sin acentos ni mayúsculas («presentación kontrolya» = «PRESENTACION KONTROLYA»);
  # primero los abiertos y los más recientes.
  def find_events(args)
    return [@account.events.find(args['event_id'])] if args['event_id'].present?

    words = GlobalSearch.normalize(args['event']).split
    events = @account.events.order(Arel.sql("CASE WHEN status = #{Event.statuses[:closed]} THEN 1 ELSE 0 END"), starts_at: :desc)
                     .limit(EVENT_SCAN).to_a
    events = events.select { |e| words.all? { |w| GlobalSearch.normalize(e.name).include?(w) } } if words.any?
    events.first(5)
  end

  def nfc_inboxes
    @account.inboxes.where(channel_type: 'Channel::Whatsapp').includes(:channel).filter_map do |inbox|
      { id: inbox.id, name: inbox.name } if inbox.channel.try(:phone_number).present?
    end
  end

  def nfc_link_ref(link)
    { id: link.id, seller: link.user&.name, inbox: link.inbox.name, captured: link.captures_count, code: link.code }
  end
end
