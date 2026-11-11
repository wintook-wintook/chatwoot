# frozen_string_literal: true

# Un «carrera=?» de {{hoja_buscar:}} toma primero la VARIABLE del Agente IA con el mismo
# nombre que la columna (CARRERA), no solo lo que se dijo en los últimos mensajes.
#
# Medido el 04/11/2026 (cuenta 1128, AGENTE ESCUELA): solo con los mensajes, «¿gastos de
# administración?» traía la fila de Administración en una conversación de Relaciones
# Internacionales, y pasados 6 mensajes sin nombrar la carrera el bot la volvía a preguntar
# aunque CARRERA ya la tenía.
module ContactTrackings::SheetLookup::VariableValues
  private

  # Lo que nombró el cliente gana sobre lo que ofreció el agente; con la variable puesta,
  # ver with_variable; con la variable declarada y en VACÍO, ver current_turn_values.
  def conversation_values(column, known)
    return current_turn_values(known) if variable_empty?(column)

    cliente, agente = recent_messages.partition(&:incoming?)
    del_cliente = first_mention(cliente, known)
    with_variable(column, known, del_cliente) || del_cliente || first_mention(agente, known) || []
  end

  # Con la variable puesta van las dos: la de la variable y la que el cliente nombró en sus
  # últimos mensajes, si es otra. Cada fila llega con su carrera y el prompt decide (CARRERA
  # manda salvo que el cliente cambie de carrera). Sin variable, lo de siempre.
  def with_variable(column, known, del_cliente)
    de_variable = variable_values(column, known)
    return if de_variable.empty?

    note_switch(column, known, de_variable)
    (de_variable + del_cliente.to_a).uniq
  end

  # Un solo valor nuevo en el turno actual del cliente: candidato a cambio (ver Switch).
  def note_switch(column, known, de_variable)
    nuevos = current_turn_values(known) - de_variable
    return unless nuevos.one?

    variable = ContactTrackings::ConversationVariables.key(column)
    @switch = ContactTrackings::SheetLookup::Switch.new(variable: variable, to: nuevos.first, from: de_variable)
  end

  # El Agente declara la variable (CARRERA=VACÍO|valor) y sigue en VACÍO: nadie eligió todavía.
  def variable_empty?(column)
    clave = ContactTrackings::ConversationVariables.key(column)
    @variables.key?(clave) && ContactTrackings::ConversationVariables.key(@variables[clave]).in?(['VACIO', ''])
  end

  # Sin elección, vale solo lo que el cliente escribió en su turno actual (sus mensajes desde
  # la última respuesta). Lo de antes ya pasó sin que la variable se llenara, y lo que escribió
  # el agente (el catálogo con todas las carreras, el PDF de una) no es una elección. Sin
  # mención ahí: :needs_value y el bot pregunta. Medido el 05/11/2026 (cuenta 1128, conv 120):
  # «Tampoco gastos de Administración» dejaba la carrera Administración en los últimos 6
  # mensajes y el plan de estudios siguiente salió de Administración sin que el cliente la
  # eligiera; en producción (cuenta 613, conv 59) el PDF de RI que mandó el bot hizo lo mismo.
  def current_turn_values(known)
    first_mention(recent_messages.take_while(&:incoming?), known) || []
  end

  # Los valores de la columna que nombra la variable. «Licenciatura en Ciencias de la
  # Educación» nombra también «Educación»: se queda el más largo.
  def variable_values(column, known)
    valor = @variables[ContactTrackings::ConversationVariables.key(column)].to_s
    return [] if valor.blank? || ContactTrackings::ConversationVariables.key(valor) == 'VACIO'

    found = known.select { |value| mentions?(valor, value) }
    found.reject { |value| found.any? { |otro| otro != value && mentions?(otro, value) } }
  end
end
