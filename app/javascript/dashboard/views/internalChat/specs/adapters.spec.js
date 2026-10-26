import { roomContact, toChat, toMessage } from '../adapters';

const ana = {
  id: 1,
  name: 'Ana',
  avatar_url: 'a.png',
  availability_status: 'online',
};
const luis = { id: 2, name: 'Luis', avatar_url: 'l.png' };
const msg = (id, sender, extra = {}) => ({
  id,
  room_id: 9,
  content: 'hola',
  created_at: 100,
  sender,
  deleted: false,
  ...extra,
});

describe('internal chat adapters', () => {
  it('shows my messages as sent and the others as received', () => {
    const room = { id: 9, kind: 'team' };
    expect(toMessage(msg(1, ana), 1, room).message_type).toBe(1);
    expect(toMessage(msg(2, luis), 1, room).message_type).toBe(0);
    expect(toMessage(msg(2, luis), 1, room).sender).toMatchObject({
      name: 'Luis',
      thumbnail: 'l.png',
      type: 'user',
    });
  });

  it('marks deleted messages the way the bubble expects', () => {
    const message = toMessage(msg(3, luis, { deleted: true }), 1, { id: 9 });
    expect(message.content_attributes).toEqual({ deleted: true });
    expect(message.content).toBe('');
  });

  it('builds a chat with a negative id, unread count and a named preview', () => {
    const room = {
      id: 9,
      kind: 'team',
      name: 'ventas',
      unread_count: 3,
      last_message_at: 200,
      last_message: msg(5, luis),
    };
    const chat = toChat(room, 1, 'general');
    expect(chat.id).toBe(-9);
    expect(chat.unread_count).toBe(3);
    expect(chat.timestamp).toBe(200);
    expect(chat.last_non_activity_message.content).toBe('Luis: hola');
  });

  it('does not prefix the name in a direct chat', () => {
    const room = {
      id: 4,
      kind: 'direct',
      members: [ana, luis],
      last_message: msg(6, luis),
    };
    expect(toChat(room, 1).last_non_activity_message.content).toBe('hola');
  });

  it('uses the other agent as contact in a direct and the room name otherwise', () => {
    const direct = { id: 4, kind: 'direct', members: [ana, luis] };
    expect(roomContact(direct, 1)).toMatchObject({
      name: 'Luis',
      thumbnail: 'l.png',
    });
    expect(roomContact({ id: 1, kind: 'general' }, 1, 'general').name).toBe(
      '# general'
    );
  });
});
