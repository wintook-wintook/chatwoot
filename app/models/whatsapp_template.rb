# frozen_string_literal: true

# @waba_templates
# Plantilla de mensaje de WhatsApp gestionada desde Chatwoot (crear/submit/editar/borrar
# contra Meta). Tabla propia — NO reutiliza el JSONB `channel_whatsapp.message_templates`,
# que se conserva para el picker de envío existente.
#
# `status` guarda el enum CRUDO de Meta (no TitleCase) para casar 1:1 con el webhook
# `message_template_status_update` y distinguir estados recuperables de terminales.
#
# == Schema Information
#
# Table name: whatsapp_templates
#
#  id                  :bigint           not null, primary key
#  body_text           :text
#  buttons             :jsonb            not null
#  category            :string
#  footer_text         :string
#  header_content      :text
#  header_handle       :string
#  header_media_url    :string
#  header_type         :string
#  language            :string           not null
#  last_submitted_at   :datetime
#  name                :string           not null
#  quality_score       :string
#  rejection_reason    :string
#  sample_values       :jsonb            not null
#  status              :string           default("DRAFT"), not null
#  submission_error    :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  channel_whatsapp_id :bigint           not null
#  meta_template_id    :string
#
# Indexes
#
#  index_whatsapp_templates_on_account_id             (account_id)
#  index_whatsapp_templates_on_channel_name_language  (channel_whatsapp_id,name,language) UNIQUE
#  index_whatsapp_templates_on_meta_template_id       (meta_template_id)
#
class WhatsappTemplate < ApplicationRecord
  belongs_to :account
  belongs_to :channel_whatsapp, class_name: 'Channel::Whatsapp'

  # feat/plantillas_whatsapp_mejoras F6: el archivo de muestra del encabezado, subido desde la
  # pantalla de plantillas. De él salen la muestra para Meta (F0) y el archivo que mandan los
  # seguimientos y campañas (F5). Ver #header_media_link.
  has_one_attached :header_sample

  # Estados crudos de Meta. EDITABLES: se pueden re-enviar (vuelven a PENDING).
  # TERMINALES: no admiten acción. RECUPERABLES: reintentables desde la UI.
  STATUSES = %w[DRAFT PENDING APPROVED REJECTED PAUSED DISABLED IN_APPEAL PENDING_DELETION].freeze
  EDITABLE_STATUSES = %w[APPROVED REJECTED PAUSED].freeze
  TERMINAL_STATUSES = %w[DISABLED PENDING_DELETION].freeze
  RECOVERABLE_STATUSES = %w[DRAFT REJECTED].freeze

  HEADER_TYPES = %w[text image video document].freeze
  QUALITY_SCORES = %w[GREEN YELLOW RED].freeze

  validates :name, presence: true,
                   format: { with: /\A[a-z0-9_]{1,512}\z/, message: 'solo minúsculas, números y _ (máx 512)' },
                   uniqueness: { scope: [:channel_whatsapp_id, :language], case_sensitive: false }
  validates :language, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :header_type, inclusion: { in: HEADER_TYPES }, allow_nil: true
  validates :quality_score, inclusion: { in: QUALITY_SCORES }, allow_blank: true
  # feat/plantillas_whatsapp_mejoras F0: el handle que devuelve Meta al subir un VIDEO pasa de
  # los 255 que ApplicationRecord pone por defecto a las columnas string (el de documento
  # cabía): Meta creaba la plantilla y el guardado local fallaba (drift). Una liga firmada
  # también puede pasar de 255. Un validador propio reemplaza al de 255.
  validates :header_handle, length: { maximum: 4000 }
  validates :header_media_url, length: { maximum: 2048 }

  scope :for_channel, ->(channel_id) { where(channel_whatsapp_id: channel_id) }
  scope :by_meta_id, ->(meta_id) { where(meta_template_id: meta_id) }

  # La liga del archivo del encabezado para dársela a Meta AHORA (subir la muestra, mandar la
  # plantilla). Si se subió un archivo, una liga fresca suya: las de ActiveStorage para
  # servicios externos caducan en minutos (y rails_blob_url es una redirección que muchos no
  # siguen), así que no sirven guardadas en header_media_url para usarse días después. Si no,
  # la liga pegada a mano.
  def header_media_link(expires_in: 1.hour)
    return header_media_url.presence unless header_sample.attached?

    ActiveStorage::Current.url_options = Rails.application.routes.default_url_options if ActiveStorage::Current.url_options.blank?
    header_sample.blob.url(expires_in: expires_in)
  end

  # ¿Se subió un archivo nuevo en esta edición? (hay que volver a subir la muestra a Meta)
  def header_sample_changed?
    attachment_changes.key?('header_sample')
  end

  # ¿Se puede editar en Meta? (Meta reemplaza los components y la vuelve a PENDING.)
  def editable?
    EDITABLE_STATUSES.include?(status)
  end

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  # Fila que nunca llegó a Meta (draft local / falló el submit) → destroy no llama a Meta.
  def local_only?
    meta_template_id.blank? || meta_template_id.to_s.start_with?('dry-run-')
  end
end
