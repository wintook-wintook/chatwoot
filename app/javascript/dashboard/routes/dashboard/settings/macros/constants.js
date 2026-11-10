export const MACRO_ACTION_TYPES = [
  {
    key: 'assign_team',
    label: 'Asignar un equipo',
    inputType: 'search_select',
  },
  {
    key: 'assign_agent',
    label: 'Asignar un agente',
    inputType: 'search_select',
  },
  {
    key: 'add_label',
    label: 'Agregar una etiqueta',
    inputType: 'multi_select',
  },
  {
    key: 'remove_label',
    label: 'Quitar una etiqueta',
    inputType: 'multi_select',
  },
  {
    key: 'remove_assigned_team',
    label: 'Quitar el equipo asignado',
    inputType: null,
  },
  {
    key: 'send_email_transcript',
    label: 'Enviar la transcripción por correo',
    inputType: 'email',
  },
  {
    key: 'mute_conversation',
    label: 'Silenciar la conversación',
    inputType: null,
  },
  {
    key: 'snooze_conversation',
    label: 'Posponer la conversación',
    inputType: null,
  },
  {
    key: 'resolve_conversation',
    label: 'Resolver la conversación',
    inputType: null,
  },
  {
    key: 'send_webhook_event',
    label: 'Enviar evento de webhook',
    inputType: 'url',
  },
  {
    key: 'send_attachment',
    label: 'Enviar un archivo adjunto',
    inputType: 'attachment',
  },
  {
    key: 'send_message',
    label: 'Enviar un mensaje',
    inputType: 'textarea',
  },
  {
    key: 'add_private_note',
    label: 'Agregar una nota privada',
    inputType: 'textarea',
  },
  {
    key: 'change_priority',
    label: 'Cambiar la prioridad',
    inputType: 'search_select',
  },
];
