# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LO QUE LA PERSONA EDITÓ A MANO (fase B de PROMPT STUDIO)
# ================================================================================
# El cliente manda dos textos: el que entregó el asistente la última vez
# (`delivered`) y el que está en pantalla (`current`). La diferencia entre los dos es
# lo que la persona escribió a mano, pieza por pieza.
#
# Con eso se hacen dos cosas:
#   1. Se le NOMBRAN al modelo esas piezas, para que no las toque sin que se lo pidan.
#   2. Si igual las pisó sin declararlo, se le devuelven a la persona sus versiones
#      (DraftPieces.restore) y se conserva todo lo demás que el asistente cambió. El
#      Entrenamiento del asistente viaja aparte, para elegirlo con un clic.
#
# El orden es a propósito: primero se aplica lo que NO destruye nada y después se
# pregunta. Preguntar antes costaría otra llamada de ~50 s con un prompt grande, y
# mientras tanto la persona no tiene nada que mirar.
#
# `delivered` nil = el cliente no sabe qué entregó el asistente (una versión vieja de
# la pantalla): no se detecta nada. "" = no hubo entrega todavía, así que TODO lo que
# hay en pantalla lo escribió la persona.
# ================================================================================

class ContactTrackings::Assistant::ManualEdits
  Pieces = ContactTrackings::Assistant::DraftPieces

  def initialize(delivered:, current:)
    @delivered = delivered
    @current = current.to_s
  end

  def edited
    return [] if @delivered.nil?

    @edited ||= ContactTrackings::Assistant::DraftDiff.new(@delivered, @current).changes
  end

  delegate :any?, to: :edited

  def labels
    edited.map(&:key)
  end

  # nil si el asistente respetó lo editado a mano. Si no:
  #   { draft: el suyo con las piezas de la persona devueltas,
  #     conflict: { assistant_draft:, items: [{ key:, mine:, theirs: }] } }
  def resolve(final, declared)
    pisadas = overwritten(final, declared)
    return nil if pisadas.empty?

    mias = Pieces.new(@current).pieces
    suyas = Pieces.new(final).pieces
    { draft: Pieces.restore(theirs: final, mine: @current, keys: pisadas.map(&:slug)),
      conflict: { assistant_draft: final,
                  items: pisadas.map { |c| { key: c.key, mine: mias[c.slug]&.raw, theirs: suyas[c.slug]&.raw } } } }
  end

  private

  # Piezas editadas a mano que el asistente cambió sin nombrarlas en `toca`. Si las
  # nombró, la persona se lo pidió en este mensaje: no hay nada que devolver.
  def overwritten(final, declared)
    return [] unless any?

    a_mano = edited.map(&:slug)
    ContactTrackings::Assistant::DraftDiff.new(@current, final).undeclared(declared)
                                          .select { |change| a_mano.include?(change.slug) }
  end
end
