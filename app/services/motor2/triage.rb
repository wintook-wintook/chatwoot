# frozen_string_literal: true

# Motor 2.0 — el clasificador de «Atención a clientes» (Plan-Motor-Agentes §11.15; plan funcional del
# Coordinador Kontrolya §2, §5, §11, §17–19). Una llamada corta y aparte (AiModels::REVIEW,
# temperatura 0) que decide, con la plática completa:
#   - el área de lo que pide (por la INTENCIÓN, no por la palabra: «no puedo enviar una cotización» es
#     Soporte); 'none' si solo saluda, agradece o platica;
#   - si es suficiente para actuar o hace falta UNA aclaración (y cuál);
#   - en Comercial, si es información o una gestión (cotización, demo, visita, vendedor, contratar);
#   - en Soporte, la severidad (1 no puede operar, 2 funciona con falla, 3 duda de uso/configuración);
#   - si pide una persona;
#   - las otras solicitudes del mismo mensaje (multi-intención): ninguna se pierde.
# Continuidad: si quedó una aclaración pendiente, el mensaje se evalúa primero contra ella («10
# usuarios» completa «quiero una cotización»).
#
#   Motor2::Triage.new(account).call(areas:, history:, pending:, queue:)
#   → { 'atender' => { 'area', 'intencion', 'suficiente', 'aclaracion', 'gestion', 'severidad', 'pide_persona' },
#       'pendientes' => [{ 'area', 'intencion' }] }
class Motor2::Triage < Cases::Ai::BaseService
  HISTORY = 8
  GESTIONES = %w[info cotizacion demo visita vendedor contratar otra].freeze

  SYSTEM = <<~TEXT
    Clasificas los mensajes de un cliente de una empresa para saber qué área lo atiende. Decide por la
    INTENCIÓN (qué resultado busca), no por una palabra suelta: si quiere reparar algo que falla (aunque
    hable de cotizaciones o facturas) es soporte; si quiere conocer, cotizar, comprar o contratar es
    comercial; si es una gestión de su cuenta (factura, pago, saldo, RFC) es administrativo.
    Reglas:
    - Si hay una ACLARACIÓN PENDIENTE, primero ve si el último mensaje la contesta: entonces es la MISMA
      solicitud completada (misma área), no una nueva («10 usuarios» completa «quiero una cotización»).
    - «suficiente»: false solo si no se entiende qué necesita para poder actuar («quiero información»,
      «quiero una cotización» sin decir de qué, «tengo un problema con una factura»); entonces da en
      «aclaracion» UNA pregunta corta. Una gestión administrativa clara («mi factura tiene mal el RFC») ya
      es suficiente: no pidas datos de más.
    - «gestion» (solo comercial): info si busca información (preguntar «¿cuánto cuesta…?» o «¿qué planes
      tienen?» es info); cotizacion solo si pide una cotización; demo, visita, vendedor, contratar u otra si
      pide que se haga algo. Que un vendedor vaya a verlo es visita. Una visita no es una demo.
    - «severidad» (solo soporte): 1 SOLO si no puede usar nada (el sistema no abre, no puede entrar, todo está
      detenido); 2 si una función o una parte falla («no puedo enviar una cotización», «no se genera la factura»);
      3 duda de uso o configuración.
    - area "none" si solo saluda, agradece, se despide o platica sin pedir nada.
    - Si en el mismo mensaje pide varias cosas independientes, la primera va en «atender» y las demás en
      «pendientes». Conserva en «pendientes» las que ya estaban pendientes y no se han atendido.
    - «pide_persona»: true si pide hablar con una persona, un asesor o un humano. Si pide una persona sin
      decir para qué, el área es "none" (no la adivines); «quiero hablar con un vendedor» sí es comercial.
    Responde solo JSON:
    {"atender": {"area": "...", "intencion": "...", "suficiente": true, "aclaracion": "", "gestion": "", "severidad": 0,
     "pide_persona": false}, "pendientes": [{"area": "...", "intencion": "..."}]}
  TEXT

  def call(areas:, history:, pending: nil, queue: [])
    result = chat(system: SYSTEM, user: context(areas, history, pending, queue), json: true, temperature: 0, max_tokens: 400)
    clean(result, areas)
  rescue StandardError => e
    Rails.logger.warn("[Motor2::Triage] #{e.class}: #{e.message}")
    nil
  end

  private

  def model = AiModels::REVIEW

  def context(areas, history, pending, queue)
    lines = ['ÁREAS:', *areas.flat_map { |a| area_lines(a) }]
    lines << "ACLARACIÓN PENDIENTE: #{pending['area']} — «#{pending['intencion']}»; se le preguntó: «#{pending['aclaracion']}»" if pending
    lines << "PENDIENTES DE ANTES: #{queue.map { |q| "#{q['area']}: #{q['intencion']}" }.join(' | ')}" if queue.present?
    lines << 'PLÁTICA (la última línea es el mensaje a clasificar):'
    Array(history).last(HISTORY).each { |m| lines << "#{m[:role].to_s == 'user' ? 'CLIENTE' : 'AGENTE'}: #{m[:content].to_s.first(400)}" }
    lines.join("\n")
  end

  def area_lines(area)
    lines = ["- #{area['key']} (#{area['title']}): #{area['when']}"]
    lines << "  sí: #{area['examples_yes'].join(' | ')}" if area['examples_yes'].present?
    lines << "  no: #{area['examples_no'].join(' | ')}" if area['examples_no'].present?
    lines
  end

  # Solo áreas que existen; lo demás, con valores conocidos.
  def clean(result, areas)
    return nil unless result.is_a?(Hash) && result['atender'].is_a?(Hash)

    keys = areas.pluck('key')
    { 'atender' => clean_now(result['atender'], keys), 'pendientes' => clean_queue(result['pendientes'], keys) }
  end

  def clean_now(now, keys)
    { 'area' => now['area'].to_s.presence_in(keys) || 'none', 'intencion' => now['intencion'].to_s.first(200),
      'suficiente' => now['suficiente'] != false, 'aclaracion' => now['aclaracion'].to_s.first(200),
      'gestion' => now['gestion'].to_s.presence_in(GESTIONES), 'severidad' => now['severidad'].to_i.clamp(0, 3),
      'pide_persona' => now['pide_persona'] == true }.compact
  end

  def clean_queue(list, keys)
    Array(list).filter_map do |item|
      item = item.to_h
      { 'area' => item['area'], 'intencion' => item['intencion'].to_s.first(200) } if keys.include?(item['area'])
    end.first(5)
  end
end
