import { throwErrorMessage } from 'dashboard/store/utils/api';
import ConversationApi from '../../../../api/inbox/conversation';
import mutationTypes from '../../../mutation-types';
import { isInternalChat } from 'dashboard/helper/internalChat';

// feat/chat_interno_pulido: al leer (o dejar sin leer) una sala de «Interno», el contador
// del menú «Chat interno» se vuelve a pedir.
const refreshInternalUnread = (dispatch, rootGetters, id) => {
  const chats = rootGetters.getAllConversations || [];
  if (isInternalChat(chats.find(chat => chat.id === id))) {
    dispatch('internalChat/fetchUnread', null, { root: true });
  }
};

export default {
  markMessagesRead: async ({ commit, dispatch, rootGetters }, data) => {
    try {
      const {
        data: { id, agent_last_seen_at: lastSeen },
      } = await ConversationApi.markMessageRead(data);
      refreshInternalUnread(dispatch, rootGetters, id);
      setTimeout(
        () =>
          commit(mutationTypes.UPDATE_MESSAGE_UNREAD_COUNT, { id, lastSeen }),
        4000
      );
    } catch (error) {
      // Handle error
    }
  },

  markMessagesUnread: async ({ commit, dispatch, rootGetters }, { id }) => {
    try {
      const {
        data: { agent_last_seen_at: lastSeen, unread_count: unreadCount },
      } = await ConversationApi.markMessagesUnread({ id });
      commit(mutationTypes.UPDATE_MESSAGE_UNREAD_COUNT, {
        id,
        lastSeen,
        unreadCount,
      });
      refreshInternalUnread(dispatch, rootGetters, id);
    } catch (error) {
      throwErrorMessage(error);
    }
  },
};
