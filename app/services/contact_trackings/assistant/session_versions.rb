# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — QUÉ VERSIONES DEJA UN TURNO (fase D de PROMPT STUDIO)
# ================================================================================
# Hasta dos por turno, en este orden:
#   1. lo que la persona tenía en pantalla, si difiere de la última versión:
#        loaded  el agente cargado, cuando todavía no hay versiones y nadie lo tocó
#        manual  lo que cambió a mano desde la última versión (o lo que restauró)
#   2. lo que devolvió el asistente, si trajo Entrenamiento
# TrackingAssistantSession#add_version saltea las que repiten el texto de la última:
# una edición rechazada devuelve el mismo Entrenamiento que había, y no suma nada.
# ================================================================================

class ContactTrackings::Assistant::SessionVersions
  SIGNS = { added: '+', changed: '~', removed: '-' }.freeze

  def initialize(sesion, on_screen:, delivered:)
    @sesion = sesion
    @on_screen = on_screen.to_s
    @delivered = delivered
  end

  def record(result)
    record_on_screen
    return if result.draft.blank?

    @sesion.add_version(draft: result.draft, source: 'assistant', validation: result.validation,
                        summary: Array(result.changes&.dig(:summary)).first || result.reply)
  end

  private

  def record_on_screen
    return if @on_screen.blank? || @on_screen == @sesion.last_version_draft

    anterior = @sesion.last_version_draft || @delivered
    @sesion.add_version(draft: @on_screen, source: source, summary: summary(anterior))
  end

  def source
    @sesion.draft_versions.blank? && @delivered == @on_screen ? 'loaded' : 'manual'
  end

  # Qué cambió, en piezas: "~ [ESTILO] · + @ruta(factura)".
  def summary(anterior)
    return nil if anterior.blank?

    ContactTrackings::Assistant::DraftDiff.new(anterior, @on_screen).changes
                                          .map { |c| "#{SIGNS[c.kind]} #{c.key}" }.join(' · ').presence
  end
end
