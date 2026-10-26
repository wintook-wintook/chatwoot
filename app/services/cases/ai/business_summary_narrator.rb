# frozen_string_literal: true

# ================================================================================
# @tickets_cases — «Resumen del negocio»: «Explícame la semana» con IA
# ================================================================================
# Servicio: Cases::Ai::BusinessSummaryNarrator
#
# Recibe el resumen YA CALCULADO (V2::Reports::Cases::BusinessSummaryBuilder) y lo
# cuenta en lenguaje de dueño: qué va bien, qué preocupa y qué haría hoy. Como en
# «Plan de mi día», la IA explica y no decide: no inventa cifras (solo usa las
# que recibe) ni toca datos. Devuelve un Hash o nil ante cualquier fallo.
# ================================================================================

class Cases::Ai::BusinessSummaryNarrator < Cases::Ai::BaseService
  MAX_ITEMS = 5

  # summary: el Hash del builder · period: texto del período («1–21 oct») y su
  # comparación («1–21 sept»), tal como los ve el dueño.
  def narrate(summary:, period: nil, compare: nil)
    raw = chat(system: system_prompt, user: user_prompt(summary, period, compare), json: true,
               temperature: 0.3, max_tokens: 700)
    return nil if raw.blank?

    sanitize(raw)
  end

  private

  def system_prompt
    <<~PROMPT.strip
      Eres el asesor de confianza del dueño de un negocio. Recibes el resumen de su
      negocio (ventas, soporte, órdenes de trabajo y proyectos) en JSON, con cifras ya
      calculadas. Explícaselo en español, como se lo diría un gerente en 30 segundos:
        - Directo y concreto, sin tecnicismos ni palabras como "KPI" o "pipeline".
        - Usa SOLO las cifras que recibes; no inventes datos, nombres ni porcentajes.
        - Los montos van con su moneda; nunca sumes monedas distintas.
        - Si algo no se puede comparar (sin período anterior), no lo compares.
        - "committed" = lo que el cliente ya se comprometió a pagar; "overdue" = vencido.
      Responde EXCLUSIVAMENTE con un objeto JSON:
        {
          "headline": "una frase: cómo va el negocio",
          "good": ["lo que va bien, una frase cada uno (máx. 3)"],
          "watch": ["lo que preocupa, una frase cada uno (máx. 3)"],
          "today": ["qué haría hoy, acción concreta (máx. 3)"]
        }
    PROMPT
  end

  def user_prompt(summary, period, compare)
    <<~PROMPT.strip
      PERÍODO: #{period.presence || '(sin período)'}
      COMPARADO CON: #{compare.presence || '(sin comparación)'}

      RESUMEN:
      #{summary.to_json}
    PROMPT
  end

  def sanitize(raw)
    {
      'headline' => raw['headline'].to_s.strip,
      'good' => clean_list(raw['good']),
      'watch' => clean_list(raw['watch']),
      'today' => clean_list(raw['today'])
    }
  end

  def clean_list(list)
    Array(list).filter_map { |item| item.to_s.strip.presence }.first(MAX_ITEMS)
  end
end
