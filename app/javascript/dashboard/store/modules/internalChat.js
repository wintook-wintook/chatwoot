// feat/chat_interno_pulido — LO QUE EL MENÚ NECESITA DE «INTERNO»
// ============================================================================
// · inboxId: la bandeja «Interno» de la cuenta (la entrada «Chat interno» del menú).
// · unread: lo que el agente tiene sin leer en todas sus salas (el contador del menú).
//   Lo cuenta el servidor (no leídos por agente); se vuelve a pedir cuando llega un
//   mensaje de otro agente o cuando el agente abre una sala.
// · Sonido: si llega un mensaje de otro agente y esa sala no está a la vista.
// ============================================================================
import InternalChannelAPI from 'dashboard/api/internalChannel';

const REFRESH_DELAY = 800; // junta varios mensajes seguidos en una sola consulta
let refreshTimer = null;

export const state = {
  inboxId: null,
  unread: 0,
};

export const getters = {
  getInboxId: $state => $state.inboxId,
  getUnread: $state => $state.unread,
};

export const actions = {
  // La deja lista (bandeja, # general, equipos) y trae el contador.
  async ensure({ commit, dispatch }) {
    const { data } = await InternalChannelAPI.ensure();
    commit('SET_INBOX_ID', data.inbox_id);
    dispatch('fetchUnread');
    return data.inbox_id;
  },
  fetchUnread({ commit }) {
    clearTimeout(refreshTimer);
    refreshTimer = setTimeout(async () => {
      try {
        const { data } = await InternalChannelAPI.unread();
        commit('SET_UNREAD', data.unread || 0);
      } catch {
        // Sin red: el contador se corrige en la siguiente consulta.
      }
    }, REFRESH_DELAY);
  },
  // Un mensaje nuevo por ActionCable: si es de «Interno» y de otro agente, suena (si la
  // sala no está a la vista) y se actualiza el contador.
  messageCreated({ state: $state, dispatch, rootGetters }, message) {
    if (!$state.inboxId || message.inbox_id !== $state.inboxId) return;
    const mine =
      message.sender && message.sender.id === rootGetters.getCurrentUserID;
    if (mine) return;
    const selected = rootGetters.getSelectedChat || {};
    const inView = selected.id === message.conversation_id && !document.hidden;
    if (!inView && typeof window.playAudioAlert === 'function') {
      window.playAudioAlert();
    }
    dispatch('fetchUnread');
  },
};

export const mutations = {
  SET_INBOX_ID($state, inboxId) {
    $state.inboxId = inboxId;
  },
  SET_UNREAD($state, unread) {
    $state.unread = unread;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
