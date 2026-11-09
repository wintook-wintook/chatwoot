# frozen_string_literal: true

# El cliente nombra un valor largo por una parte: «bienes raíces» es la «Desarrollo y
# Administración Inmobiliaria en Bienes Raíces». Vale un tramo de dos o más palabras con
# contenido, seguidas, que ningún otro valor de la columna tiene. Una sola palabra no basta:
# «social» de «servicio social» no es «Trabajo Social».
#
# Medido el 06/11/2026 (producción, cuenta 613, AGENTE ESCUELA): «y para bienes raíces es lo
# mismo» no encontraba la fila; con CARRERA=Relaciones Internacionales el bot dijo cinco veces
# que no tenía la información de inscripción y luego mandó la liga de RI.
module ContactTrackings::SheetLookup::ShortNames
  FILLER = %w[a de del e el en la las los o para por y licenciatura maestria].freeze

  private

  # Los nombrados completos o por un tramo propio. Si uno nombrado contiene a otro
  # («Administración» dentro de «… Inmobiliaria en Bienes Raíces»), se queda el largo.
  def named_values(text, known)
    found = known.select { |value| mentions?(text, value) || own_spans(value, known).any? { |span| mentions?(text, span) } }
    found.reject { |value| found.any? { |otro| otro != value && mentions?(otro, value) } }
  end

  def own_spans(value, known)
    @own_spans ||= {}
    @own_spans[value] ||= begin
      otros = known - [value]
      spans(value).reject { |span| otros.any? { |otro| mentions?(otro, span) } }
    end
  end

  # Tramos seguidos que empiezan y terminan en palabra con contenido y tienen al menos dos.
  def spans(value)
    words = value.split(/\s+/)
    (0...words.size).flat_map do |i|
      (i + 1...words.size).filter_map do |j|
        tramo = words[i..j]
        next if filler?(tramo.first) || filler?(tramo.last) || tramo.count { |w| !filler?(w) } < 2

        tramo.join(' ')
      end
    end
  end

  def filler?(word)
    FILLER.include?(ContactTrackings::SheetNumbers.fold(word).gsub(/[^[:alnum:]]/, ''))
  end
end
