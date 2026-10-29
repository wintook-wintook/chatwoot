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
#  id                            :bigint           not null, primary key
#  adaptation_answers            :jsonb            not null
#  ai_context                    :text
#  archived_at                   :datetime
#  booking_calendar_ids          :jsonb            not null
#  calendar_event_duration       :integer          default(30)
#  calendar_integration_ids      :jsonb            not null
#  complementary_prompt          :text
#  customer_display_name         :string
#  email_signature               :text
#  keyword_actions               :jsonb            not null
#  name                          :string           not null
#  objective                     :string           not null
#  previous_complementary_prompt :text
#  published_prompt_version      :integer
#  retry_interval_unit           :string           default("days")
#  retry_interval_value          :integer          default(1)
#  slots_presentation            :string           default("detailed"), not null
#  tags                          :json
#  timezone                      :string
#  training_structure            :jsonb            not null
#  whatsapp_templates            :json
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  account_id                    :bigint           not null
#  inbox_id                      :bigint
#  kbase_hook_id                 :integer
#  published_prompt_id           :bigint
#  user_id                       :bigint
#
# Indexes
#
#  index_tracking_templates_on_account_id           (account_id)
#  index_tracking_templates_on_account_id_and_name  (account_id,name) UNIQUE
#  index_tracking_templates_on_archived_at          (archived_at)
#  index_tracking_templates_on_inbox_id             (inbox_id)
#  index_tracking_templates_on_kbase_hook_id        (kbase_hook_id)
#  index_tracking_templates_on_published_prompt_id  (published_prompt_id)
#  index_tracking_templates_on_user_id              (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (published_prompt_id => published_prompts.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#

