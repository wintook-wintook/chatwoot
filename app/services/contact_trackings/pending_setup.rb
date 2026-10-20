# frozen_string_literal: true

# ================================================================================
# proyecto@adaptar_prompts_publicados (F5) — UN AGENTE CON DATOS POR CONFIGURAR NO HABLA
# ================================================================================
# Un prompt bajado de la Galería llega con <PENDIENTE: Nombre del negocio> (F4) y se crea
# sin pasar por el comprobador (PublishedPrompts::Installer). Si se usa antes de llenar
# la pestaña «Configurar», el agente le escribiría al cliente «<PENDIENTE: horario>» tal
# cual — ya pasó el 15/09/2026, cuando las marcas todavía no bloqueaban nada.
#
# Dos candados:
#   · TrackingTemplate: no se le asigna bandeja con marcas en el Entrenamiento.
#   · El motor, en sus tres entradas, con la copia del seguimiento (que es lo que lee):
#       ContactTrackingJob          primer mensaje      → seguimiento fallido, con el motivo
#       TrackingDispatch::SendJob   envío de campaña     → ídem (fail_claimed)
#       ContactTrackingResponseAnalyzerJob  respuestas   → no contesta ese seguimiento
#     El primero no alcanza: las campañas crean los seguimientos con insert! (sin
#     validaciones) y se puede asignar un agente sin bandeja.
# Plan: docs/adaptar_prompts_publicados_plan.md
# ================================================================================

module ContactTrackings::PendingSetup
  class Blocked < StandardError; end

  FIELDS = %i[complementary_prompt ai_context objective].freeze

  module_function

  # Las marcas de un seguimiento (o de cualquier cosa con esos campos), sin repetir.
  def markers(record)
    return [] if record.nil?

    FIELDS.flat_map { |campo| ContactTrackings::Assistant::PendingMarkers.scan(record.try(campo)) }.uniq
  end

  def blocked?(record)
    markers(record).any?
  end

  # «Nombre del negocio, Horario»: lo que va dentro de cada <PENDIENTE: …>.
  def labels(record)
    markers(record).map { |marca| marca[/:\s*([^>]+)>/, 1].to_s.strip.presence || marca }.uniq.join(', ')
  end

  def message(record, key = 'blocked')
    I18n.t("published_prompts.pending_setup.#{key}", labels: labels(record))
  end

  def ensure!(record)
    raise Blocked, message(record) if blocked?(record)
  end
end
