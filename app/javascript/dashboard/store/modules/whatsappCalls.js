// diag/llamadas_whatsapp (F5) — LA LLAMADA QUE SUENA Y LA QUE ESTÁ ACTIVA
// ============================================================================
// incoming  la entrante que suena en esta pestaña (de voice_call.incoming)
// active    la llamada en curso o la saliente que está sonando del lado del cliente:
//           { id, conversationId, inboxId, direction, status, startedAt, caller, muted,
//             recording } — recording: se graba (F7), el widget le muestra el guion al agente
// Los eventos de ActionCable (helper/actionCable.js) llegan a las acciones `on*`.
// El audio vive en helper/whatsappCallSession.js. Los avisos van a `notice` ({ key,
// args }) y los muestra el widget (aquí no hay $t).
// ============================================================================
import WhatsappCallsAPI from 'dashboard/api/whatsappCalls';
import * as session from 'dashboard/helper/whatsappCallSession';

export const state = {
  incoming: null,
  active: null,
  isBusy: false,
  notice: null,
};

export const getters = {
  getIncoming: $state => $state.incoming,
  getActive: $state => $state.active,
  isBusy: $state => $state.isBusy,
  getNotice: $state => $state.notice,
};

const notice = (commit, key, args = {}) =>
  commit('SET_NOTICE', {
    key: `WHATSAPP_CALLS.WIDGET.${key}`,
    args,
    at: Date.now(),
  });

export const actions = {
  // ── Eventos de ActionCable ───────────────────────────────────────────────
  onIncoming({ commit, state: $state }, data) {
    // Con una llamada en curso no se interrumpe: los demás agentes la tomarán.
    if ($state.active || $state.incoming) return;
    commit('SET_INCOMING', data);
  },
  onAccepted({ commit, state: $state, rootGetters }, data) {
    const yo = rootGetters.getCurrentUserID;
    if (
      $state.incoming &&
      $state.incoming.id === data.id &&
      data.accepted_by_agent_id !== yo
    ) {
      commit('SET_INCOMING', null);
    }
  },
  onEnded({ commit, state: $state }, data) {
    if ($state.incoming && $state.incoming.id === data.id)
      commit('SET_INCOMING', null);
    if ($state.active && $state.active.id === data.id) {
      commit('SET_ACTIVE', null);
      // Colgó el cliente: se sube lo grabado antes de soltar todo.
      session.finishCall().catch(() => {});
    }
  },
  async onOutboundConnected(_context, data) {
    await session.applyOutboundAnswer(data);
  },
  onOutboundAccepted({ commit, state: $state }, data) {
    if ($state.active && $state.active.id === data.id) {
      commit('SET_ACTIVE', {
        ...$state.active,
        status: 'in_progress',
        startedAt: Date.now(),
      });
      session.armRecorder(data.id);
    }
  },
  onPermissionGranted({ commit }, data) {
    notice(commit, 'PERMISSION_GRANTED', { name: data.contact_name });
  },

  // ── Lo que hace el agente ────────────────────────────────────────────────
  async answer({ commit, state: $state }) {
    const llamada = $state.incoming;
    if (!llamada) return;
    commit('SET_BUSY', true);
    try {
      const data = await session.answerIncoming(llamada);
      commit('SET_INCOMING', null);
      commit('SET_ACTIVE', {
        id: data.id,
        conversationId: llamada.conversation_id,
        inboxId: llamada.inbox_id,
        direction: 'inbound',
        status: 'in_progress',
        startedAt: Date.now(),
        caller: llamada.caller,
        muted: false,
        recording: data.recording_enabled === true,
      });
    } catch (error) {
      commit('SET_INCOMING', null);
      const status = error && error.response && error.response.status;
      notice(commit, status === 409 ? 'ALREADY_TAKEN' : 'ANSWER_ERROR');
    } finally {
      commit('SET_BUSY', false);
    }
  },
  async reject({ commit, state: $state }) {
    const llamada = $state.incoming;
    commit('SET_INCOMING', null);
    if (llamada) await WhatsappCallsAPI.reject(llamada.id).catch(() => {});
  },
  async hangup({ commit }) {
    commit('SET_ACTIVE', null);
    await session.hangup().catch(() => {});
  },
  toggleMute({ commit, state: $state }) {
    if (!$state.active) return;
    commit('SET_ACTIVE', { ...$state.active, muted: session.toggleMute() });
  },
  // conversation: { id (display_id), inbox_id, meta.sender }
  async call({ commit, state: $state }, conversation) {
    if ($state.active || $state.incoming) {
      notice(commit, 'BUSY');
      return;
    }
    const contacto = (conversation.meta && conversation.meta.sender) || {};
    commit('SET_ACTIVE', {
      id: null,
      conversationId: conversation.id,
      inboxId: conversation.inbox_id,
      direction: 'outbound',
      status: 'connecting',
      startedAt: null,
      caller: {
        name: contacto.name,
        phone: contacto.phone_number,
        avatar: contacto.thumbnail,
      },
      muted: false,
    });
    try {
      const resultado = await session.startOutbound(conversation.id);
      if (resultado.permission) {
        commit('SET_ACTIVE', null);
        const { status, next_allowed_at: siguiente } = resultado.permission;
        if (status === 'permission_limit') {
          notice(commit, 'PERMISSION_LIMIT', {
            date: new Date(siguiente).toLocaleString(),
          });
        } else {
          notice(commit, 'PERMISSION_REQUESTED');
        }
        return;
      }
      commit('SET_ACTIVE', {
        ...$state.active,
        id: resultado.call.id,
        status: 'ringing',
        recording: resultado.call.recording_enabled === true,
      });
    } catch (error) {
      commit('SET_ACTIVE', null);
      const mensaje =
        error &&
        error.response &&
        error.response.data &&
        error.response.data.error;
      notice(commit, 'CALL_ERROR', { message: mensaje || '' });
    }
  },
};

export const mutations = {
  SET_INCOMING($state, data) {
    $state.incoming = data;
  },
  SET_ACTIVE($state, data) {
    $state.active = data;
  },
  SET_BUSY($state, value) {
    $state.isBusy = value;
  },
  SET_NOTICE($state, value) {
    $state.notice = value;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
