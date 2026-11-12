# frozen_string_literal: true

# Base común de los agentes que le hablan a clientes (Seguimiento IA y Agentes listos): la nota
# del contacto marcada «para IA» (hay una sola por contacto), para personalizar sin recitársela.
module AgentBase::ContactNote
  MAX_CHARS = 2000

  module_function

  def for(contact)
    contact&.notes&.for_ia&.order(updated_at: :desc)&.first
  end

  def block(contact)
    note = self.for(contact)
    return '' if note.blank? || note.content.blank?

    "LO QUE SABEMOS DEL CLIENTE (nota del equipo; úsala para personalizar, sin recitársela):\n" \
      "#{note.content.to_s.strip.truncate(MAX_CHARS)}"
  end
end
