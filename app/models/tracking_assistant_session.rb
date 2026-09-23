# frozen_string_literal: true

# == Schema Information
#
# Table name: tracking_assistant_sessions
#
#  id                   :bigint           not null, primary key
#  draft                :text
#  draft_versions       :jsonb            not null
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
  # La que se retoma sola al abrir el Asistente: la propia, no la de otro. Verlas
  # todas no significa que la pantalla arranque en la conversación ajena.
  def self.resumable_for(account, user)
    open_sessions.where(account: account, user: user).recent_first.first
  end

  def open? = status == 'open'

  # Las que se muestran en el listado. Las descartadas quedan en la tabla pero
  # fuera de la vista: descartar no debería ser irreversible.
  # De TODA la cuenta, no solo de quien pregunta: el Entrenamiento de un Agente IA
  # es trabajo del equipo, y quedaba escondido en la conversación de quien lo armó.
  # El módulo es de administradores (ver el controlador), así que "toda la cuenta"
  # son ellos.
  def self.listable_for(account)
    where(account: account, status: %w[open saved])
      .includes(:tracking_template, :user).recent_first.limit(LIST_LIMIT)
  end

  # De qué se trataba, para el listado. El primer mensaje de la persona es lo más
  # cercano a un título que hay: es con lo que arrancó la entrevista.
  # Si arrancó desde unas instrucciones iniciales, el primer mensaje es el encargo
  # armado para el modelo (largo, y no escrito para leerlo): va el nombre del archivo.
  def title
    primero = Array(messages).find { |m| m['role'] == 'user' }
    texto = primero&.dig('content').to_s

    ContactTrackings::Assistant::BriefComposer.title_for(texto) || texto.squish.presence&.truncate(80)
  end

  # Cuántas ramas leería el motor del último borrador. Sale de la comprobación ya
  # guardada, sin volver a parsear: es lo que distingue un intento que sirve de uno
  # que no, y es lo primero que se quiere ver en una lista.
  def route_count
    Array(validation['routes']).size
  end

  # ── versiones del Entrenamiento (fase D de PROMPT STUDIO) ───────────────────
  # Una por cada Entrenamiento que entrega el asistente y una por cada tanda de
  # edición a mano (se registra al mandar el turno siguiente). Tope: una
  # conversación larga sobre un prompt de 17.000 caracteres son ~500 KB con 30.
  MAX_VERSIONS = 30
  VERSION_SOURCES = %w[loaded manual assistant].freeze

  # Agrega una versión si el texto cambió respecto de la última. No guarda.
  def add_version(draft:, source:, summary: nil, validation: nil)
    return if draft.blank? || VERSION_SOURCES.exclude?(source)

    versiones = Array(draft_versions)
    return if versiones.last&.dig('draft') == draft

    versiones << version_entry(versiones.last&.dig('n').to_i + 1, draft, source, summary, validation)
    self.draft_versions = versiones.last(MAX_VERSIONS)
  end

  def version_entry(number, draft, source, summary, validation)
    datos = (validation || {}).with_indifferent_access
    { 'n' => number, 'source' => source, 'at' => Time.current.iso8601,
      'summary' => summary.to_s.squish.truncate(140).presence,
      'routes' => Array(datos[:routes]).size, 'blocking' => Array(datos[:blocking]).size,
      'draft' => draft }.compact
  end
  private :version_entry

  # Sin el texto: es lo que viaja en cada turno. El texto se pide de a una.
  def version_list
    Array(draft_versions).map { |version| version.except('draft') }
  end

  def version(number)
    Array(draft_versions).find { |version| version['n'] == number.to_i }
  end

  def last_version_draft
    Array(draft_versions).last&.dig('draft')
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
