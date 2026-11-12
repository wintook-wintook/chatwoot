# frozen_string_literal: true

# Asistente (Dali) — candados para no contestarle a la conversación equivocada. Se incluye en
# Assistant::Tools (lo usan propose_reply y propose_internal_note).
#
#   1. El nombre: la propuesta dice a quién va (`para`) y debe ser el contacto de esa conversación
#      (el modelo a veces toma el número de otra fila: «Andrés» en la conversación de Mariana).
#   2. La lista: si el turno anterior listó VARIAS conversaciones (¿qué tengo pendiente?) y el
#      usuario dijo solo «contéstale», sin nombre ni número, no se escoge: se le pregunta.
#
# `listed_now`: las conversaciones que listó este turno (Assistant::Chat las guarda en el mensaje
# y las pasa en `turn[:listed]` al siguiente).
module Assistant::ReplyTarget
  MIN_TOKEN = 3

  # Lo que listó el último mensaje de Dali en esta plática.
  def self.last_listed(thread)
    thread.messages.reverse.find { |m| m['role'] == 'assistant' }&.dig('listed')
  end

  def listed_now = @listed_now ||= []

  def remember_listed(rows)
    return if @focused # ya leyó una: esa es la de la plática
    return focus_on_number(asked_number) if asked_number # «¿qué me escribieron en la #3?»

    rows.each { |row| listed_now << { 'id' => row[:id], 'name' => row[:contact].to_s } if row[:id] }
    listed_now.uniq! { |row| row['id'] }
  end

  def asked_number
    normalize(turn.to_h[:question])[/(?:#\s?|conversacion\s+)(\d+)/, 1]&.to_i
  end

  def focus_on_number(number)
    @focused = true
    @listed_now = [{ 'id' => number, 'name' => '' }]
  end

  # Leyó una conversación (read_conversation): de esa se está hablando, aunque antes listara varias.
  def focus_on(conversation)
    @focused = true
    @listed_now = [{ 'id' => conversation.display_id, 'name' => conversation.contact&.name.to_s }]
  end

  def check_reply_target!(conversation, args)
    return if conversation.internal?

    name = conversation.contact&.name.to_s
    check_name!(conversation, name, args['para'])
    check_ambiguous!(conversation, name)
  end

  private

  def check_name!(conversation, name, para)
    return if para.blank? || name.blank? || same_person?(para, name)

    raise ArgumentError, "La conversación ##{conversation.display_id} es de #{name}, no de «#{para}». " \
                         'Usa el número de la conversación de esa persona (my_conversations o search).'
  end

  def check_ambiguous!(conversation, name)
    listed = Array(turn.to_h[:listed])
    return if listed.size < 2 || listed.none? { |row| row['id'].to_i == conversation.display_id }
    return if named_in_question?(conversation, name)

    options = listed.first(6).map { |row| "#{row['name']} (##{row['id']})" }.join(', ')
    raise ArgumentError, "El usuario no dijo a cuál conversación contestar y la lista tenía varias: #{options}. " \
                         'No escojas tú: pregúntale a cuál, con esos nombres y números.'
  end

  def named_in_question?(conversation, name)
    question = normalize(turn.to_h[:question])
    return true if question.match?(/(?:#\s?|conversacion\s+)#{conversation.display_id}\b/)

    tokens(name).any? { |token| question.match?(/\b#{Regexp.escape(token)}\b/) }
  end

  # «Andres» = «Andrés Liverio»; basta un nombre o apellido en común.
  def same_person?(para, name)
    tokens(para).intersect?(tokens(name))
  end

  def tokens(text) = normalize(text).split(/[^a-z0-9]+/).select { |t| t.length >= MIN_TOKEN }

  def normalize(text) = I18n.transliterate(text.to_s).downcase
end
