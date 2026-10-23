# frozen_string_literal: true

# ================================================================================
# proyecto@erp_productos — UNA {{consulta:}} CON "?", DE PUNTA A PUNTA (sin redactar)
# ================================================================================
# Plan: docs/erp_productos_plan.md (§3.2). Lo usa el motor (KnowledgeBaseResponseService)
# cuando la directiva del turno pide parámetros a la IA:
#
#   1. encuentra la consulta (mismas reglas de conexión que el render de siempre);
#   2. la IA llena SOLO los "?" (ExternalDb::AskedParams);
#   3. se suman los valores fijos —que siempre ganan—, el posicional y el RFC del contacto;
#   4. corre, recorta a `max` y, si hace falta, busca por palabra: ExternalDb::AskedRun.
#
# Devuelve { query:, rows:, columns: } o nil = no aplica (el mensaje no pide esta
# consulta, la IA no respondió, la consulta no existe o falló): el motor sigue su camino
# y el agente contesta como siempre, sin inventar datos.
# ================================================================================
class ExternalDb::AskedConsulta
  # conversation: de ahí salen la cuenta, el inbox (conexión por defecto y modelo) y el
  # contacto (su RFC).
  def initialize(source:, question:, conversation:, history: [])
    @source = source
    @question = question
    @inbox = conversation.inbox
    @history = history
    @renderer = ExternalDb::ConsultaDirectiveRenderer.new(account: conversation.account, contact: conversation.contact,
                                                          inbox: @inbox)
  end

  def call
    directive = ExternalDb::ConsultaDirectiveRenderer.parse(@source).find(&:asks?)
    query = directive && @renderer.resolve(directive)
    return log(nil, "consulta '#{directive&.name}' no encontrada") unless query

    filled = ExternalDb::AskedParams.new(query: query, asked: directive.asked, question: @question, inbox: @inbox,
                                         history: @history).call
    return log(nil, "#{query.name}: el mensaje no la pide o la IA no respondió") unless filled && filled[:use]

    run(query, @renderer.params_for(directive, query, filled[:params]))
  end

  private

  def run(query, params)
    ExternalDb::AskedRun.new(query, params).call
  rescue StandardError => e
    log(nil, "#{query.name}: #{e.message}")
  end

  def log(value, reason)
    Rails.logger.info "[ExternalDb::AskedConsulta] ⏭️ #{reason}"
    value
  end
end
