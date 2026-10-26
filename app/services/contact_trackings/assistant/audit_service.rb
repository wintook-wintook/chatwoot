# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — REVISAR LOS AGENTES YA CARGADOS
# ================================================================================
# Pasa todos los Agentes IA de la cuenta por el comprobador y dice cuáles no están
# ejecutando lo que su nombre promete.
#
# POR QUÉ EXISTE:
#   El comprobador nació para lo que se está escribiendo, pero el problema ya está
#   repartido: hay agentes guardados hace meses, con Entrenamientos que se leen
#   perfecto y que el motor no ejecuta. Como el motor es fail-soft, nadie recibió
#   nunca un error — simplemente contestan peor de lo que deberían.
#
#   Es la misma máquina al revés, y no cuesta nada: el comprobador es una función
#   pura sobre texto, así que revisar 50 agentes son 50 parseos, sin IA y sin red.
#
# LA LENTE DEL AUDITOR NO ES LA DEL AUTOR:
#   Al ESCRIBIR un Entrenamiento con el asistente, "0 ramas" es bloqueante: el
#   asistente está para producir agentes ruteados y si no lo logró, falló.
#   Al REVISAR uno que ya existe, "0 ramas" no es un defecto: es un agente
#   conversacional, un estilo válido y anterior a que las @ruta existieran.
#
#   Medido contra una cuenta real de 28 agentes: con la lente del autor, 21 salían
#   marcados como rotos y solo 8 lo estaban. Un informe que grita por 13 agentes
#   sanos no se vuelve a mirar. Por eso `no_routes` se ignora acá y el estado
#   `conversational` existe como resultado propio, no como un rojo atenuado.
#
# QUÉ NO HACE:
#   No arregla nada ni toca ningún agente. Devuelve el diagnóstico; corregir es
#   una decisión de quien lo lee, y pasa por la misma pantalla y el mismo guardado
#   que un Entrenamiento nuevo.
# ================================================================================

class ContactTrackings::Assistant::AuditService
  def initialize(account)
    @account = account
  end

  # "0 ramas" describe un agente conversacional, no un defecto: se saca de la lista
  # de defectos antes de decidir si el agente está roto. Ver la nota de arriba.
  IGNORED_WHEN_AUDITING = %i[no_routes].freeze

  STATUSES = %i[empty conversational routed broken].freeze

  def call
    @account.tracking_templates.order(:name).map { |template| review(template) }
  end

  private

  def review(template)
    prompt = template.complementary_prompt.to_s
    return summary(template, nil, []) if prompt.blank?

    validation = ContactTrackings::Assistant::ValidatorService.new(prompt, account: @account).call
    defects = validation[:blocking].reject { |f| IGNORED_WHEN_AUDITING.include?(f[:code]) }
    summary(template, validation, defects)
  end

  def summary(template, validation, defects)
    {
      id: template.id,
      name: template.name,
      inbox_id: template.inbox_id,
      status: status_for(validation, defects),
      routes: validation ? validation[:routes].size : 0,
      defects: defects.size,
      degrading: validation ? validation[:degrading].size : 0,
      # El primer defecto alcanza para decidir si vale la pena abrirlo; el detalle
      # completo sale al cargarlo en la pantalla.
      headline: defects.first&.dig(:message)
    }
  end

  def status_for(validation, defects)
    return :empty if validation.nil?
    return :broken if defects.any?

    validation[:routes].any? ? :routed : :conversational
  end
end
