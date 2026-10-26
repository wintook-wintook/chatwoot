// feat/chat_interno (F3) — ESTADO DEL CHAT INTERNO
// ============================================================================
// rooms              las salas del agente (con unread_count y last_message)
// messages[roomId]   los mensajes cargados de cada sala, del más viejo al más nuevo
// activeRoomId       la sala abierta en pantalla: lo que llega ahí no cuenta como sin leer
// Los eventos de tiempo real (helper/actionCable.js) entran por messageCreated,
// roomUpdated y roomRemoved. Plan: docs/chat_interno_plan.md §5
// ============================================================================
import InternalChatAPI from 'dashboard/api/internalChat';

export const sortRooms = rooms =>
  [...rooms].sort((a, b) => {
    if (a.kind === 'general' && b.kind !== 'general') return -1;
    if (b.kind === 'general' && a.kind !== 'general') return 1;
    return (b.last_message_at || 0) - (a.last_message_at || 0);
  });

export const state = {
  rooms: [],
  messages: {},
  hasMore: {},
  activeRoomId: null,
  uiFlags: { loadingRooms: false, loadingMessages: false, sending: false },
};

export const getters = {
  rooms: $state => sortRooms($state.rooms),
  groupRooms: (_, $getters) =>
    $getters.rooms.filter(room => room.kind !== 'direct'),
  directRooms: (_, $getters) =>
    $getters.rooms.filter(room => room.kind === 'direct'),
  roomById: $state => id => $state.rooms.find(room => room.id === Number(id)),
  messagesFor: $state => id => $state.messages[id] || [],
  hasMoreFor: $state => id => !!$state.hasMore[id],
  totalUnread: $state =>
    $state.rooms.reduce((sum, room) => sum + (room.unread_count || 0), 0),
  activeRoomId: $state => $state.activeRoomId,
  uiFlags: $state => $state.uiFlags,
};

export const mutations = {
  SET_FLAG($state, flags) {
    $state.uiFlags = { ...$state.uiFlags, ...flags };
  },
  SET_ROOMS($state, rooms) {
    $state.rooms = rooms;
  },
  // Sala nueva o cambiada: se conservan sus no leídos y su último mensaje.
  UPSERT_ROOM($state, room) {
    const index = $state.rooms.findIndex(item => item.id === room.id);
    if (index === -1) {
      $state.rooms = [...$state.rooms, { unread_count: 0, ...room }];
      return;
    }
    const current = $state.rooms[index];
    const merged = {
      ...current,
      ...room,
      unread_count: current.unread_count,
      last_message: room.last_message || current.last_message,
    };
    $state.rooms = $state.rooms.map(item =>
      item.id === room.id ? merged : item
    );
  },
  REMOVE_ROOM($state, roomId) {
    $state.rooms = $state.rooms.filter(room => room.id !== roomId);
    if ($state.activeRoomId === roomId) $state.activeRoomId = null;
  },
  SET_ACTIVE_ROOM($state, roomId) {
    $state.activeRoomId = roomId;
  },
  SET_UNREAD($state, { roomId, count }) {
    $state.rooms = $state.rooms.map(room =>
      room.id === roomId ? { ...room, unread_count: count } : room
    );
  },
  // older=true: página anterior (va arriba). Nunca se duplica un mensaje.
  ADD_MESSAGES($state, { roomId, messages, older = false }) {
    const current = $state.messages[roomId] || [];
    const known = new Set(current.map(message => message.id));
    const fresh = messages.filter(message => !known.has(message.id));
    $state.messages = {
      ...$state.messages,
      [roomId]: older ? [...fresh, ...current] : [...current, ...fresh],
    };
  },
  SET_HAS_MORE($state, { roomId, hasMore }) {
    $state.hasMore = { ...$state.hasMore, [roomId]: hasMore };
  },
  // Un mensaje nuevo sube la sala y, si no es mío ni está abierta, suma un no leído.
  BUMP_ROOM($state, { message, countAsUnread }) {
    $state.rooms = $state.rooms.map(room => {
      if (room.id !== message.room_id) return room;
      return {
        ...room,
        last_message: message,
        last_message_at: message.created_at,
        unread_count: (room.unread_count || 0) + (countAsUnread ? 1 : 0),
      };
    });
  },
};

