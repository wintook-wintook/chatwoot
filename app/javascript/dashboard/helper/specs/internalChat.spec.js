import {
  internalDisplay,
  isInternalChat,
  otherAgentId,
  viewerMessageType,
} from '../internalChat';

const chat = (kind, extra = {}) => ({
  id: 1,
  additional_attributes: { internal: { kind, ...extra } },
});
const agents = [
  { id: 1, name: 'Ana', thumbnail: 'a.png', availability_status: 'online' },
  { id: 2, name: 'Luis', available_name: 'Luis P.', thumbnail: 'l.png' },
];

describe('internalChat helper', () => {
  it('knows which conversations are internal', () => {
    expect(isInternalChat(chat('general'))).toBe(true);
    expect(isInternalChat({ id: 1, additional_attributes: {} })).toBe(false);
    expect(isInternalChat(null)).toBe(false);
  });

  it('finds the other agent of a direct', () => {
    const direct = chat('direct', { key: 'direct:1:2' });
    expect(otherAgentId(direct, 1)).toBe(2);
    expect(otherAgentId(direct, 2)).toBe(1);
    expect(otherAgentId(chat('general'), 1)).toBeNull();
  });

  it('shows the room name or the other agent depending on who looks', () => {
    const options = {
      currentUserId: 1,
      agents,
      teams: [{ id: 7, name: 'ventas' }],
    };
    expect(internalDisplay(chat('general'), options).name).toBe('# general');
    expect(internalDisplay(chat('team', { team_id: 7 }), options).name).toBe(
      '# ventas'
    );
    expect(
      internalDisplay(chat('direct', { key: 'direct:1:2' }), options)
    ).toMatchObject({
      name: 'Luis P.',
      thumbnail: 'l.png',
    });
    expect(internalDisplay({ id: 1 }, options)).toBeNull();
  });

  it('puts the other agents on the left only in internal conversations', () => {
    const fromLuis = { message_type: 1, sender: { id: 2 } };
    const mine = { message_type: 1, sender: { id: 1 } };
    expect(
      viewerMessageType(fromLuis, { internal: true, currentUserId: 1 })
    ).toBe(0);
    expect(viewerMessageType(mine, { internal: true, currentUserId: 1 })).toBe(
      1
    );
    expect(
      viewerMessageType(fromLuis, { internal: false, currentUserId: 1 })
    ).toBe(1);
    expect(
      viewerMessageType(
        { message_type: 2 },
        { internal: true, currentUserId: 1 }
      )
    ).toBe(2);
  });
});
