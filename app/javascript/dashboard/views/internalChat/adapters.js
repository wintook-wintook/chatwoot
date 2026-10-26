// feat/chat_interno — SALAS Y MENSAJES CON LA FORMA DE CONVERSACIÓN DE CHATWOOT
// ============================================================================
// Para pintarlos con los componentes reales (ConversationCard y Message) en vez de copias.
// La dirección depende de quién mira: lo mío sale como enviado (derecha) y lo de otros
// como recibido (izquierda), igual que en una conversación con un cliente.
// Los ids van en negativo para no confundirse nunca con una conversación real.
// ============================================================================
import { memberName, otherMember, roomTitle } from './roomHelpers';

const INCOMING = 0;
const OUTGOING = 1;

export const toMessage = (message, meId, room) => {
  const sender = message.sender || {};
  const mine = sender.id === meId;
  return {
    id: message.id,
    content: message.deleted ? '' : message.content,
    message_type: mine ? OUTGOING : INCOMING,
    created_at: message.created_at,
    private: false,
    status: 'sent',
    attachments: [],
    content_attributes: message.deleted ? { deleted: true } : {},
    conversation_id: -room.id,
    sender: {
      id: sender.id,
      name: memberName(sender),
      thumbnail: sender.avatar_url,
      type: 'user',
    },
  };
};

// La vista previa de la tarjeta: en salas de varias personas, «Ana: …».
const previewMessage = (room, meId) => {
  const last = room.last_message;
  if (!last) return null;
  const message = toMessage(last, meId, room);
  const mine = message.message_type === OUTGOING;
  if (room.kind !== 'direct' && !mine && message.content) {
    message.content = `${message.sender.name}: ${message.content}`;
  }
  return message;
};

export const toChat = (room, meId, generalLabel) => {
  const last = previewMessage(room, meId);
  const timestamp = room.last_message_at || 0;
  return {
    id: -room.id,
    inbox_id: null,
    status: 'open',
    priority: null,
    labels: [],
    unread_count: room.unread_count || 0,
    timestamp,
    created_at: timestamp,
    messages: last ? [last] : [],
    last_non_activity_message: last,
    meta: { sender: { id: null }, assignee: {} },
    room_title: roomTitle(room, meId, generalLabel),
  };
};

// Lo que la tarjeta y el encabezado muestran como «contacto»: el otro agente en un
// directo; el nombre de la sala (# general, # equipo) en las demás.
export const roomContact = (room, meId, generalLabel) => {
  if (room.kind === 'direct') {
    const other = otherMember(room, meId) || {};
    return {
      name: memberName(other),
      thumbnail: other.avatar_url,
      availability_status: other.availability_status,
    };
  }
  return { name: roomTitle(room, meId, generalLabel), thumbnail: '' };
};
