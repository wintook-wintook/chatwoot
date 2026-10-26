# frozen_string_literal: true

# ================================================================================
# proyecto@asistente_agentes_ia — LO QUE EL MOTOR NO VA A CUMPLIR (M6 de docs/importar_prompt_extenso_plan.md)
# ================================================================================
# Hay reglas del encargo que ningún Entrenamiento puede cumplir, porque el motor hace algo
# por su cuenta. Con ADAM (28–29/09/2026) salieron en la pila en vivo, no antes:
#
#   · avisos fijos en tú («Tu caso fue registrado…», los horarios, el correo de la cita)
#     aunque el agente trate de usted;
#   · la #etiqueta de la ruta se pega al final del mensaje, después de la pregunta de cierre;
#   · el correo que da el cliente solo se guarda en el contacto al agendar una cita;
#   · el horario de atención y la ventana de días se configuran en el calendario;
#   · los seguimientos automáticos se configuran en la ficha del agente.
#
# Tabla fija (código, no IA) cruzada con las reglas de la ficha: si una regla habla de eso,
# se avisa, con las reglas (id) que afecta. No bloquea nada: lo ve la persona en el modal.
# ================================================================================

module ContactTrackings::Assistant::EngineLimits
  LIMITS = [
    { 'clave' => 'usted', 're' => /\busted\b/i,
      'aviso' => 'Los avisos fijos del motor (caso registrado, horarios, correo de la cita) hablan de tú.' },
    { 'clave' => 'cierre_pregunta', 're' => /(cierra|termina|termine|cierre)[^.]{0,40}pregunta/i,
      'aviso' => 'La #etiqueta de la ruta se agrega al final del mensaje, después de la pregunta de cierre.' },
    { 'clave' => 'correo', 're' => /\bcorreo\b|\bemail\b/i,
      'aviso' => 'El correo que da el cliente solo se guarda en el contacto cuando agenda una cita.' },
    { 'clave' => 'horario', 're' => /\b\d{1,2}:\d{2}\b|\b\d{2,3}\s*horas\b|horario de atenci/i,
      'aviso' => 'El horario que se ofrece y cuántos días hacia adelante se configuran en el calendario, no en el prompt.' },
    { 'clave' => 'seguimiento', 're' => /seguimiento|recordatorio|contactos? de seguimiento/i,
      'aviso' => 'Los mensajes de seguimiento automáticos se configuran en la ficha del agente (intervalo), no en el prompt.' }
  ].freeze
  MAX_EXAMPLES = 3

  module_function

  # [{ 'clave', 'aviso', 'cuantas', 'ejemplos' => [id o texto corto] }] para las reglas que chocan.
  def call(ficha)
    reglas = %w[reglas prohibiciones tono].flat_map { |campo| Array(ficha[campo]) }
    LIMITS.filter_map do |limite|
      afectadas = reglas.select { |r| r['texto'].to_s.match?(limite['re']) }
      next if afectadas.empty?

      { 'clave' => limite['clave'], 'aviso' => limite['aviso'], 'cuantas' => afectadas.size,
        'ejemplos' => afectadas.first(MAX_EXAMPLES).map { |r| label(r) } }
    end
  end

  # La id de la regla si la tiene; si no, el comienzo de su texto.
  def label(regla) = Array(regla['ids']).first || regla['regla_id'] || regla['texto'].to_s.truncate(80)
end
