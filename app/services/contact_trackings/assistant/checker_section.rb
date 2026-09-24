# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LO QUE YA COMPROBÓ EL COMPROBADOR, PARA EL CHAT
# ================================================================================
# Pedido del usuario (24/09/2026): pegar un prompt en el editor y preguntarle al chat
# «¿qué errores tiene?». El chat contestaba con su propia lectura: podía callar un
# rojo que el comprobador marca, o llamar error a algo que no lo es.
#
# Ahora, al editar, el chat recibe los hallazgos del comprobador (ValidatorService: el
# parser real del motor, gratis y sin IA) como HECHOS, y contesta separando lo
# comprobado de su lectura. Son los mismos avisos que la persona ve en rojo y ámbar.
# ================================================================================

module ContactTrackings::Assistant::CheckerSection
  MAX_FINDINGS = 25
  MAX_MESSAGE = 300

  module_function

  def call(draft, account:)
    return nil if draft.to_s.strip.empty?

    resultado = ContactTrackings::Assistant::ValidatorService.new(draft, account: account).call
    <<~SECCION.strip
      ═══ LO QUE YA COMPROBÓ EL COMPROBADOR (el parser real del motor) ═══
      Son HECHOS, no opiniones, y la persona los ve marcados en pantalla (rojo: no se ejecuta;
      ámbar: funciona mal). Si te preguntan por errores o por qué algo no funciona, parte de
      esta lista: nombra cada punto con su línea o su ruta. Puedes sumar tu lectura
      (contradicciones, reglas vagas, lo que falta), pero sepárala con «Mi lectura:». Nunca
      digas que algo está bien si aparece aquí. Todo va DENTRO de "mensaje", como texto con
      viñetas: no agregues llaves nuevas al JSON.

      #{findings_text(resultado)}
    SECCION
  rescue StandardError => e
    Rails.logger.warn "[Asistente] no se pudo comprobar para el chat: #{e.message}"
    nil
  end

  def findings_text(resultado)
    lineas = { 'ROJO' => resultado[:blocking], 'ÁMBAR' => resultado[:degrading] }.flat_map do |nivel, hallazgos|
      Array(hallazgos).map { |f| "- #{nivel}#{where(f)}: #{f[:message].to_s.squish.truncate(MAX_MESSAGE)}" }
    end
    return '- Sin hallazgos: el comprobador no marca nada.' if lineas.empty?

    extra = lineas.size > MAX_FINDINGS ? ["- (y #{lineas.size - MAX_FINDINGS} más)"] : []
    (lineas.first(MAX_FINDINGS) + extra).join("\n")
  end

  # Sin repetir la línea cuando el aviso ya empieza con ella («Línea 8: …»).
  def where(finding)
    partes = []
    partes << "línea #{finding[:line]}" if finding[:line] && !finding[:message].to_s.match?(/\A(Línea|Line) \d/)
    rutas = finding[:routes] || [finding[:route]].compact
    partes << "ruta #{rutas.join(', ')}" if rutas.any?
    partes.any? ? " (#{partes.join(' · ')})" : ''
  end
end
