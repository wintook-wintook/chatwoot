import { getters, mutations, actions, sortRooms } from '../internalChat';

const room = (id, extra = {}) => ({
  id,
  kind: 'group',
  unread_count: 0,
  last_message_at: 0,
  ...extra,
});
const message = (id, roomId, senderId = 2) => ({
  id,
  room_id: roomId,
  content: `m${id}`,
  created_at: 100 + id,
  sender: { id: senderId },
});
const freshState = () => ({
  rooms: [],
  messages: {},
  hasMore: {},
  activeRoomId: null,
  uiFlags: {},
});

describe('internalChat store', () => {
  describe('sortRooms', () => {
    it('keeps general first and then the most recent', () => {
      const sorted = sortRooms([
        room(1, { last_message_at: 5 }),
        room(2, { kind: 'general', last_message_at: 1 }),
        room(3, { last_message_at: 9 }),
      ]);
      expect(sorted.map(r => r.id)).toEqual([2, 3, 1]);
    });
  });

  describe('getters', () => {
    it('splits groups (with general) from directs and sums unread', () => {
      const $state = {
        ...freshState(),
        rooms: [
          room(1, { kind: 'general', unread_count: 2 }),
          room(2, { kind: 'direct', unread_count: 1 }),
          room(3, { unread_count: 0 }),
        ],
      };
      const local = { rooms: getters.rooms($state) };
      expect(getters.groupRooms($state, local).map(r => r.id)).toEqual([1, 3]);
      expect(getters.directRooms($state, local).map(r => r.id)).toEqual([2]);
      expect(getters.totalUnread($state)).toBe(3);
    });
  });

  describe('mutations', () => {
    it('ADD_MESSAGES never duplicates and puts older pages on top', () => {
      const $state = freshState();
      mutations.ADD_MESSAGES($state, { roomId: 1, messages: [message(5, 1)] });
      mutations.ADD_MESSAGES($state, {
        roomId: 1,
        messages: [message(5, 1), message(6, 1)],
      });
      mutations.ADD_MESSAGES($state, {
        roomId: 1,
        messages: [message(3, 1)],
        older: true,
      });
      expect($state.messages[1].map(m => m.id)).toEqual([3, 5, 6]);
    });

    it('UPSERT_ROOM keeps unread count and last message of a known room', () => {
      const $state = {
        ...freshState(),
        rooms: [room(1, { unread_count: 4, last_message: message(9, 1) })],
      };
      mutations.UPSERT_ROOM(
        $state,
        room(1, { name: 'nuevo', unread_count: 0 })
      );
      expect($state.rooms[0]).toMatchObject({ name: 'nuevo', unread_count: 4 });
      expect($state.rooms[0].last_message.id).toBe(9);
      mutations.UPSERT_ROOM($state, room(2));
      expect($state.rooms).toHaveLength(2);
    });

    it('REMOVE_ROOM closes it if it was open', () => {
      const $state = { ...freshState(), rooms: [room(1)], activeRoomId: 1 };
      mutations.REMOVE_ROOM($state, 1);
      expect($state.rooms).toEqual([]);
      expect($state.activeRoomId).toBeNull();
    });
  });

  describe('messageCreated', () => {
    const run = ($state, msg, currentUserId = 1) => {
      const commit = (type, payload) => mutations[type]($state, payload);
      const dispatch = vi.fn();
      actions.messageCreated(
        {
          commit,
          dispatch,
          state: $state,
          rootGetters: { getCurrentUserID: currentUserId },
        },
        msg
      );
      return dispatch;
    };

    it('counts a message from someone else in a closed room as unread', () => {
      const $state = { ...freshState(), rooms: [room(1)] };
      run($state, message(1, 1, 2));
      expect($state.rooms[0].unread_count).toBe(1);
      expect($state.rooms[0].last_message_at).toBe(101);
    });

    it('does not count my own messages', () => {
      const $state = { ...freshState(), rooms: [room(1)] };
      run($state, message(1, 1, 1));
      expect($state.rooms[0].unread_count).toBe(0);
    });

    it('marks as read when the room is open on screen', () => {
      const $state = {
        ...freshState(),
        rooms: [room(1)],
        activeRoomId: 1,
        messages: { 1: [] },
      };
      const dispatch = run($state, message(1, 1, 2));
      expect($state.rooms[0].unread_count).toBe(0);
      expect($state.messages[1]).toHaveLength(1);
      expect(dispatch).toHaveBeenCalledWith('markRead', 1);
    });

    it('reloads the room list when the message is for an unknown room', () => {
      const $state = freshState();
      const dispatch = run($state, message(1, 7, 2));
      expect(dispatch).toHaveBeenCalledWith('fetchRooms');
    });
  });
});
