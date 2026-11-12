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
#  menu              :boolean          default(FALSE), not null
#  opcion            :bigint           default(0), not null
#  short_code        :string
#  url_content       :boolean          default(FALSE), not null
#  url_short_code    :text
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :integer          not null
#  category_id       :bigint
#

class CannedResponse < ApplicationRecord
  validates :content, presence: true
  validates :short_code, presence: true
  validates :account, presence: true
  validates :short_code, uniqueness: { scope: :account_id }

  belongs_to :account
  # proyecto@respuestas_predefinidas R3: una categoría o ninguna (D1).
  belongs_to :category, class_name: 'CannedResponseCategory', optional: true, inverse_of: :canned_responses
  validate :category_from_account

  # @knowledge_sources — sincroniza embeddings al crear/actualizar/eliminar
  # proyecto@predefinidas_prompt — solo se vectoriza lo que se busca (el nombre y el
  # contenido). Cambiar únicamente el prompt propio no toca la búsqueda, y volver a pedir
  # el embedding sería una llamada a OpenAI por nada.
  #
  # Un solo callback: registrar el mismo método dos veces (on: :create y on: :update) hace
  # que Rails se quede con el último, y las respuestas nuevas no se vectorizarían nunca.
  after_commit :sync_knowledge_embedding, on: %i[create update], if: :needs_embedding?
  after_commit :destroy_knowledge_embedding, on: :destroy
  # R3/D2: la categoría no entra al texto vectorizado; cambiarla solo actualiza el dato que
  # lee la búsqueda (metadata 'category' del vector), sin OpenAI.
  after_update_commit :sync_own_category_metadata, if: :saved_change_to_category_id?

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

  # El nombre de la categoría en el vector de cada predefinida (nil = sin categoría).
  def self.sync_category_metadata(ids, nombre)
    return if ids.blank?

    items = KnowledgeItem.where(source_type: 'canned_response', source_id: ids)
    if nombre.nil?
      items.update_all("metadata = COALESCE(metadata, '{}'::jsonb) - 'category'") # rubocop:disable Rails/SkipsModelValidations
    else
      items.update_all(["metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{category}', to_jsonb(?::text))", nombre]) # rubocop:disable Rails/SkipsModelValidations
    end
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
    sync_knowledge_embedding
  end

  private

  def category_from_account
    errors.add(:category, :invalid) if category && category.account_id != account_id
  end

  def sync_own_category_metadata
    self.class.sync_category_metadata([id], category&.name)
  end

  def needs_embedding?
    previously_new_record? || saved_change_to_short_code? || saved_change_to_content?
  end

  # @knowledge_sources
  def sync_knowledge_embedding
    # Marca de «en camino» sin callbacks (update_columns): el job la cambia al terminar.
    update_columns(embedding_status: 'pending', embedding_error: nil) unless embedding_status == 'pending' # rubocop:disable Rails/SkipsModelValidations
    KnowledgeItemSyncJob.perform_later(
      action: 'upsert',
      source_type: 'canned_response',
      source_id: id,
      account_id: account_id
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
