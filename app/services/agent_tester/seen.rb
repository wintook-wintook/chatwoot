# frozen_string_literal: true

# Probador de agentes — todo lo que el agente tuvo a la vista al contestar: su Entrenamiento (1.0)
# o su ficha (2.0), el contexto del negocio, la plática y lo que le llegó de las fuentes (la
# traza). Con eso el juez y el entrenador revisan si un monto, porcentaje o código de la
# respuesta salió de algún lado o lo inventó (KnowledgeBase::DataGuard).
#
#   AgentTester::Seen.new(template).text(turns, trace) → String
class AgentTester::Seen
  def initialize(template)
    @template = template
    @account = template.account
  end

  def text(turns, trace)
    [agent_text, Array(turns).map { |t| t['content'] || t[:content] }, sources(trace.to_h)].flatten.compact.join("\n")
  end

  private

  def agent_text
    base = [@template.ai_context.to_s, business_data]
    return base + [@template.complementary_prompt.to_s] unless Motor2.on?(@template)

    config = Motor2::Config.new(@template)
    base + [config.instructions, config.never, config.welcome, config.business.to_json]
  rescue StandardError
    base || []
  end

  def business_data
    AgentBase::BusinessData.lines(@account).to_s
  rescue StandardError
    ''
  end

  # 1.0: la traza guarda solo los títulos; el texto se busca. 2.0: la traza trae lo encontrado.
  def sources(trace)
    return Array(trace['sources']).flat_map { |s| Array(s['found']) } if trace['engine'] == '2'

    titulos = Array(trace['fragmentos']).pluck('titulo').compact_blank
    return [] if titulos.empty?

    # La traza recorta los títulos largos («…»): se buscan por su principio, no iguales.
    condiciones = titulos.map do |t|
      ActiveRecord::Base.sanitize_sql_array(['knowledge_items.title LIKE ?', "#{ActiveRecord::Base.sanitize_sql_like(t.sub(/(\.\.\.|…)\z/, ''))}%"])
    end
    @account.knowledge_items.where(condiciones.join(' OR ')).limit(20).pluck(:content)
  end
end