export const actions = {
  async fetchRooms({ commit }) {
    commit('SET_FLAG', { loadingRooms: true });
    try {
      const { data } = await InternalChatAPI.getRooms();
      commit('SET_ROOMS', data.payload || []);
    } finally {
      commit('SET_FLAG', { loadingRooms: false });
    }
  },
  async openRoom({ commit, dispatch, state: $state }, roomId) {
    commit('SET_ACTIVE_ROOM', roomId);
    if (!roomId) return;
    if (!$state.messages[roomId]) {
      commit('SET_FLAG', { loadingMessages: true });
      try {
        const { data } = await InternalChatAPI.getMessages(roomId);
        commit('ADD_MESSAGES', { roomId, messages: data.payload || [] });
        commit('SET_HAS_MORE', { roomId, hasMore: data.meta.has_more });
      } finally {
        commit('SET_FLAG', { loadingMessages: false });
      }
    }
    dispatch('markRead', roomId);
  },
  async fetchOlder({ commit, state: $state }, roomId) {
    const first = ($state.messages[roomId] || [])[0];
    if (!first || !$state.hasMore[roomId]) return;
    const { data } = await InternalChatAPI.getMessages(roomId, first.id);
    commit('ADD_MESSAGES', {
      roomId,
      messages: data.payload || [],
      older: true,
    });
    commit('SET_HAS_MORE', { roomId, hasMore: data.meta.has_more });
  },
  markRead({ commit }, roomId) {
    commit('SET_UNREAD', { roomId, count: 0 });
    return InternalChatAPI.markRead(roomId).catch(() => {});
  },
  async sendMessage({ commit }, { roomId, content }) {
    commit('SET_FLAG', { sending: true });
    try {
      const { data } = await InternalChatAPI.sendMessage(roomId, content);
      commit('ADD_MESSAGES', { roomId, messages: [data] });
      commit('BUMP_ROOM', { message: data, countAsUnread: false });
      return data;
    } finally {
      commit('SET_FLAG', { sending: false });
    }
  },
  async openDirect({ commit }, userId) {
    const { data } = await InternalChatAPI.openDirect(userId);
    commit('UPSERT_ROOM', data);
    return data;
  },
  async createGroup({ commit }, { name, userIds }) {
    const { data } = await InternalChatAPI.createGroup(name, userIds);
    commit('UPSERT_ROOM', data);
    return data;
  },
  async rename({ commit }, { roomId, name }) {
    const { data } = await InternalChatAPI.rename(roomId, name);
    commit('UPSERT_ROOM', data);
  },
  async addMembers({ commit }, { roomId, userIds }) {
    const { data } = await InternalChatAPI.addMembers(roomId, userIds);
    commit('UPSERT_ROOM', data);
  },
  async leaveRoom({ commit, rootGetters }, roomId) {
    await InternalChatAPI.removeMember(roomId, rootGetters.getCurrentUserID);
    commit('REMOVE_ROOM', roomId);
  },

  // ── Tiempo real (helper/actionCable.js) ──────────────────────────────────
  messageCreated({ commit, dispatch, state: $state, rootGetters }, message) {
    const mine =
      message.sender && message.sender.id === rootGetters.getCurrentUserID;
    const isOpen = $state.activeRoomId === message.room_id && !document.hidden;
    if ($state.messages[message.room_id]) {
      commit('ADD_MESSAGES', { roomId: message.room_id, messages: [message] });
    }
    const known = $state.rooms.some(room => room.id === message.room_id);
    if (!known) {
      dispatch('fetchRooms');
      return;
    }
    commit('BUMP_ROOM', { message, countAsUnread: !mine && !isOpen });
    if (!mine && isOpen) dispatch('markRead', message.room_id);
  },
  roomUpdated({ commit }, room) {
    commit('UPSERT_ROOM', room);
  },
  roomRemoved({ commit }, roomId) {
    commit('REMOVE_ROOM', roomId);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  mutations,
  actions,
};
