# frozen_string_literal: true

# Las etiquetas de cómo catalogó la IA la plática, para «Atención a prospectos» y «Vendedor de campaña» (las de
# «Atención a clientes» las pone Motor2::Skills::SupportLabels). Van a la conversación (Motor2::Labels) y al chat
# de prueba. Salen de lo que hizo en el turno (las herramientas que funcionaron).
class Motor2::Skills::Tags < Motor2::Skills::Base
  FUNCTIONS = %w[prospects campaign_seller].freeze
  COMMON = { 'pasar_a_humano' => 'canalizada', 'agendar_cita' => 'cita', 'mover_cita' => 'cita-movida',
             'cancelar_cita' => 'cita-cancelada', 'recomendar' => 'recomendado', 'cotizar' => 'cotizacion' }.freeze
  BY_FUNCTION = {
    'prospects' => { 'prospecto_calificado' => 'calificado', 'descartar' => 'descartado' },
    'campaign_seller' => { 'le_interesa' => 'le-interesa', 'no_le_interesa' => 'no-le-interesa',
                           'confirmar_asistencia' => 'confirmo-asistencia', 'guardar_respuesta' => 'encuesta' }
  }.freeze

  def self.key = 'tags'

  def on? = FUNCTIONS.include?(config.function&.key)

  def labels
    map = COMMON.merge(BY_FUNCTION[config.function.key].to_h)
    trace.tools.select { |t| t['ok'] }.filter_map { |t| map[t['name']] }.uniq
  end
end
