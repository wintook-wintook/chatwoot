# Mueve las conversaciones de Instagram de un inbox legacy (Channel::FacebookPage, donde
# Instagram viajaba junto a Messenger) al inbox del canal nativo.
#
# El inbox legacy NO se toca más allá de eso: sigue sirviendo Messenger con sus agentes,
# horarios, automatizaciones y campañas. Solo se lleva lo que es de Instagram.
#
# Los `source_id` (IGSID) se conservan entre ambas APIs, así que las conversaciones
# históricas siguen entregando después de mover. Ver docs/instagram_plan.md §6 F7
class Instagram::MigrationService
  # Tablas que cuelgan de la conversación y viajan con ella
  CONVERSATION_SCOPED_TABLES = %w[reporting_events sla_events contact_trackings command_sessions].freeze

  attr_reader :report

  # Inboxes que todavía sirven Instagram a través de un Channel::FacebookPage, con el
  # canal nativo correspondiente si ya se conectó.
  def self.pending
    Channel::FacebookPage.where.not(instagram_id: nil).filter_map do |channel|
      inbox = channel.inbox
      next if inbox.blank?

      {
        inbox_id: inbox.id,
        account_id: inbox.account_id,
        name: inbox.name,
        instagram_id: channel.instagram_id,
        instagram_conversations: inbox.conversations.where("additional_attributes ->> 'type' = 'instagram_direct_message'").count,
        native_inbox_id: Channel::Instagram.find_by(instagram_id: channel.instagram_id)&.inbox&.id
      }
    end
  end

  # Informe legible del listado anterior, para la tarea rake
  def self.pending_report
    rows = pending
    return 'No queda ningún inbox con Instagram dentro de un Channel::FacebookPage.' if rows.empty?

    header = format('%-8<a>s %-9<b>s %-26<c>s %-30<d>s %<e>s', a: 'INBOX', b: 'CUENTA', c: 'IGSID', d: 'NOMBRE', e: 'CANAL NATIVO')
    lines = rows.map do |row|
      target = row[:native_inbox_id] ? "inbox #{row[:native_inbox_id]}" : "SIN CONECTAR (#{row[:instagram_conversations]} conv. de IG)"
      format('%-8<a>s %-9<b>s %-26<c>s %-30<d>s %<e>s',
             a: row[:inbox_id], b: row[:account_id], c: row[:instagram_id], d: row[:name].to_s.truncate(28), e: target)
    end
    [header, *lines].join("\n")
  end

  def initialize(legacy_inbox:, native_inbox:, apply: false)
    @legacy_inbox = legacy_inbox
    @native_inbox = native_inbox
    @apply = apply
    @report = {}
  end

  def perform
    validate!
    build_report

    ActiveRecord::Base.transaction { migrate! } if @apply

    @report
  end

  private

  def validate!
    raise ArgumentError, "el inbox #{@legacy_inbox.id} no es un Channel::FacebookPage" unless @legacy_inbox.facebook?
    raise ArgumentError, "el inbox #{@native_inbox.id} no es un Channel::Instagram" unless @native_inbox.native_instagram?

    if @legacy_inbox.account_id != @native_inbox.account_id
      raise ArgumentError,
            'los dos inboxes pertenecen a cuentas distintas'
    end

    return if @legacy_inbox.channel.instagram_id == @native_inbox.channel.instagram_id

    raise ArgumentError, 'los inboxes no corresponden a la misma cuenta de Instagram (IGSID distinto)'
  end

  def build_report
    @report = {
      account_id: @legacy_inbox.account_id,
      instagram_id: @native_inbox.channel.instagram_id,
      legacy_inbox: { id: @legacy_inbox.id, name: @legacy_inbox.name },
      native_inbox: { id: @native_inbox.id, name: @native_inbox.name },
      conversations: conversations.count,
      messages: messages.count,
      contact_inboxes: contact_inboxes.count,
      members_to_copy: members_to_copy.count,
      # Lo que se queda en el inbox legacy porque es de Messenger
      messenger_conversations_left_behind: messenger_conversations.count,
      applied: @apply
    }

    CONVERSATION_SCOPED_TABLES.each do |table|
      @report[table.to_sym] = scoped_relation(table).count
    end
  end

  def migrate!
    # Los identificadores se congelan ANTES de mover nada: las relaciones se definen por
    # `inbox_id = legacy`, así que en cuanto se actualizan las conversaciones dejarían de
    # encontrarse a sí mismas y el resto de tablas se quedaría sin migrar.
    ids = conversation_ids
    contact_inbox_ids = contact_inboxes.pluck(:id)

    # update_all a propósito: es un traslado masivo de filas entre inboxes. Disparar
    # callbacks aquí reenviaría eventos y notificaciones de conversaciones históricas.
    # rubocop:disable Rails/SkipsModelValidations
    ContactInbox.where(id: contact_inbox_ids).update_all(inbox_id: @native_inbox.id)
    Conversation.where(id: ids).update_all(inbox_id: @native_inbox.id)
    Message.where(conversation_id: ids).update_all(inbox_id: @native_inbox.id)

    CONVERSATION_SCOPED_TABLES.each do |table|
      table.classify.constantize.where(conversation_id: ids).update_all(inbox_id: @native_inbox.id)
    end
    # rubocop:enable Rails/SkipsModelValidations

    copy_members
    detach_instagram_from_legacy_channel
  end

  def conversation_ids
    @conversation_ids ||= conversations.pluck(:id)
  end

  # Sin esto los agentes perderían el acceso a las conversaciones recién movidas: el inbox
  # nativo nace sin miembros. Se copian, no se mueven — el legacy sigue con Messenger.
  def copy_members
    members_to_copy.find_each do |member|
      InboxMember.create!(inbox: @native_inbox, user_id: member.user_id)
    end
  end

  # El canal legacy deja de reclamar este IGSID, así que el router ya no puede resolverlo
  # por la ruta antigua ni aunque la app vieja siguiera entregando.
  def detach_instagram_from_legacy_channel
    @legacy_inbox.channel.update!(instagram_id: nil)
  end

  def conversations
    @conversations ||= @legacy_inbox.conversations
                                    .where("additional_attributes ->> 'type' = 'instagram_direct_message'")
  end

  def messenger_conversations
    @legacy_inbox.conversations.where.not(id: conversations.select(:id))
  end

  def messages
    Message.where(conversation_id: conversations.select(:id))
  end

  # Solo los contactos que llegaron por Instagram: su source_id es el IGSID, un espacio de
  # identificadores distinto al PSID de Messenger.
  def contact_inboxes
    ContactInbox.where(id: conversations.select(:contact_inbox_id))
  end

  def members_to_copy
    existing = InboxMember.where(inbox_id: @native_inbox.id).select(:user_id)
    InboxMember.where(inbox_id: @legacy_inbox.id).where.not(user_id: existing)
  end

  def scoped_relation(table)
    table.classify.constantize.where(conversation_id: conversations.select(:id))
  end
end
