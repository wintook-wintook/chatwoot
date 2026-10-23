# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — ENMASCARADO DE LAS FRASES DE CLIENTES
# ================================================================================
# Tapa datos personales en los mensajes de clientes antes de que salgan del
# servidor hacia OpenAI.
#
# POR QUÉ NO CUESTA CALIDAD:
#   Las frases reales sirven para UNA cosa: escribir la descripción de cada rama en
#   las palabras del cliente, que es lo único que el clasificador usa para rutear.
#   Lo que aporta ahí es el vocabulario —cómo nombran tus productos, qué jerga usan,
#   cómo escriben mal—, no un teléfono ni un RFC. Enmascarar saca justo la parte que
#   no clasifica nada. No es un compromiso entre privacidad y calidad.
#
# QUÉ NO SE TAPA, A PROPÓSITO:
#   Números cortos. "firebird 5", "CONTPAQi 2026" o "factura A-1234" son vocabulario
#   del negocio y tienen que sobrevivir: taparlos SÍ degradaría la clasificación. Por
#   eso el corte va en 7 dígitos seguidos, y un teléfono exige 10 dígitos reales —
#   así una fecha como 2026-09-11 no se confunde con un número de contacto.
#
#   Tampoco se tapan nombres de persona: distinguirlos de un nombre de producto no
#   es fiable, y equivocarse borraría justo el vocabulario que se vino a buscar.
#
# DÓNDE SE VE:
#   La pantalla del Asistente muestra estas frases YA enmascaradas — las mismas que
#   se envían. Lo que se ve es lo que sale.
# ================================================================================

class ContactTrackings::Assistant::PhraseMasker
  EMAIL = /[\w+.-]+@[\w-]+(?:\.[\w-]+)+/
  # CURP antes que RFC: la CURP empieza igual y si corriera después quedaría a medias.
  CURP  = /\b[A-ZÑ]{4}\d{6}[HM][A-Z]{5}[A-Z\d]{2}\b/i
  RFC   = /\b[A-ZÑ&]{3,4}\d{6}[A-Z\d]{3}\b/i
  # Candidato a teléfono: dígitos con separadores. Solo se tapa si además tiene 10
  # dígitos reales (ver PHONE_MIN_DIGITS), para no comerse fechas ni versiones.
  PHONE_CANDIDATE = /\+?\d[\d\s().-]{7,}\d/
  PHONE_MIN_DIGITS = 10
  # Series largas sueltas: folios, cuentas, números de cliente.
  LONG_DIGITS = /\b\d{7,}\b/

  def self.call(text)
    new(text).call
  end

  def initialize(text)
    @text = text.to_s
  end

  def call
    masked = @text.gsub(EMAIL, '[correo]')
    masked = masked.gsub(CURP, '[curp]')
    masked = masked.gsub(RFC, '[rfc]')
    masked = mask_phones(masked)
    masked.gsub(LONG_DIGITS, '[numero]')
  end

  private

  # Se decide con el conteo de dígitos y no con la forma, porque la forma de un
  # teléfono escrito a mano es impredecible y la de una fecha se le parece.
  def mask_phones(text)
    text.gsub(PHONE_CANDIDATE) do |match|
      match.count('0-9') >= PHONE_MIN_DIGITS ? '[telefono]' : match
    end
  end
end
