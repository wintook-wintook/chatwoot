// feat/chat_interno (plan v2, R4) — CONVERSACIONES DE LA BANDEJA «INTERNO»
// ============================================================================
// Todas las conversaciones internas tienen el mismo contacto oculto («Chat interno») y
// todos sus mensajes son de agentes (salientes). Lo que cambia según quién mira:
//   · el nombre y la foto: # general, # el equipo, o el OTRO agente en un directo
//   · la dirección: lo mío a la derecha, lo de los demás a la izquierda
// El tipo de sala viene en additional_attributes.internal = { kind, key, team_id }.
// ============================================================================

const OUTGOING = 1;
const INCOMING = 0;

export const internalInfo = chat =>
  (chat && chat.additional_attributes && chat.additional_attributes.internal) ||
  null;

export const isInternalChat = chat => Boolean(internalInfo(chat));

// En un directo la llave es «direct:<id>:<id>»: el otro es el que no soy yo.
export const otherAgentId = (chat, currentUserId) => {
  const info = internalInfo(chat);
  if (!info || info.kind !== 'direct') return null;
  const ids = String(info.key || '')
    .split(':')
    .slice(1)
    .map(Number);
  return ids.find(id => id !== currentUserId) || null;
};

// Lo que la tarjeta y el encabezado muestran en lugar del contacto oculto.
export const internalDisplay = (
  chat,
  { currentUserId, agents = [], teams = [], generalLabel = 'general' }
) => {
  const info = internalInfo(chat);
  if (!info) return null;
  if (info.kind === 'general') return { name: `# ${generalLabel}` };
  if (info.kind === 'team') {
    const team = teams.find(item => item.id === info.team_id);
    return { name: `# ${team ? team.name : ''}` };
  }
  const agent = agents.find(
    item => item.id === otherAgentId(chat, currentUserId)
  );
  if (!agent) return { name: '' };
  return {
    id: agent.id,
    name: agent.available_name || agent.name,
    thumbnail: agent.thumbnail,
    availability_status: agent.availability_status,
  };
};

// Mensaje de otro agente en «Interno»: se pinta como recibido (izquierda).
export const viewerMessageType = (message, { internal, currentUserId }) => {
  const type = message.message_type;
  if (!internal || type !== OUTGOING) return type;
  const sender = message.sender || {};
  return sender.id === currentUserId ? OUTGOING : INCOMING;
};
