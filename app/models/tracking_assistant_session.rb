# frozen_string_literal: true

# == Schema Information
#
# Table name: tracking_assistant_sessions
#
#  id                   :bigint           not null, primary key
#  draft                :text
#  messages             :jsonb            not null
#  proposal             :jsonb            not null
#  status               :string           default("open"), not null
#  validation           :jsonb            not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  tracking_template_id :bigint
#  user_id              :bigint           not null
#
# Indexes
#
#  idx_tracking_assistant_sessions_lookup                     (account_id,user_id,status,updated_at)
#  index_tracking_assistant_sessions_on_tracking_template_id  (tracking_template_id)
#  index_tracking_assistant_sessions_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (tracking_template_id => tracking_templates.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
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
  # Tope del listado. Nadie revisa más que eso, y sin tope la pantalla se vuelve
  # pesada en una cuenta que use mucho el asistente.
  LIST_LIMIT = 50

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

  # Las que se muestran en el listado. Las descartadas quedan en la tabla pero
  # fuera de la vista: descartar no debería ser irreversible.
  def self.listable_for(account, user)
    where(account: account, user: user, status: %w[open saved])
      .includes(:tracking_template).recent_first.limit(LIST_LIMIT)
  end

  # De qué se trataba, para el listado. El primer mensaje de la persona es lo más
  # cercano a un título que hay: es con lo que arrancó la entrevista.
  def title
    primero = Array(messages).find { |m| m['role'] == 'user' }
    texto = primero&.dig('content').to_s.squish

    texto.presence&.truncate(80)
  end

  # Cuántas ramas leería el motor del último borrador. Sale de la comprobación ya
  # guardada, sin volver a parsear: es lo que distingue un intento que sirve de uno
  # que no, y es lo primero que se quiere ver en una lista.
  def route_count
    Array(validation['routes']).size
  end

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
