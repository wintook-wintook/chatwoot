# frozen_string_literal: true

# Un «?» con la VARIABLE puesta y el cliente nombrando OTRO valor en su mensaje actual:
# candidato a cambio de valor. El modelo debería escribirlo en su línea VARIABLES, pero no
# siempre lo hace. Medido el 06/11/2026 (cuenta 1128, AGENTE ESCUELA, conv 146): el cliente
# pasó de Bienes Raíces a la Maestría en Administración de Negocios y luego a Derecho,
# CARRERA se quedó en Bienes Raíces y el bot siguió contestando prácticas, precio y la beca
# de Bienes Raíces. La misma pila, en otra corrida, sí cambió (conv 139).
#
# Solo se acepta si la respuesta enviada nombra el valor nuevo y ya no el anterior: así
# «¿y los gastos de administración?» en una conversación de Relaciones Internacionales no
# cambia la carrera a Administración (la respuesta sigue hablando de Relaciones Internacionales).
ContactTrackings::SheetLookup::Switch = Struct.new(:variable, :to, :from, keyword_init: true) do
  def confirmed_by?(reply)
    ContactTrackings::SheetNumbers.names?(reply, to) && from.none? { |valor| ContactTrackings::SheetNumbers.names?(reply, valor) }
  end
end
