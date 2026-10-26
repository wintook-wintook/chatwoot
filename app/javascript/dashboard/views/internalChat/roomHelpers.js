// feat/chat_interno (F3) — cómo se llama y con qué avatar se ve cada sala.
// Un directo se ve con el nombre y la foto del OTRO agente (depende de quién mira).

export const otherMember = (room, meId) =>
  (room.members || []).find(member => member.id !== meId) || null;

export const memberName = member =>
  (member && (member.available_name || member.name)) || '';

export const roomTitle = (room, meId, generalLabel = 'general') => {
  if (!room) return '';
  if (room.kind === 'general') return `# ${generalLabel}`;
  if (room.kind === 'group') return `# ${room.name}`;
  return memberName(otherMember(room, meId));
};
