# frozen_string_literal: true

# Embudo de contactos — bitácora de cada cambio de columna de una conversación:
# quién la movió (una persona, una regla, la IA o una automatización), por qué y
# de dónde a dónde. Alimenta la nota de la tarjeta y las métricas del embudo.
class KanbanMove < ApplicationRecord
  SOURCES = %w[manual rule ai automation].freeze

  belongs_to :account
  belongs_to :conversation
  belongs_to :kanban_type_process
  belongs_to :from_process, class_name: 'KanbanProcess', optional: true
  belongs_to :to_process, class_name: 'KanbanProcess', optional: true
  belongs_to :user, optional: true

  validates :source, inclusion: { in: SOURCES }
end
