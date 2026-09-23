# frozen_string_literal: true

# == Schema Information
#
# Table name: tracking_agent_briefs
#
#  id                            :bigint           not null, primary key
#  answers                       :jsonb            not null
#  chunks                        :jsonb            not null
#  content                       :text             not null
#  digest                        :jsonb            not null
#  filename                      :string           not null
#  sha256                        :string           not null
#  status                        :string           default("pending"), not null
#  usage                         :jsonb            not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  account_id                    :bigint           not null
#  tracking_assistant_session_id :bigint
#  tracking_template_id          :bigint
#  user_id                       :bigint           not null
#
# Indexes
#
#  index_tracking_agent_briefs_on_account_id_and_sha256          (account_id,sha256)
#  index_tracking_agent_briefs_on_tracking_assistant_session_id  (tracking_assistant_session_id)
#  index_tracking_agent_briefs_on_tracking_template_id           (tracking_template_id)
#  index_tracking_agent_briefs_on_user_id                        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (tracking_assistant_session_id => tracking_assistant_sessions.id) ON DELETE => nullify
#  fk_rails_...  (tracking_template_id => tracking_templates.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
# ================================================================================
# proyecto@asistente_agentes_ia — EL ENCARGO DE UN AGENTE IA
# ================================================================================
# Un .md con la IDEA de cómo se quiere el agente (ver docs/importar_prompt_md_plan.md).
# No es el Entrenamiento ni un pedazo de él: el Asistente lo lee, arma la ficha del
# encargo, pregunta en el chat lo que falta y escribe el Entrenamiento.
#
# POR QUÉ SE GUARDA ENTERO:
#   Para regenerar sin volver a subirlo, y porque la ficha es un resumen: si algún día
#   hace falta volver a entenderlo con otras instrucciones, el original tiene que estar.
#
# LA HUELLA (sha256):
#   Leer un encargo grande cuesta (ADAM, 1,1 MB: ≈ USD 1,90 con gpt-4o). Si la cuenta
#   ya leyó ese mismo archivo, la lectura se copia en vez de pagarse otra vez.
#
# El encargo es material interno de quien arma el agente (ADAM trae una sección
# "CONFIDENCIAL · USO INTERNO"): no se vectoriza ni es fuente de respuestas al cliente.
# ================================================================================

class TrackingAgentBrief < ApplicationRecord
  # pending = subido, sin leer · reading = leyéndose · ready = ficha lista · failed
  STATUSES = %w[pending reading ready failed].freeze
  # ADAM, el encargo más grande que se conoce, pesa 1,1 MB.
  MAX_BYTES = 5.megabytes
  EXTENSIONS = %w[.md .markdown .txt].freeze
  # Lo que se copia de otro encargo con la misma huella: la lectura, no la conversación.
  # Las respuestas del chat son de cada agente, aunque el archivo sea el mismo.
  READING_ATTRIBUTES = %w[chunks digest].freeze

  belongs_to :account
  belongs_to :user
  belongs_to :tracking_template, optional: true
  belongs_to :tracking_assistant_session, optional: true

  validates :filename, :content, :sha256, presence: true
  # Sin esto rige el tope general de ApplicationRecord para columnas text (20.000
  # caracteres), y un encargo como ADAM tiene más de un millón.
  validates :content, length: { maximum: MAX_BYTES }
  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(created_at: :desc) }

  def self.fingerprint(text)
    Digest::SHA256.hexdigest(text.to_s)
  end

  # Un encargo de la cuenta con el mismo archivo y la lectura ya hecha.
  def self.read_twin(account, sha256)
    where(account: account, sha256: sha256, status: 'ready').recent_first.first
  end

  def ready? = status == 'ready'

  # Trae la lectura de otro encargo con el mismo archivo. No guarda.
  def copy_reading_from(twin)
    lectura = twin.slice(*READING_ATTRIBUTES)
    assign_attributes(lectura.merge('status' => 'ready', 'usage' => { 'reused_from' => twin.id }))
  end

  # Lo que viaja a la pantalla. Sin el texto: con 1 MB por encargo, se pide aparte.
  def summary
    {
      id: id, filename: filename, status: status, bytes: content.to_s.bytesize,
      characters: content.to_s.length, sha256: sha256,
      tracking_template_id: tracking_template_id,
      tracking_assistant_session_id: tracking_assistant_session_id,
      reused_from: usage['reused_from'],
      created_at: created_at, updated_at: updated_at
    }.compact
  end
end
