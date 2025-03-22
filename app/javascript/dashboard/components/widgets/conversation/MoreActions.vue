<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import EmailTranscriptModal from './EmailTranscriptModal.vue';
import ResolveAction from '../../buttons/ResolveAction.vue';
import {
  CMD_MUTE_CONVERSATION,
  CMD_SEND_TRANSCRIPT,
  CMD_UNMUTE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';

export default {
  components: {
    EmailTranscriptModal,
    ResolveAction,
  },
  data() {
    return {
      showEmailActionsModal: false,
      textButtonMA: '',
      colorSchemeMA: '',
      botMA: null,
    };
  },
  props: {
    chatBot: {
      type: Object,
      default: () => { },
    },
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      currentUser: 'getCurrentUser',
    }),
  },
  mounted() {
    this.$emitter.on(CMD_MUTE_CONVERSATION, this.mute);
    this.$emitter.on(CMD_UNMUTE_CONVERSATION, this.unmute);
    this.$emitter.on(CMD_SEND_TRANSCRIPT, this.toggleEmailActionsModal);
  },
  destroyed() {
    this.$emitter.off(CMD_MUTE_CONVERSATION, this.mute);
    this.$emitter.off(CMD_UNMUTE_CONVERSATION, this.unmute);
    this.$emitter.off(CMD_SEND_TRANSCRIPT, this.toggleEmailActionsModal);
  },
  methods: {
    async getBotConversation() {
      const { access_token } = this.currentUser;
      const { account_id, id: display_id, inbox_id } = this.currentChat;
      const params = new URLSearchParams({ access_token, account_id, display_id, inbox_id });
      try {
        let response = await fetch(`${process.env.WINTOOK_BOT}/api/getBotConversation?${params.toString()}`, {
          method: 'GET'
        });
        const result = await response.json();

        if (response.status === 200) {
          this.chatBot = result;
          useAlert(result.toastMessage);
        } else {
          console.error("Error:", result);
        }
      } catch (error) {
        console.error("Fetch error:", error);
      }
    },
    async setBotConversation() {
      const { access_token } = this.currentUser;
      const { account_id, id: display_id, inbox_id } = this.currentChat;
      const params = new URLSearchParams({ access_token, account_id, display_id, inbox_id });
      try {
        let response = await fetch(`${process.env.WINTOOK_BOT}/api/setBotConversation?${params.toString()}`, {
          method: 'GET',
          headers: {
            'Content-Type': 'application/json'
          }
        });

        let result = await response.json();

        if (response.status === 200) {
          this.chatBot = result;
          useAlert(result.toastMessage);
        }
      } catch (error) {
        console.error(error);
        return error;
      }
    },
    mute() {
      this.$store.dispatch('muteConversation', this.currentChat.id);
      useAlert(this.$t('CONTACT_PANEL.MUTED_SUCCESS'));
    },
    unmute() {
      this.$store.dispatch('unmuteConversation', this.currentChat.id);
      useAlert(this.$t('CONTACT_PANEL.UNMUTED_SUCCESS'));
    },
    toggleEmailActionsModal() {
      this.showEmailActionsModal = !this.showEmailActionsModal;
    },
  },
};
</script>

<template>
  <div class="relative flex items-center gap-2 actions--container">
    <woot-button v-if="chatBot.inbox_bot && chatBot.account_bot" v-tooltip="'Bot EVAi'" title=" 'Bot Eva' "
      :color-scheme="chatBot.colorScheme" icon-size="14" variant="smooth" size="small expanded"
      @click="setBotConversation">
      {{ chatBot.textButton }}
    </woot-button>

    <woot-button v-if="!currentChat.muted" v-tooltip="$t('CONTACT_PANEL.MUTE_CONTACT')" variant="clear"
      color-scheme="secondary" icon="speaker-mute" @click="mute" />
    <woot-button v-else v-tooltip.left="$t('CONTACT_PANEL.UNMUTE_CONTACT')" variant="clear" color-scheme="secondary"
      icon="speaker-1" @click="unmute" />
    <woot-button v-tooltip="$t('CONTACT_PANEL.SEND_TRANSCRIPT')" variant="clear" color-scheme="secondary" icon="share"
      @click="toggleEmailActionsModal" />
    <ResolveAction :conversation-id="currentChat.id" :status="currentChat.status" />
    <EmailTranscriptModal v-if="showEmailActionsModal" :show="showEmailActionsModal" :current-chat="currentChat"
      @cancel="toggleEmailActionsModal" />
  </div>
</template>

<style scoped lang="scss">
.more--button {
  @apply items-center flex ml-2 rtl:ml-0 rtl:mr-2;
}

.dropdown-pane {
  @apply -right-2 top-12;
}

.icon {
  @apply mr-1 rtl:mr-0 rtl:ml-1 min-w-[1rem];
}
</style>
