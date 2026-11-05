# frozen_string_literal: true

# ================================================================================
# proyecto@respuestas_predefinidas R2 — LA TABLA DE RESPUESTAS PREDEFINIDAS
# ================================================================================
# Plan: docs/respuestas_predefinidas_plan.md §5. Paginación, orden y filtros del lado del
# servidor, como Contactos:
#
#   q        texto en el nombre o el contenido
#   state    estado de vectorización (CannedResponse::EMBEDDING_STATES) o 'not_ready'
#            (todas las que el agente no encontraría: missing, no_key, failed)
#   prompt   'with' | 'without' (prompt propio o la respuesta es un prompt)
#   sort     short_code | created_at | updated_at     order  asc | desc
#   page / per_page (25 por omisión, hasta 100)
#
# El estado se filtra en SQL con las mismas reglas que CannedResponse#embedding_state:
# lo guardado (embedding_status) + si tiene vector (knowledge_items) + si la cuenta tiene
# OpenAI (una sola respuesta para toda la cuenta).
# ================================================================================

class CannedResponseFinder
  SORTS = %w[short_code created_at updated_at].freeze
  PER_PAGE = 25
  MAX_PER_PAGE = 100
  NOT_READY = %w[missing no_key failed].freeze

  def initialize(account, params)
    @account = account
    @params = params
  end

  # { records:, count:, page:, per_page:, summary: }
  # summary: cuántas de TODA la cuenta no encontraría el agente, para el aviso de arriba.
  def perform
    scope = filtered
    { records: scope.order(order_clause).offset((page - 1) * per_page).limit(per_page).to_a,
      count: scope.count, page: page, per_page: per_page, summary: summary }
  end

  def summary
    todas = @account.canned_responses
    { no_key: state_scope(todas, 'no_key').count, missing: state_scope(todas, 'missing').count,
      failed: state_scope(todas, 'failed').count + state_scope(todas, 'stale').count }
  end

  def key? = @key ||= @account.hooks.exists?(app_id: 'openai', status: 'enabled')

  private

  def filtered
    scope = @account.canned_responses
    scope = search(scope)
    scope = by_prompt(scope)
    by_state(scope)
  end

  def search(scope)
    texto = @params[:q].to_s.strip
    return scope if texto.empty?

    patron = "%#{ActiveRecord::Base.sanitize_sql_like(texto)}%"
    scope.where('canned_responses.short_code ILIKE :q OR canned_responses.content ILIKE :q', q: patron)
  end

  def by_prompt(scope)
    con_prompt = "(COALESCE(canned_responses.content_prompts, '') <> '' OR canned_responses.content_is_prompt)"
    case @params[:prompt]
    when 'with' then scope.where(con_prompt)
    when 'without' then scope.where.not(con_prompt)
    else scope
    end
  end

  # Las mismas reglas que CannedResponse#embedding_state, en SQL.
  def by_state(scope)
    estados = @params[:state] == 'not_ready' ? NOT_READY : [@params[:state].to_s]
    estados &= CannedResponse::EMBEDDING_STATES
    return scope if estados.empty?

    estados.map { |estado| state_scope(scope, estado) }.reduce(:or)
  end

  # Sin vector y sin falla: «missing» si la cuenta tiene OpenAI, «no_key» si no.
  def state_scope(scope, estado)
    con = scope.where(vector_exists)
    sin = scope.where.not(vector_exists)
    abierta = "COALESCE(canned_responses.embedding_status, '') NOT IN ('pending', 'failed')"
    {
      'pending' => -> { scope.where(embedding_status: 'pending') },
      'failed' => -> { sin.where(embedding_status: 'failed') },
      'stale' => -> { con.where(embedding_status: 'failed') },
      'ready' => -> { con.where(abierta) },
      (key? ? 'missing' : 'no_key') => -> { sin.where(abierta) }
    }.fetch(estado, -> { scope.where('1 = 0') }).call
  end

  def vector_exists
    KnowledgeItem.where(source_type: 'canned_response', account_id: @account.id)
                 .where('knowledge_items.source_id = canned_responses.id').where.not(embedding: nil).arel.exists
  end

  def order_clause
    columna = SORTS.include?(@params[:sort]) ? @params[:sort] : 'short_code'
    direccion = @params[:order] == 'desc' ? :desc : :asc
    { columna => direccion, :id => direccion }
  end

  def page = [@params[:page].to_i, 1].max

  def per_page
    pedido = @params[:per_page].to_i
    pedido.positive? ? [pedido, MAX_PER_PAGE].min : PER_PAGE
  end
end
