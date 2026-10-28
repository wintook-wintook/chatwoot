# frozen_string_literal: true

# ================================================================================
# proyecto@diagrama_agente_ia — F0: POR DÓNDE PASÓ CADA RESPUESTA
# ================================================================================
# Plan: docs/diagrama_agente_ia_plan.md §3. Mientras ContactTrackingResponseAnalyzerJob
# atiende un mensaje del cliente, cada etapa del motor anota aquí lo que decidió:
#
#   ruta        el clasificador (BranchClassifierService): cuál y cómo se eligió
#   fuente      la directiva que buscó (KnowledgeBaseResponseService#perform)
#   fragmentos  lo que trajo la búsqueda local, con su similitud (search_items)
#   etiqueta    si el motor tuvo que reponer la de la ruta (with_branch_tag)
#   uso         modelo, llamadas y tokens de cada llamada a OpenAI del turno
#   camino      qué parte del job contestó (bienvenida, ticket, kbase, conversacional…)
#
# Al terminar, la traza se escribe en content_attributes['traza'] de cada respuesta del
# bot creada en el turno (Message#register_in_engine_trace las anota al crearse).
#
# POR QUÉ AL FINAL Y NO AL CREAR EL MENSAJE
#   El camino se sabe cuando el handler devuelve, y el mensaje se crea ADENTRO del
#   handler. Escrita al crearse, la traza saldría sin camino justo en las respuestas que
#   más importan. Se escribe con update_columns: no dispara eventos ni callbacks.
#
# QUÉ NO GUARDA
#   Ni el texto del cliente ni el de los fragmentos: solo nombres, títulos y números. La
#   traza va en cada respuesta del bot de todas las conversaciones (decisión D2); no debe
#   crecer la BD ni duplicar datos del cliente.
#
# NUNCA ROMPE EL TURNO
#   Todo método traga sus errores. Fuera de un `run` (prueba en seco, consola, otro job)
#   cada anotación es un no-op.
# ================================================================================

module ContactTrackings::EngineTrace
  VERSION       = 1
  KEY           = :contact_trackings_engine_trace
  MAX_FRAGMENTS = 5
  MAX_TITLE     = 120

  module_function

  def run(message)
    Thread.current[KEY] = { data: { 'v' => VERSION, 'mensaje_id' => message.id }, message_ids: [],
                            conversation_id: message.conversation_id,
                            started: Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    yield
  ensure
    finish
    Thread.current[KEY] = nil
  end

  def active?
    Thread.current[KEY].present?
  end

  # Una anotación de una etapa: reemplaza lo que hubiera bajo esa llave.
  def record(key, value)
    state = Thread.current[KEY]
    state[:data][key.to_s] = value if state
    value
  rescue StandardError
    value
  end

  # El camino que contestó. Devuelve true para usarse como `return answered(...)`.
  def answered(camino)
    record('camino', camino.to_s)
    true
  end

  def route(route, como)
    return record('ruta', { 'como' => 'sin_ruta' }) if route.nil?

    record('ruta', { 'nombre' => route.name, 'etiqueta' => route.hashtag, 'como' => como.to_s }.compact)
  end

  def source(directive)
    return if directive.blank?

    record('fuente', { 'modo' => directive[:mode].to_s, 'nombre' => directive[:source_name],
                       'grupo' => directive[:group] }.compact)
  end

  def fragments(items)
    record('fragmentos', Array(items).first(MAX_FRAGMENTS).map do |item|
      similitud = item.respond_to?(:neighbor_distance) && item.neighbor_distance ? (1 - item.neighbor_distance).round(3) : nil
      { 'titulo' => item.title.to_s.truncate(MAX_TITLE), 'similitud' => similitud }.compact
    end)
  end

  def tag_restored(tag)
    record('etiqueta_repuesta', tag)
  end

  # El `usage` de una respuesta de chat/completions. Suma: un turno hace varias llamadas
  # (clasificar la ruta, redactar) y el costo es el de todas.
  def usage(model, body)
    state = Thread.current[KEY]
    return unless state

    body = JSON.parse(body) if body.is_a?(String)
    uso = state[:data]['uso'] ||= { 'llamadas' => 0, 'tokens' => 0, 'modelos' => [] }
    uso['llamadas'] += 1
    uso['tokens'] += body.dig('usage', 'total_tokens').to_i
    uso['modelos'] |= [model.to_s] if model.present?
  rescue StandardError
    nil
  end

  def register(message)
    state = Thread.current[KEY]
    return unless state && message.conversation_id == state[:conversation_id]

    state[:message_ids] << message.id
  rescue StandardError
    nil
  end

  def finish
    state = Thread.current[KEY]
    return if state.blank? || state[:message_ids].empty?

    base  = state[:data].merge('ms' => elapsed_ms(state))
    total = state[:message_ids].size
    Message.where(id: state[:message_ids]).order(:id).each.with_index(1) do |message, n|
      traza = base.merge('respuesta' => "#{n}/#{total}")
      # Sin validaciones ni callbacks a propósito: ver «POR QUÉ AL FINAL» arriba.
      message.update_columns(content_attributes: message.content_attributes.merge('traza' => traza)) # rubocop:disable Rails/SkipsModelValidations
    end
  rescue StandardError => e
    Rails.logger.warn "[EngineTrace] ⚠️ No se pudo guardar la traza: #{e.message}"
  end

  def elapsed_ms(state)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - state[:started]) * 1000).round
  end
end
