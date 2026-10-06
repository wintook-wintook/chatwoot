# frozen_string_literal: true

# proyecto@asistente_agentes_ia — una conversación del Asistente como la ve la pantalla.
# Vive aparte del controlador porque también la arma InterviewTurn, que corre en
# Sidekiq (InterviewJob), donde no hay Current.user: quien pregunta viaja explícito.
module ContactTrackings::Assistant::SessionPresenter
  # Al retomar una conversación se devuelve además su identidad —id, estado,
  # cuándo se creó, de qué Agente IA salió—, no solo su contenido: la pantalla del
  # Asistente mostraba el hilo y el borrador sin decir en CUÁL de las
  # conversaciones estabas trabajando. Con doce en el listado, eso es un problema
  # real: se retoma una, se la confunde con otra, y se guarda encima del agente
  # equivocado.
  def self.full(sesion, user)
    {
      id: sesion.id, messages: sesion.messages, draft: sesion.draft, instructions: sesion.instructions,
      creator: sesion.user&.available_name || sesion.user&.name,
      mine: sesion.user_id == user.id,
      validation: sesion.validation.presence, proposal: sesion.proposal.presence,
      tracking_template_id: sesion.tracking_template_id,
      status: sesion.status,
      # De qué se trataba: el primer mensaje de la persona. Es lo que el card de
      # referencia muestra arriba de la conversación.
      title: sesion.title, named: sesion.name.present?,
      template_name: sesion.tracking_template&.name,
      created_at: sesion.created_at,
      updated_at: sesion.updated_at
    }
  end
end
