# frozen_string_literal: true

# Motor 2.0 — lo que el código recuerda de cada cliente (contact_trackings.motor2_state).
# El modelo no lo escribe a mano: lo mueven las habilidades (guardar_dato, siguiente_oferta…).
# En el chat de prueba vive solo en memoria y regresa a la pantalla.
#
#   { 'data' => { 'carrera' => 'Derecho' }, 'offer_step' => 1, 'welcome_sent' => true,
#     'files_sent' => [3, 7], 'case_id' => 12, 'appointment' => { 'id' => 5, 'at' => '…' } }
class Motor2::State
  attr_reader :values

  def initialize(values = {})
    @values = values.to_h.deep_stringify_keys
  end

  def [](key) = @values[key.to_s]

  def dig(*keys) = @values.dig(*keys.map(&:to_s))

  def []=(key, value)
    @values[key.to_s] = value
  end

  def data = (@values['data'] ||= {})

  def files_sent = (@values['files_sent'] ||= [])

  def to_h = @values
end
