# frozen_string_literal: true

# Asistente (Dali) — las funciones que el modelo puede llamar (formato de OpenAI).
# Lo que hace cada una vive en Assistant::Tools.
module Assistant::ToolDefinitions
  def self.fn(name, description, properties, required = [])
    { type: 'function',
      function: { name: name, description: description,
                  parameters: { type: 'object', properties: properties, required: required } } }
  end

  def self.str(description) = { type: 'string', description: description }
  def self.int(description) = { type: 'integer', description: description }

  BASE = [
    fn('search', 'Busca una palabra en todos los datos de contactos, organizaciones y casos; dice dónde apareció (match).',
       { query: str('Texto a buscar') }, %w[query]),
    fn('get_case', 'Detalle de un caso: datos, qué sigue, último contacto y su actividad reciente.',
       { case_id: int('Id del caso'), folio: str('Folio del caso, p. ej. OPB-00003') }),
    fn('get_contact', 'Detalle de un contacto: datos, organización, casos abiertos, tareas, agenda y conversaciones.',
       { contact_id: int('Id del contacto') }, %w[contact_id]),
    fn('my_agenda', 'Agenda del usuario: tareas agendadas y tareas pendientes entre dos fechas (incluye atrasadas).',
       { from: str('Fecha inicial YYYY-MM-DD'), to: str('Fecha final YYYY-MM-DD') }, %w[from to]),
    fn('open_page', 'Abre una pantalla para el usuario.',
       { target: { type: 'string', enum: Assistant::Pages::MAP.keys },
         id: int('Id del caso/contacto/organización o número de la conversación') }, %w[target]),
    fn('propose_note', 'Propone dejar una nota interna en un caso o en un contacto. Requiere confirmación.',
       { case_id: int('Id del caso'), contact_id: int('Id del contacto (si no hay caso)'), content: str('Texto') },
       %w[content]),
    fn('propose_task', 'Propone crear una tarea (con caso, o con contacto/organización). Requiere confirmación.',
       { title: str('Título corto'), description: str('Detalle'), due_at: str('Día en que vence, YYYY-MM-DD (sin hora: vence al final del día)'),
         case_id: int('Id del caso'), contact_id: int('Id del contacto'), organization_id: int('Id de la organización'),
         assignee_id: int('Id del usuario responsable (omitir = el usuario)') }, %w[title]),
    fn('propose_meeting', 'Propone agendar una tarea con hora (llamada, reunión, visita) en el calendario. Requiere confirmación.',
       { title: str('Título'), starts_at: str('Inicio, hora local YYYY-MM-DDTHH:MM'),
         duration_minutes: int('Duración en minutos (default 30)'), description: str('Detalle'),
         location: str('Lugar'), is_visit: { type: 'boolean', description: 'Es una visita en sitio' },
         case_id: int('Id del caso'), contact_id: int('Id del contacto'), organization_id: int('Id de la organización') },
       %w[title starts_at]),
    fn('propose_scheduled_message', 'Propone programar un mensaje al cliente en una conversación. Requiere confirmación.',
       { conversation_id: int('Número (display id) de la conversación'), content: str('Texto del mensaje'),
         send_at: str('Envío, hora local YYYY-MM-DDTHH:MM') }, %w[conversation_id content send_at]),
    fn('list_agents', 'Agentes IA de seguimiento que se pueden usar con la conversación del cliente (o del caso).',
       { case_id: int('Id del caso'), contact_id: int('Id del contacto'), conversation_id: int('Número de la conversación') }),
    fn('tracking_status', 'Cómo van los seguimientos con agente IA de un cliente: estado, intentos, próximo intento y resultado.',
       { case_id: int('Id del caso'), contact_id: int('Id del contacto') }),
    fn('propose_delegate', 'Propone delegar el seguimiento del cliente a un agente IA (crear el seguimiento). Requiere confirmación. ' \
                           'Antes usa list_agents para elegir el agente.',
       { agent_id: int('Id del agente (de list_agents)'), case_id: int('Id del caso'), contact_id: int('Id del contacto'),
         conversation_id: int('Número de la conversación (omitir = la del caso o la más reciente)'),
         objective: str('Objetivo concreto, p. ej. «que envíe la orden de compra»'),
         instruction: str('Instrucción extra para el agente en este seguimiento'),
         starts_at: str('Primer intento, hora local YYYY-MM-DDTHH:MM (omitir = en unos minutos)'),
         max_attempts: int('Intentos (1 a 10)'), interval_value: int('Cada cuánto (número)'),
         interval_unit: { type: 'string', enum: %w[minutes hours days] } }, %w[agent_id]),
    fn('propose_follow_up_action', "Propone pausar, reanudar o cancelar un #{AiFollowUp::DISPLAY_NAME}. Requiere confirmación.",
       { follow_up_id: int('Id del Seguimiento IA (de tracking_status, ai_follow_ups)'),
         action: { type: 'string', enum: %w[pause resume cancel] } }, %w[follow_up_id action]),
    fn('propose_tracking_action', 'Propone pausar, reanudar o cancelar un seguimiento con agente IA. Requiere confirmación.',
       { tracking_id: int('Id del seguimiento (de tracking_status)'),
         action: { type: 'string', enum: %w[pause resume cancel] } }, %w[tracking_id action]),
    fn('list_case_types', 'Tipos de caso que el usuario puede crear (soporte, oportunidad, orden, proyecto…).', {}),
    fn('case_options', 'Etapas de un caso (y en cuál está) y motivos para ganar, perder, cancelar o posponer.',
       { case_id: int('Id del caso') }, %w[case_id]),
    fn('propose_create_case', 'Propone crear un caso u oportunidad para un contacto. Requiere confirmación. Antes list_case_types.',
       { case_type_id: int('Id del tipo'), contact_id: int('Id del contacto'), title: str('Título'),
         description: str('Descripción'), amount: { type: 'number', description: 'Monto (oportunidades)' },
         currency: str('Moneda, p. ej. MXN'), expected_close_at: str('Cierre estimado YYYY-MM-DD') },
       %w[case_type_id contact_id title]),
    fn('propose_move_stage', 'Propone pasar un caso a otra etapa (no de resultado). Requiere confirmación. Antes case_options.',
       { case_id: int('Id del caso'), column_id: int('Id de la etapa') }, %w[case_id column_id]),
    fn('propose_outcome', 'Propone cerrar una oportunidad como ganada, perdida o cancelada. Requiere confirmación.',
       { case_id: int('Id del caso'), outcome: { type: 'string', enum: %w[won lost cancelled] },
         reason_id: int('Id del motivo (de case_options)'), note: str('Nota'),
         pending_tasks: { type: 'string', enum: %w[keep cancel],
                          description: 'Tareas pendientes: keep (default) o cancel solo si el usuario lo pidió' } },
       %w[case_id outcome]),
    fn('propose_postpone', 'Propone posponer una oportunidad hasta una fecha. Requiere confirmación.',
       { case_id: int('Id del caso'), until: str('Fecha YYYY-MM-DD'), reason_id: int('Id del motivo'), reason: str('Motivo') },
       %w[case_id until]),
    fn('propose_resume_case', 'Propone retomar una oportunidad pospuesta. Requiere confirmación.',
       { case_id: int('Id del caso') }, %w[case_id]),
    fn('propose_update_opportunity', 'Propone cambiar monto, moneda, cierre estimado, probabilidad o el compromiso del cliente. ' \
                                     'Requiere confirmación.',
       { case_id: int('Id del caso'), amount: { type: 'number' }, currency: str('Moneda'),
         expected_close_at: str('Cierre estimado o fecha prometida YYYY-MM-DD'), probability: int('0 a 100'),
         committed: { type: 'boolean', description: 'El cliente se comprometió' }, commit_note: str('Nota del compromiso') },
       %w[case_id]),
    fn('propose_create_contact', 'Propone dar de alta un contacto. Requiere confirmación.',
       { name: str('Nombre'), email: str('Correo'), phone: str('Teléfono con lada, p. ej. +5215512345678'),
         organization_id: int('Id de la organización') }, %w[name]),
    fn('propose_draft', 'Redacta un borrador de mensaje para que el usuario lo copie. No envía nada.',
       { conversation_id: int('Número de la conversación, si aplica'), content: str('Texto del borrador') }, %w[content])
  ].freeze

  EXTRA = %w[Sales Guide Quote Conversation Field Event ClientTask Cancel Convert FollowUp Progress].freeze # Assistant::<X>ToolDefinitions::ALL

  # Al primer uso, no al cargar: los <X>ToolDefinitions usan D.fn de aquí (carga circular en eager load).
  def self.all = @all ||= (BASE + EXTRA.flat_map { |x| "Assistant::#{x}ToolDefinitions".constantize::ALL }).freeze
end
