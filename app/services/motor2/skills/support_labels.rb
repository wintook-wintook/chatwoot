# frozen_string_literal: true

# «Atención a clientes» — las etiquetas con las que la IA catalogó cada mensaje (van a la conversación:
# Motor2::Labels; y al chat de prueba), para que el equipo vea qué pidió el cliente y qué se hizo:
#   qué pidió:  soporte-duda | soporte-falla | soporte-critico | informacion | cotizacion | demo | visita | cita |
#               vendedor | contratar | comercial | administrativo | otra-area | humano
#   qué se hizo: respondida | info-relacionada | sin-respuesta | caso-levantado | canalizada |
#               gestion-registrada | cita-agendada | resuelto
# Lo usa Motor2::Skills::Areas (por Motor2::Skills::SupportFlow).
module Motor2::Skills::SupportLabels
  SALES_LABELS = { 'info' => 'informacion', 'cotizacion' => 'cotizacion', 'demo' => 'demo', 'visita' => 'visita', 'cita' => 'cita',
                   'vendedor' => 'vendedor', 'contratar' => 'contratar', 'otra' => 'comercial' }.freeze
  SUPPORT_LABELS = { 1 => 'soporte-critico', 2 => 'soporte-falla' }.freeze
  MATCH_LABELS = { 'exacta' => 'respondida', 'relacionada' => 'info-relacionada', 'ninguna' => 'sin-respuesta' }.freeze
  TOOL_LABELS = { 'crear_caso' => 'caso-levantado', 'canalizar' => 'canalizada', 'pasar_a_humano' => 'canalizada',
                  'registrar_gestion' => 'gestion-registrada', 'agendar_cita' => 'cita-agendada',
                  'cotizar' => 'cotizacion' }.freeze

  # Qué pidió y qué se hizo en este mensaje.
  def labels
    list = [@resolved ? 'resuelto' : type_label, ('humano' if human?)]
    list.concat(trace.tools.select { |t| t['ok'] }.filter_map { |t| TOOL_LABELS[t['name']] })
    list << MATCH_LABELS[@match['tipo']] if @match && !@resolved
    list.compact.uniq
  end

  private

  def type_label
    case area_key
    when 'support' then SUPPORT_LABELS[now['severidad'].to_i] || 'soporte-duda'
    when 'sales' then SALES_LABELS[now['gestion'].to_s] || 'informacion'
    when 'admin' then 'administrativo'
    when 'other' then 'otra-area'
    end
  end
end
