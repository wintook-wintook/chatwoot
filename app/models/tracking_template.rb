# ================================================================================
# proyecto@tracking_templates
# ================================================================================
# Modelo: TrackingTemplate
# Descripción: Plantillas reutilizables para configuraciones de seguimiento
# Asociaciones: account, inbox (optional), user (optional)
# ================================================================================

# == Schema Information
#
# Table name: tracking_templates
#
#  id                       :bigint           not null, primary key
#  ai_context               :text
#  archived_at              :datetime
#  booking_calendar_ids     :jsonb            not null
#  calendar_event_duration  :integer          default(30)
#  calendar_integration_ids :jsonb            not null
#  complementary_prompt     :text
#  keyword_actions          :jsonb            not null
#  name                     :string           not null
#  objective                :string           not null
#  retry_interval_unit      :string           default("days")
#  retry_interval_value     :integer          default(1)
#  slots_presentation       :string           default("detailed"), not null
#  tags                     :json
#  timezone                 :string
#  whatsapp_templates       :json
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint           not null
#  inbox_id                 :bigint
#  kbase_hook_id            :integer
#  user_id                  :bigint
#
# Indexes
#
#  index_tracking_templates_on_account_id           (account_id)
#  index_tracking_templates_on_account_id_and_name  (account_id,name) UNIQUE
#  index_tracking_templates_on_archived_at          (archived_at)
#  index_tracking_templates_on_inbox_id             (inbox_id)
#  index_tracking_templates_on_kbase_hook_id        (kbase_hook_id)
#  index_tracking_templates_on_user_id              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (user_id => users.id)
#

class TrackingTemplate < ApplicationRecord
  belongs_to :account
  belongs_to :inbox, optional: true
  belongs_to :user, optional: true

  # proyecto@ai_agent_attachments: archivos del Agente IA referenciados por {{name}}
  has_many :ai_agent_attachments, dependent: :destroy

  # proyecto@ai_agent_assistant (F4): historial en sitio. Se itera sobre el MISMO agente
  # en vez de duplicarlo; cada guardado deja un snapshot con autor y nota.
  has_many :versions, class_name: 'TrackingTemplateVersion', dependent: :delete_all

  # Nota y origen del guardado en curso. Los pone el controlador; no se persisten en la
  # plantilla, viajan al snapshot.
  attr_accessor :version_note, :version_source

  validates :name, presence: true, length: { minimum: 2, maximum: 100 },
                   uniqueness: { scope: :account_id, case_sensitive: false }
  validates :objective, presence: true, length: { minimum: 5, maximum: 500 }
  # proyecto@automatizacion_tracking: intervalo entre intentos (opcional, mismo comportamiento que ContactTracking)
  validates :retry_interval_value, numericality: { greater_than: 0 }, allow_nil: true
  validates :retry_interval_unit, inclusion: { in: %w[minutes hours days] }, allow_nil: true
  # proyecto@bot_seguimiento_calendar: zona horaria para agendar (slots, hora mostrada, evento)
  validates :timezone, inclusion: { in: TZInfo::Timezone.all_identifiers }, allow_blank: true
  # proyecto@contact_tracking: palabras clave de acción
  validate :keyword_actions_valid_structure

  scope :by_tag, ->(tag) { where("tags @> ?", [tag].to_json) }
  scope :by_inbox, ->(inbox_id) { where(inbox_id: inbox_id) }
  scope :search_by_name, ->(query) { where('name ILIKE ?', "%#{query}%") }
  scope :ordered, -> { order(updated_at: :desc) }
  # proyecto@ai_agent_assistant (F4): archivar saca de las listas sin borrar nada —
  # conserva historial y seguimientos en curso.
  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  before_save :ensure_arrays
  after_save :record_version

  def archived?
    archived_at.present?
  end

  # Sin snapshot: archivar no cambia el comportamiento del agente, solo lo saca de las listas.
  def archive!
    update_columns(archived_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def unarchive!
    update_columns(archived_at: nil) # rubocop:disable Rails/SkipsModelValidations
  end

  private

  # ==========================================================================
  # F4 · un snapshot por guardado que cambie el comportamiento del agente.
  # ==========================================================================
  def record_version
    return unless versioned_fields_changed?

    ensure_baseline_version! unless previously_new_record?

    versions.create!(
      account: account,
      user: Current.user,
      version: next_version_number,
      source: resolved_version_source,
      note: version_note.to_s.strip.presence&.truncate(255),
      snapshot: TrackingTemplateVersion.snapshot_of(self)
    )
  end

  def versioned_fields_changed?
    TrackingTemplateVersion::VERSIONED_FIELDS.any? { |field| saved_change_to_attribute?(field) }
  end

  # Los agentes creados antes de F4 no tienen historial: su primer diff no tendría contra
  # qué compararse. Al primer guardado se reconstruye el estado anterior como versión 1.
  def ensure_baseline_version!
    return if versions.exists?

    versions.create!(account: account, version: 1, source: 'baseline',
                     snapshot: TrackingTemplateVersion.previous_snapshot_of(self))
  end

  def next_version_number
    versions.maximum(:version).to_i + 1
  end

  # Al nacer, el origen es `create` salvo que quien lo creó diga de dónde salió.
  # Sin esto todas las v1 se ven iguales, y la de una copia no lo es: tiene un
  # original al que compararse, y quien la abra dentro de un mes necesita saberlo.
  BIRTH_SOURCES = %w[fork assistant import].freeze

  def resolved_version_source
    source = version_source.to_s
    known = TrackingTemplateVersion::SOURCES.include?(source)
    return source if known && (!previously_new_record? || BIRTH_SOURCES.include?(source))

    previously_new_record? ? 'create' : 'manual'
  end

  def ensure_arrays
    self.whatsapp_templates = [] unless whatsapp_templates.is_a?(Array)
    self.tags               = [] unless tags.is_a?(Array)
    self.keyword_actions    = [] unless keyword_actions.is_a?(Array)
  end

  def keyword_actions_valid_structure
    return unless keyword_actions.is_a?(Array)

    keyword_actions.each do |ka|
      unless ka.is_a?(Hash) &&
             ka['keyword'].to_s.strip.present? &&
             ContactTrackings::KeywordActionService::VALID_ACTIONS.include?(ka['action'].to_s) &&
             ContactTrackings::KeywordActionService::VALID_DIRECTIONS.include?(ka['direction'].to_s)
        errors.add(:keyword_actions, 'contiene una entrada con formato inválido')
        break
      end
    end
  end
end
