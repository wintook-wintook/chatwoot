# frozen_string_literal: true

# Motor 2.0 — «Citas»: el horario que el cliente eligió de los que se le ofrecieron (state['offered_slots']), sin
# depender del modelo: «10», «a las 10:30», «el primero», «el último», «el de John», «11 con Mariana».
# Solo con mensajes cortos (una elección, no «quiero 2 manicures»). nil si no se entiende o hay más de uno posible.
#
#   Motor2::SlotPick.call('a las 10', [{ 'inicio' => '2026-11-27T10:00', 'con' => 'Mariana', 'texto' => '…' }, …])
module Motor2::SlotPick
  MAX_WORDS = 7
  ORDINALS = { /\b(el\s+)?(primer[oa]?|1r[oa]|1º)\b/ => 0, /\b(el\s+)?segund[oa]\b/ => 1, /\b(el\s+)?tercer[oa]?\b/ => 2,
               /\b(el\s+)?(ultim[oa]|ultimo)\b/ => -1 }.freeze
  HOUR = /\b(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm|hrs?|h)?\b/

  module_function

  def call(text, offered)
    slots = Array(offered).select { |s| s['inicio'].present? }
    words = normalize(text)
    return nil if slots.empty? || words.split.size > MAX_WORDS

    by_ordinal(words, slots) || by_hour_and_person(words, slots)
  end

  def normalize(text) = I18n.transliterate(text.to_s.downcase).gsub(/[¿?¡!,]/, ' ').squish

  def by_ordinal(words, slots)
    index = ORDINALS.find { |pattern, _| words.match?(pattern) }&.last
    index && slots[index]
  end

  # La hora (si la dijo) y la persona (si la dijo); tiene que quedar uno solo.
  def by_hour_and_person(words, slots)
    hour = words.match(HOUR)
    found = hour ? at_hour(slots, hour) : slots
    person = found.select { |s| named?(words, s['con']) }
    found = person if person.any?
    found.size == 1 && (hour || person.any?) ? found.first : nil
  end

  # «10» es 10:00 si también hay 10:30.
  def at_hour(slots, hour)
    found = slots.select { |s| same_time?(s, hour) }
    hour[2].nil? ? on_the_hour(found) : found
  end

  def on_the_hour(found)
    exact = found.select { |s| s['inicio'].to_s.end_with?(':00') }
    exact.any? ? exact : found
  end

  # «4» o «4 pm» son las 16:00 (nadie agenda a las 4 de la mañana).
  def same_time?(slot, match)
    hh, mm = slot['inicio'].to_s.scan(/T(\d{2}):(\d{2})/).flatten.map(&:to_i)
    hour = match[1].to_i
    hour += 12 if hour < 12 && (match[3] == 'pm' || hour <= 8)
    hh == hour && (match[2].nil? || mm == match[2].to_i)
  end

  def named?(words, name)
    first = normalize(name).split.first
    first.present? && words.split.include?(first)
  end
end
