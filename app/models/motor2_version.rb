# frozen_string_literal: true

# Motor 2.0 — una versión de la ficha 2.0 (lo que el usuario puede deshacer o restaurar).
# Solo se escribe si cambió algo respecto a la anterior.
class Motor2Version < ApplicationRecord
  SOURCES = %w[create manual trainer restore convert].freeze

  belongs_to :account
  belongs_to :tracking_template
  belongs_to :user, optional: true

  validates :source, inclusion: { in: SOURCES }
  scope :ordered, -> { order(version: :desc) }

  def readonly? = persisted?

  def self.record!(template, user:, source:, note: nil)
    snapshot = Motor2::AgentJson.snapshot(template)
    last = where(tracking_template_id: template.id).ordered.first
    return last if last && last.snapshot == snapshot.as_json

    create!(account: template.account, tracking_template: template, user: user, source: source,
            note: note.to_s.strip.first(255).presence, snapshot: snapshot,
            version: last&.version.to_i + 1)
  end
end
