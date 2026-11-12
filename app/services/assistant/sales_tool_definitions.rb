# frozen_string_literal: true

# Asistente (Dali) — D5a: las funciones de ventas (solo lectura; cifras sin IVA, por
# trato, con los permisos del usuario). Lo que hace cada una vive en Assistant::SalesTools.
module Assistant::SalesToolDefinitions
  def self.fn(*args) = Assistant::ToolDefinitions.fn(*args)
  def self.str(description) = Assistant::ToolDefinitions.str(description)
  def self.int(description) = Assistant::ToolDefinitions.int(description)

  SELLER = { type: 'string', description: 'Nombre del vendedor (opcional)' }.freeze
  PERIOD = {
    period: { type: 'string', enum: Sales::Period::NAMES, description: 'Periodo con nombre (por omisión this_month)' },
    from: { type: 'string', description: 'Inicio YYYY-MM-DD (solo si el usuario da fechas exactas)' },
    to: { type: 'string', description: 'Fin YYYY-MM-DD' }
  }.freeze

  ALL = [
    fn('sales_overview',
       '¿Cómo vamos? Lo ganado en el periodo contra el periodo anterior o el año pasado, contra la meta (presupuesto) ' \
       'con el ritmo, tasa de cierre, ciclo y lo abierto que cierra en el periodo.',
       PERIOD.merge(compare: { type: 'string', enum: %w[previous last_year] }, seller: SELLER)),
    fn('budget_progress',
       'Avance contra el presupuesto por vendedor y sus clientes, y las oportunidades abiertas que podrían cubrir lo que falta.',
       PERIOD.merge(seller: SELLER, currency: str('Moneda, p. ej. MXN'))),
    fn('pipeline_health',
       'Salud del embudo: abierto y ponderado, por etapa, compromisos vencidos, cierres vencidos, sin fecha y estancadas.',
       { seller: SELLER }),
    fn('sales_breakdown',
       'Ranking de lo ganado por vendedor o por cliente (monto, tratos, ticket promedio, tasa de cierre).',
       PERIOD.merge(dimension: { type: 'string', enum: %w[seller client] },
                    metric: { type: 'string', enum: %w[won_value won_count avg_ticket win_rate] },
                    top: int('Cuántos, máximo 20')),
       %w[dimension]),
    fn('deal_list',
       'Oportunidades para actuar: las que cierran esta semana o este mes, vencidas, compromisos vencidos, estancadas, ' \
       'las abiertas más grandes o las ganadas este mes.',
       { filter: { type: 'string', enum: Sales::Insights::DEAL_FILTERS }, seller: SELLER,
         min_amount: { type: 'number', description: 'Monto mínimo' } },
       %w[filter])
  ].freeze
end
