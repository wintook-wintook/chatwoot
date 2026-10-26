# frozen_string_literal: true

# proyecto@solicitudes (pieza 5, F3) — los «?» de {{hoja_buscar:}} con el texto de UN servicio
# («hiab 12 t», «low boy 50 t») en vez de los mensajes de la conversación.
module ContactTrackings::SheetLookup::ServiceText
  UNITS_RE = /\d+(?:[.,]\d+)?\s*(?:toneladas?|tons?|tn|t|kilos?|kgs?|kg|metros?|mts?|m)?\b/

  private

  # El valor completo («TP-64»), la frase del equipo dentro del valor («low boy» → «Low boy
  # (cama muy baja…)») o una palabra suya de 4+ letras («plana» → «Plataforma plana»).
  def in_service_text(known)
    frase = ContactTrackings::SheetNumbers.fold(@text).gsub(UNITS_RE, ' ').squish
    palabras = frase.scan(/[[:alpha:]]{4,}/)
    known.select do |valor|
      plano = ContactTrackings::SheetNumbers.fold(valor)
      mentions?(@text, valor) || (frase.present? && plano.include?(frase)) ||
        palabras.any? { |palabra| plano.match?(/\b#{Regexp.escape(palabra)}\b/) }
    end
  end

  def service_number(filter)
    numeros = ContactTrackings::SheetNumbers.in_text(@text, filter.column)
    return nil if numeros.empty?

    filter.op.start_with?('>') ? numeros.max : numeros.min
  end
end
