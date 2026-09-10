# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LA CONVERSACIÓN DEL ASISTENTE
# ================================================================================
# Una entrevista con el Asistente de Agentes IA, guardada para poder retomarla.
#
# POR QUÉ SE PERSISTE:
#   Una entrevista dura 30–45 minutos. Mientras el hilo vivía solo en el navegador,
#   cerrar la pestaña tiraba todo ese trabajo — y no hay forma de "volver a
#   preguntar lo mismo": la conversación es el contexto que hace que el asistente
#   proponga sobre lo que ya se le dijo.
#
# QUÉ SE GUARDA Y QUÉ NO:
#   Se guardan los turnos, el último borrador, su comprobación y la propuesta de
#   datos del agente. NO se guarda el inventario: ese se relee en cada turno,
#   porque un inventario viejo vuelve a producir nombres que ya no existen.
# ================================================================================

class TrackingAssistantSession < ApplicationRecord
  STATUSES = %w[open saved discarded].freeze
  # Los turnos que se conservan. Una entrevista real son 4 o 5; el tope existe para
  # que un hilo que se fue de las manos no crezca sin límite dentro del jsonb.
  MAX_MESSAGES = 60

  belongs_to :account
  belongs_to :user
  belongs_to :tracking_template, optional: true

  validates :status, inclusion: { in: STATUSES }

  scope :open_sessions, -> { where(status: 'open') }
  scope :recent_first, -> { order(updated_at: :desc) }

  # La que se ofrece retomar al abrir la pantalla: la última a medias de esa
  # persona. Se acota por usuario y no por cuenta porque una entrevista es de quien
  # la tuvo — retomar la de otro sería seguir una conversación que no se leyó.
  def self.resumable_for(account, user)
    open_sessions.where(account: account, user: user).recent_first.first
  end

  def open? = status == 'open'

  # El hilo se guarda entero en cada turno: siempre se lee completo, así que no hay
  # nada que ganar guardando los mensajes de a uno.
  def record_turn(messages:, draft: nil, validation: nil, proposal: nil)
    assign_attributes(messages: Array(messages).last(MAX_MESSAGES))
    self.draft = draft if draft.present?
    self.validation = validation if validation.present?
    self.proposal = proposal if proposal.present?
    save!
  end

  def mark_saved!(template)
    update!(status: 'saved', tracking_template: template)
  end
end
