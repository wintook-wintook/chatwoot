# frozen_string_literal: true

# @query_databases — Modo A: corre la consulta masiva del bot (facturas por vencer /
# vencidas con teléfono del cliente) y, por cada fila, compone el recordatorio y lo
# entrega por el inbox del bot (reusa Messages::MessageBuilder, como contact_tracking).
# Devuelve un resumen { sent:, skipped:, errors: } sin lanzar (best-effort por fila).
class ErpCollection::ReminderService
  def initialize(bot)
    @bot = bot
    @account = bot.account
  end

  def perform
    summary = { sent: 0, skipped: 0, errors: 0 }
    rows.each do |row|
      deliver_row(row, summary)
    end
    @bot.update!(last_run_at: Time.current)
    summary
  end

  # Modo dry-run para pruebas/preview: compone los mensajes sin enviar nada.
  def preview(limit: 5)
    rows.first(limit).map { |row| { phone: phone_of(row), message: @bot.render_message(row) } }
  end

  private

  def rows
    return [] unless @bot.external_db_query

    ExternalDb::QueryRunner.new(@bot.external_db_query, {}).perform.rows
  rescue StandardError => e
    Rails.logger.error "[ErpCollection] error consultando bot ##{@bot.id}: #{e.message}"
    []
  end

  def deliver_row(row, summary)
    phone = phone_of(row)
    contact = resolve_contact(phone)
    if phone.blank? || contact.nil? || @bot.inbox.nil?
      summary[:skipped] += 1
      return
    end
    send_reminder(contact, @bot.render_message(row)) ? (summary[:sent] += 1) : (summary[:errors] += 1)
  rescue StandardError => e
    Rails.logger.error "[ErpCollection] fila falló (bot ##{@bot.id}): #{e.message}"
    summary[:errors] += 1
  end

  def phone_of(row)
    row[@bot.phone_column] || row[@bot.phone_column.to_s.upcase] || row[@bot.phone_column.to_s.downcase]
  end

  # Resuelve el contacto de Chatwoot por teléfono (decisión: match por tel/email).
  def resolve_contact(phone)
    return nil if phone.blank?

    digits = phone.to_s.gsub(/\D/, '')
    return nil if digits.blank?

    @account.contacts.where('phone_number LIKE ?', "%#{digits}").first
  end

  def send_reminder(contact, body)
    return false if body.blank?

    conversation = find_or_create_conversation(contact)
    message = Messages::MessageBuilder.new(
      bot_user, conversation, { content: body, private: false }
    ).perform
    message.present?
  end

  def find_or_create_conversation(contact)
    contact_inbox = ContactInbox.find_or_create_by!(
      contact: contact, inbox: @bot.inbox, source_id: contact.phone_number || contact.id.to_s
    )
    Conversation.where(contact: contact, inbox: @bot.inbox).where.not(status: :resolved).first ||
      Conversation.create!(account: @account, inbox: @bot.inbox, contact: contact, contact_inbox: contact_inbox)
  end

  def bot_user
    @bot_user ||= @account.users.administrators.first || @account.users.first
  end
end
