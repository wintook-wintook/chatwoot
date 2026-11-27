# == Schema Information
#
# Table name: canned_responses
#
#  id                :integer          not null, primary key
#  content           :text
#  content_full      :boolean          default(FALSE), not null
#  content_is_prompt :boolean          default(FALSE), not null
#  content_prompts   :text
#  embedded_at       :datetime
#  embedding_error   :string
#  embedding_status  :string
#  kind              :string           default("general"), not null
#  menu              :boolean          default(FALSE), not null
#  opcion            :bigint           default(0), not null
#  short_code        :string
#  url_content       :boolean          default(FALSE), not null
#  url_short_code    :text
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :integer          not null
#

class CannedResponse < ApplicationRecord
  validates :content, presence: true
  validates :short_code, presence: true
  validates :account, presence: true
  validates :short_code, uniqueness: { scope: :account_id }

  # proyecto@predefinidas_que_contestan — LA CATEGORÍA es fija (columna `kind`) y decide cómo
  # la usa la búsqueda (KnowledgeBase::Selector). Antes cada cuenta inventaba las suyas; se
  # quitaron (migración 20261118120000).
  #   general   lo que vale igual para todos (horarios, datos de la empresa, cómo pedir…)
  #   ficha     lo de UN sujeto (un producto, un servicio, una sucursal, una carrera): su
  #             nombre es el sujeto; nunca se usa para dar datos de otro sujeto
  #   objecion  cómo contestar un pretexto del cliente («está caro», «lo pienso»): solo
  #             cuando el cliente objeta
  KINDS = %w[general ficha objecion].freeze
  validates :kind, inclusion: { in: KINDS }

  # Lo que se guarda es lo que el agente recibe completo: «nombre: contenido» hasta
  # MAX_AGENT_CHARS y el Prompt hasta MAX_PROMPT_CHARS, igual en los tres motores. Solo se
  # revisa cuando el texto cambia: las que ya pasaban siguen funcionando (con SectionFit)
  # hasta que alguien las edite.
  MAX_AGENT_CHARS = 3500
  MAX_PROMPT_CHARS = 2000
  validate :agent_text_fits, if: -> { will_save_change_to_content? || will_save_change_to_short_code? }
  validate :prompt_fits, if: :will_save_change_to_content_prompts?

  belongs_to :account
  # proyecto@auditoria_predefinidas: lo que encontró la auditoría (las borra la FK al
  # eliminar la predefinida, de los dos lados del par).
  has_many :audit_findings, class_name: 'CannedResponseFinding', dependent: nil

  # Lo que el agente recibe de una predefinida es «nombre: contenido» (el texto que se
  # vectoriza, KnowledgeItemSyncJob#extract_content), hasta este tope por respuesta
  # (KnowledgeBaseResponseService::MAX_ITEM_CHARS). Más largo, el modelo ve solo el
  # nombre y las secciones que más se parecen a la pregunta (KnowledgeBase::SectionFit).
  def self.agent_text(short_code, content) = "#{short_code}: #{content}"
  def agent_text = self.class.agent_text(short_code, content)
  def agent_chars = agent_text.size

  # Lo que necesita el formulario para editarla (sin columnas pesadas como `embedding`,
  # que algunas bases todavía tienen).
  FORM_FIELDS = %w[id short_code content content_prompts content_is_prompt kind menu opcion
                   content_full url_content url_short_code].freeze
  def form_json = as_json.slice(*FORM_FIELDS).merge('agent_chars' => agent_chars)

  # @knowledge_sources — sincroniza embeddings al crear/actualizar/eliminar
  # proyecto@predefinidas_prompt — solo se vectoriza lo que se busca (el nombre y el
  # contenido). Cambiar únicamente el prompt propio no toca la búsqueda, y volver a pedir
  # el embedding sería una llamada a OpenAI por nada.
  #
  # Un solo callback: registrar el mismo método dos veces (on: :create y on: :update) hace
  # que Rails se quede con el último, y las respuestas nuevas no se vectorizarían nunca.
  after_commit :sync_knowledge_embedding, on: %i[create update], if: :needs_embedding?
  after_commit :destroy_knowledge_embedding, on: :destroy
  # La categoría no entra al texto vectorizado; cambiarla solo actualiza el dato que lee la
  # búsqueda (metadata 'kind' del vector), sin OpenAI.
  after_update_commit :sync_own_kind_metadata, if: :saved_change_to_kind?

  # proyecto@respuestas_predefinidas R1 — si está en la fuente de datos del agente. Lo que se
  # guarda (embedding_status) lo escribe KnowledgeItemSyncJob; lo que se MUESTRA se calcula
  # con dos datos más, porque lo guardado se queda viejo solo:
  #   ready    tiene vector y está al día                      ✓ en la fuente de datos
  #   pending  se mandó a vectorizar y no ha terminado          ⏳
  #   missing  no tiene vector y la cuenta SÍ tiene OpenAI      [Vectorizar]
  #   no_key   no tiene vector y la cuenta no tiene OpenAI       ⚠ falta activar OpenAI
  #   failed   OpenAI falló y no hay vector                     ✗ motivo · [Reintentar]
  #   stale    OpenAI falló pero queda el vector anterior        ⚠ desactualizada · [Reintentar]
  # Las que llegaron por carga directa (sin callback) no tienen estado guardado: cuentan como
  # missing / no_key hasta que se vectoricen.
  EMBEDDING_STATES = %w[ready pending missing no_key failed stale].freeze

  scope :order_by_search, lambda { |search|
    short_code_starts_with = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 1', "#{search}%"])
    short_code_like = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 0.5', "%#{search}%"])
    content_like = sanitize_sql_array(['WHEN content ILIKE ? THEN 0.2', "%#{search}%"])

    order_clause = "CASE #{short_code_starts_with} #{short_code_like} #{content_like} ELSE 0 END"

    order(Arel.sql(order_clause) => :desc)
  }

  # La categoría fija en el vector de esas predefinidas (sin volver a vectorizar).
  def self.sync_kind_metadata(ids, kind)
    return if ids.blank?

    KnowledgeItem.where(source_type: 'canned_response', source_id: ids)
                 .update_all(["metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{kind}', to_jsonb(?::text))", kind]) # rubocop:disable Rails/SkipsModelValidations
  end

  def embedding_state(has_vector:, has_key:)
    case embedding_status
    when 'pending' then 'pending'
    when 'failed' then has_vector ? 'stale' : 'failed'
    else
      return 'ready' if has_vector

      has_key ? 'missing' : 'no_key'
    end
  end

  # [Vectorizar] / [Reintentar] de la pantalla: una a la vez (D4).
  def queue_embedding!
    update_columns(embedding_status: 'pending', embedding_error: nil) # rubocop:disable Rails/SkipsModelValidations
    sync_knowledge_embedding(audit: false)
  end

  private

  def sync_own_kind_metadata
    self.class.sync_kind_metadata([id], kind)
  end

  def agent_text_fits
    return if agent_chars <= MAX_AGENT_CHARS

    errors.add(:content, :too_long_for_agent, count: MAX_AGENT_CHARS,
                                              message: "es muy larga: nombre y contenido pasan de #{MAX_AGENT_CHARS} caracteres")
  end

  def prompt_fits
    return if content_prompts.to_s.size <= MAX_PROMPT_CHARS

    errors.add(:content_prompts, :too_long, count: MAX_PROMPT_CHARS,
                                            message: "pasa de #{MAX_PROMPT_CHARS} caracteres")
  end

  def needs_embedding?
    previously_new_record? || saved_change_to_short_code? || saved_change_to_content?
  end

  # @knowledge_sources
  # audit: proyecto@auditoria_predefinidas — al guardar desde el formulario (no al
  # [Vectorizar], que no cambia el texto), lo que se había encontrado de esta predefinida
  # ya no vale y, en cuanto tenga su vector nuevo, se revisa contra sus vecinas.
  def sync_knowledge_embedding(audit: true)
    # Marca de «en camino» sin callbacks (update_columns): el job la cambia al terminar.
    update_columns(embedding_status: 'pending', embedding_error: nil) unless embedding_status == 'pending' # rubocop:disable Rails/SkipsModelValidations
    CannedResponseFinding.involving(id).unresolved.delete_all if audit
    KnowledgeItemSyncJob.perform_later(
      action: 'upsert',
      source_type: 'canned_response',
      source_id: id,
      account_id: account_id,
      audit: audit
    )
  end

  def destroy_knowledge_embedding
    KnowledgeItemSyncJob.perform_later(
      action: 'destroy',
      source_type: 'canned_response',
      source_id: id,
      account_id: account_id
    )
  end
end