class TrackingTemplate < ApplicationRecord
  belongs_to :account
  belongs_to :inbox, optional: true
  belongs_to :user, optional: true
  # proyecto@publicar_prompts: la publicación de la que salió este agente (si se bajó de la Galería)
  belongs_to :published_prompt, optional: true
  # proyecto@publicar_prompts: la publicación de ESTE agente (si su autor lo publicó)
  has_one :publication, class_name: 'PublishedPrompt', dependent: nil, inverse_of: :tracking_template

  # proyecto@publicar_prompts (F7): si se bajó de la Galería y el autor publicó una versión
  # más nueva que la que tiene (o ya revisó) esta copia. Nunca se aplica sola.
  def published_prompt_update
    pub = published_prompt
    return unless pub&.published? && pub.version > published_prompt_version.to_i

    { 'published_prompt_id' => pub.id, 'version' => pub.version, 'current_version' => published_prompt_version }
  end

  # proyecto@ai_agent_attachments: archivos del Agente IA referenciados por {{name}}
  has_many :ai_agent_attachments, dependent: :destroy

  # feat/agentes_ia_unificado (rescate del F4 de ai_agent_assistant): historial en sitio.
  # Se itera sobre el MISMO agente en vez de duplicarlo; cada guardado que cambia su
  # comportamiento deja un snapshot con autor, nota y desde dónde se hizo.
  has_many :versions, class_name: 'TrackingTemplateVersion', dependent: :delete_all
  # proyecto@diagrama_agente_ia F3: la pila de pruebas del agente.
  has_many :test_cases, class_name: 'TrackingTestCase', dependent: :delete_all

  # Nota y origen del guardado en curso. Los ponen el controlador y los servicios que
  # guardan (Asistente, Galería); no se persisten en la plantilla, viajan al snapshot.
  attr_accessor :version_note, :version_source

  validates :name, presence: true, length: { minimum: 2, maximum: 100 },
                   uniqueness: { scope: :account_id, case_sensitive: false }
  validates :objective, presence: true, length: { minimum: 5, maximum: 500 }
  # Nombre que ve el cliente (ContactTrackings::AgentIdentity); vacío = sin nombre.
  before_validation { self.customer_display_name = customer_display_name.to_s.squish.presence }
  validates :customer_display_name, length: { maximum: 30 }, allow_nil: true
  # proyecto@automatizacion_tracking: intervalo entre intentos (opcional, mismo comportamiento que ContactTracking)
  validates :retry_interval_value, numericality: { greater_than: 0 }, allow_nil: true
  validates :retry_interval_unit, inclusion: { in: %w[minutes hours days] }, allow_nil: true
  # proyecto@bot_seguimiento_calendar: zona horaria para agendar (slots, hora mostrada, evento)
  validates :timezone, inclusion: { in: TZInfo::Timezone.all_identifiers }, allow_blank: true
  # proyecto@contact_tracking: palabras clave de acción
  validate :keyword_actions_valid_structure
  # proyecto@adaptar_prompts_publicados (F5): con <PENDIENTE:> no se le asigna bandeja. Solo
  # cuando cambia la bandeja o el texto, para no trabar ediciones que no tienen que ver.
  validate :inbox_requires_complete_setup,
           if: -> { inbox_id.present? && (will_save_change_to_inbox_id? || will_save_change_to_complementary_prompt?) }

  scope :by_tag, ->(tag) { where('tags @> ?', [tag].to_json) }
  scope :by_inbox, ->(inbox_id) { where(inbox_id: inbox_id) }
  scope :search_by_name, ->(query) { where('name ILIKE ?', "%#{query}%") }
  scope :ordered, -> { order(updated_at: :desc) }

  before_save :ensure_arrays
  # proyecto@asistente_agentes_ia — el Entrenamiento por bloques (plan:
  # docs/formulario_entrenamiento_plan.md). Se regenera SIEMPRE del texto cuando el texto
  # cambia, así las dos columnas no pueden decir cosas distintas, escriba quien escriba
  # (la ficha, el Asistente, la API). El único camino que se saltea los callbacks es
  # update_columns: quien lo use tiene que pasar las dos (ver DirectiveReferenceService).
  before_save :sync_training_structure, if: :will_save_change_to_complementary_prompt?
  after_save :record_version

  # feat/agentes_ia_unificado — en qué se está usando, para no borrarlo a ciegas:
  #   active_trackings  seguimientos que todavía corren con él (no los terminados)
  #   campaigns         campañas que lo usan, aunque estén terminadas (la llave foránea
  #                     no deja borrarlo: antes salía un «no se pudo eliminar» sin motivo)
  #   automations       nombres de las automatizaciones que lo asignan (quedarían
  #                     sin hacer nada, sin avisar)
  def usage
    {
      active_trackings: ContactTracking.where(tracking_template_id: id,
                                              status: ContactTrackings::Eligibility::ACTIVE_STATUSES).count,
      campaigns: TrackingCampaign.where(tracking_template_id: id).count,
      automations: automations_using.map(&:name)
    }
  end

  def in_use?(uso = usage)
    uso[:active_trackings].positive? || uso[:campaigns].positive? || uso[:automations].any?
  end

  # La acción guarda el id en action_params (como número o como texto).
  def automations_using
    AutomationRule.where(account_id: account_id).select do |regla|
      Array(regla.actions).any? do |accion|
        accion['action_name'] == 'assign_tracking_template' && Array(accion['action_params']).map(&:to_s).include?(id.to_s)
      end
    end
  end

  # La estructura para mostrar: la guardada, o la del texto si el agente es anterior a
  # la columna y todavía no se corrió el backfill, o si la guardada quedó vieja —
  # las ramas empezaron a viajar en campos después del backfill, y una estructura sin
  # ellos dejaba el formulario de ramas sin datos (ver TrainingRoutes).
  def training_blocks
    guardada = training_structure.presence
    return ContactTrackings::TrainingStructure.parse(complementary_prompt) if guardada.blank? || stale_structure?(guardada)

    guardada
  end

  # El formulario manda bloques: se arma el texto y, al guardar, el callback vuelve a
  # separar la estructura desde ese texto — la guardada es siempre la canónica.
  def training_structure_from_form=(estructura)
    self.complementary_prompt = ContactTrackings::TrainingStructure.compose(estructura)
  end

  private

  # ── Un snapshot por guardado que cambie el comportamiento del agente ──────────
  # update_columns se salta esto a propósito (DirectiveReferenceService renombra un
  # {{archivo}} en el texto: no es una edición de nadie).
  def record_version
    return unless versioned_fields_changed?

    ensure_baseline_version! unless previously_new_record?

    versions.create!(
      account: account,
      user: Current.user,
      version: versions.maximum(:version).to_i + 1,
      source: resolved_version_source,
      note: version_note.to_s.strip.presence&.truncate(255),
      snapshot: TrackingTemplateVersion.snapshot_of(self)
    )
  end

  def versioned_fields_changed?
    TrackingTemplateVersion::VERSIONED_FIELDS.any? { |field| saved_change_to_attribute?(field) }
  end

  # Los agentes creados antes del versionado no tienen historial: su primer diff no
  # tendría contra qué compararse. Al primer guardado se reconstruye el estado anterior
  # como versión 1.
  def ensure_baseline_version!
    return if versions.exists?

    versions.create!(account: account, version: 1, source: 'baseline',
                     snapshot: TrackingTemplateVersion.previous_snapshot_of(self))
  end

  # Un alta es `create` salvo que venga de un origen que se quiere conservar
  # (la Galería, importar, el Asistente).
  def resolved_version_source
    source = version_source.to_s
    return source if TrackingTemplateVersion::SOURCES.include?(source)

    previously_new_record? ? 'create' : 'manual'
  end

  # Un bloque de ramas sin sus campos es de antes de que existieran.
  def stale_structure?(estructura)
    Array(estructura['blocks']).any? { |b| b['type'] == 'routes' && !b.key?('lines') }
  end

  def sync_training_structure
    self.training_structure = ContactTrackings::TrainingStructure.parse(complementary_prompt)
  end

  def ensure_arrays
    self.whatsapp_templates = [] unless whatsapp_templates.is_a?(Array)
    self.tags               = [] unless tags.is_a?(Array)
    self.keyword_actions    = [] unless keyword_actions.is_a?(Array)
  end

  def inbox_requires_complete_setup
    return unless ContactTrackings::PendingSetup.blocked?(self)

    errors.add(:base, ContactTrackings::PendingSetup.message(self, 'inbox_blocked'))
  end

  def keyword_actions_valid_structure
    return unless keyword_actions.is_a?(Array)

    return if keyword_actions.all? { |ka| valid_keyword_action?(ka) }

    errors.add(:keyword_actions, 'contiene una entrada con formato inválido')
  end

  def valid_keyword_action?(rule)
    rule.is_a?(Hash) &&
      rule['keyword'].to_s.strip.present? &&
      ContactTrackings::KeywordActionService::VALID_ACTIONS.include?(rule['action'].to_s) &&
      ContactTrackings::KeywordActionService::VALID_DIRECTIONS.include?(rule['direction'].to_s)
  end
end
