<script>
import { mapGetters } from 'vuex';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useAccount } from 'dashboard/composables/useAccount';
import OnboardingView from '../OnboardingView.vue';
import EmptyStateMessage from './EmptyStateMessage.vue';
import { INBOX_TYPES } from 'shared/mixins/inboxMixin';

export default {
  components: {
    OnboardingView,
    EmptyStateMessage,
  },
  props: {
    isOnExpandedLayout: {
      type: Boolean,
      default: false,
    },
  },
  setup() {
    const { isAdmin } = useAdmin();

    const { accountScopedUrl } = useAccount();

    return {
      isAdmin,
      accountScopedUrl,
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      allConversations: 'getAllConversations',
      inboxesList: 'inboxes/getInboxes',
      uiFlags: 'inboxes/getUIFlags',
      loadingChatList: 'getChatListLoadingStatus',
    }),
    loadingIndicatorMessage() {
      if (this.uiFlags.isFetching) {
        return this.$t('CONVERSATION.LOADING_INBOXES');
      }
      return this.$t('CONVERSATION.LOADING_CONVERSATIONS');
    },
    conversationMissingMessage() {
      if (!this.isOnExpandedLayout) {
        return this.$t('CONVERSATION.SELECT_A_CONVERSATION');
      }
      return this.$t('CONVERSATION.404');
    },
    // feat/chat_interno_pulido: en «Chat interno» no se habla de clientes.
    isInternalInbox() {
      const inboxId = Number(this.$route.params.inbox_id);
      const inbox = this.inboxesList.find(item => item.id === inboxId);
      return !!inbox && inbox.channel_type === INBOX_TYPES.INTERNAL;
    },
    newInboxURL() {
      return this.accountScopedUrl('settings/inboxes/new');
    },
    emptyClassName() {
      if (
        !this.inboxesList.length &&
        !this.uiFlags.isFetching &&
        !this.loadingChatList &&
        this.isAdmin
      ) {
        return 'h-full overflow-auto';
      }
      return 'flex-1 min-w-0 px-0 flex flex-col items-center justify-center h-full';
    },
  },
};
</script>

<template>
  <div :class="emptyClassName">
    <woot-loading-state
      v-if="uiFlags.isFetching || loadingChatList"
      :message="loadingIndicatorMessage"
    />
    <!-- No inboxes attached -->
    <div
      v-if="!inboxesList.length && !uiFlags.isFetching && !loadingChatList"
      class="clearfix"
    >
      <OnboardingView v-if="isAdmin" />
      <EmptyStateMessage v-else :message="$t('CONVERSATION.NO_INBOX_AGENT')" />
    </div>
    <!-- Show empty state images if not loading -->

    <div
      v-else-if="!uiFlags.isFetching && !loadingChatList"
      class="flex flex-col items-center justify-center h-full"
    >
      <!-- No conversations available -->
      <EmptyStateMessage
        v-if="isInternalInbox"
        :message="$t('INTERNAL_CHAT.EMPTY_ROOM')"
      />
      <EmptyStateMessage
        v-else-if="!allConversations.length"
        :message="$t('CONVERSATION.NO_MESSAGE_1')"
      />
      <EmptyStateMessage
        v-else-if="allConversations.length && !currentChat.id"
        :message="conversationMissingMessage"
      />
    </div>
  </div>
</template>
