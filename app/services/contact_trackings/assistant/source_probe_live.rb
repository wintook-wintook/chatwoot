# frozen_string_literal: true

# ================================================================================
# proyecto@crear_agente_conversando §15 — PROBAR FUENTES (P3: en vivo)
# ================================================================================
# Las fuentes que se consultan fuera del sistema, con las mismas piezas del motor:
#
#   @buscar_foro(X)       el foro de la fuente X: búsqueda semántica de Discourse AI
#   @discourse            el foro de la integración de la BANDEJA del agente
#                         (sin Discourse AI: la búsqueda normal; la IA saca 1 a 3 términos)
#   @soporte_contpaq(X)   el Agente de Servicio de CONTPAQi: responde ya escrito, con sus
#                         fuentes. Cada prueba abre un hilo NUEVO en su servicio, a nombre
#                         de quien prueba (no de un cliente).
#
# Del foro, el agente usa los primeros MAX_RESULTS (3) que tengan contenido: aquí se
# marcan los que tomaría. No se baja el post entero (el motor sí, con 1.5 s entre cada
# uno): para probar basta el extracto.
# ================================================================================

class ContactTrackings::Assistant::SourceProbeLive
  Semantic = KnowledgeBase::DiscourseSemanticSearch
  MAX_RESULTS = KnowledgeBaseResponseService::MAX_RESULTS
  SHOWN = 8
  # El usuario con el que CONTPAQi abre el hilo: el de quien prueba, no un cliente.
  TEST_USER = 'asistente-prueba-%<id>s'

  def initialize(account, inbox: nil, user: nil)
    @account = account
    @inbox = inbox
    @user = user
  end

  def forum(nombre, frase)
    fuente = @account.knowledge_sources.active.find_by('LOWER(name) = LOWER(?)', nombre.to_s.strip)
    return { kind: 'live', error: 'source_missing' } if fuente.nil?

    forum_hits(fuente.config.to_h, frase)
  end

  # @discourse usa la integración de la bandeja: sin bandeja no se sabe cuál.
  def discourse_integration(frase)
    return { kind: 'live', error: 'needs_inbox' } if @inbox.nil?

    hook = @account.hooks.find_by(app_id: 'discourse', inbox_id: @inbox.id, status: 'enabled')
    return { kind: 'live', error: 'hook_missing' } if hook.nil?

    forum_hits(hook.settings.to_h, frase)
  end

  def contpaq(nombre, frase)
    fuente = @account.knowledge_sources.active
                     .find_by(['source_type = ? AND LOWER(name) = LOWER(?)', 'contpaq_support', nombre.to_s.strip])
    return { kind: 'live', error: 'source_missing' } if fuente.nil?

    resultado = Contpaq::ServiceAgent.new(fuente).answer(question: frase, user_id: test_user,
                                                         conversation_id: "asistente-#{SecureRandom.hex(6)}")
    return { kind: 'live', service: 'contpaq', status: 'no_answer', reason: resultado.error.to_s } unless resultado.ok?

    { kind: 'live', service: 'contpaq', status: 'ok', answer: resultado.answer, sources: resultado.sources }
  end

  private

  def forum_hits(config, frase)
    hits = Semantic.hits(frase, config)
    modo = 'semantic'
    terminos = nil
    if hits == Semantic::NOT_AVAILABLE
      busqueda = KnowledgeBase::DiscourseKeywordSearch.new(config, ask: ->(mensajes) { chat.call_text(mensajes) })
      hits = busqueda.hits(frase)
      modo = 'keyword'
      terminos = busqueda.terms(frase)
    end
    { kind: 'live', service: 'forum', status: hits.any? ? 'ok' : 'no_results', mode: modo, terms: terminos,
      max_results: MAX_RESULTS, results: results(hits) }.compact
  rescue StandardError => e
    { kind: 'live', error: 'failed', detail: e.message.truncate(200) }
  end

  def results(hits)
    hits.first(SHOWN).each_with_index.map do |hit, index|
      { title: hit[:title], url: hit[:url], excerpt: hit[:blurb].to_s.squish.truncate(300), used: index < MAX_RESULTS }
    end
  end

  def test_user
    "#{format(TEST_USER, id: @user&.id || 0)}@#{Contpaq::UserIdBuilder::DOMAIN}"
  end

  def chat
    @chat ||= ContactTrackings::Assistant::OpenaiChat.new(account: @account, inbox: @inbox)
  end
end
