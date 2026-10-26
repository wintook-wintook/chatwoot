<script>
// feat/chat_interno (F3) — UNA SALA ABIERTA
// ============================================================================
// Mensajes del más viejo al más nuevo, agrupados por quien escribe (el nombre y la foto
// salen solo cuando cambia de persona o pasan más de 5 minutos). «Cargar anteriores»
// pide la página de antes. Enter envía; Shift+Enter hace otra línea.
// El texto se pinta como texto ({{ }}), nunca como HTML.
// ============================================================================
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import ResizableTextArea from 'shared/components/ResizableTextArea.vue';
import { messageStamp } from 'shared/helpers/timeHelper';
import { memberName, otherMember, roomTitle } from './roomHelpers';

const GROUP_WINDOW_SECONDS = 5 * 60;

export default {
  components: { Thumbnail, ResizableTextArea },
  props: {
    room: { type: Object, required: true },
  },
  data() {
    return { draft: '', loadingOlder: false };
  },
  computed: {
    ...mapGetters({
      currentUserId: 'getCurrentUserID',
      messagesFor: 'internalChat/messagesFor',
      hasMoreFor: 'internalChat/hasMoreFor',
      uiFlags: 'internalChat/uiFlags',
    }),
    messages() {
      return this.messagesFor(this.room.id);
    },
    hasMore() {
      return this.hasMoreFor(this.room.id);
    },
    title() {
      return roomTitle(
        this.room,
        this.currentUserId,
        this.$t('INTERNAL_CHAT.GENERAL')
      );
    },
    subtitle() {
      if (this.room.kind === 'general')
        return this.$t('INTERNAL_CHAT.EVERYONE');
      if (this.room.kind === 'direct') {
        const other = otherMember(this.room, this.currentUserId);
        return other ? other.availability_status || '' : '';
      }
      return this.$t('INTERNAL_CHAT.MEMBERS', {
        count: (this.room.member_ids || []).length,
      });
    },
    isGroup() {
      return this.room.kind === 'group';
    },
    canSend() {
      return this.draft.trim().length > 0 && !this.uiFlags.sending;
    },
  },
  watch: {
    'messages.length'() {
      this.$nextTick(this.scrollToBottomIfNear);
    },
  },
  mounted() {
    this.$nextTick(this.scrollToBottom);
  },
  methods: {
    senderName(message) {
      if (message.sender && message.sender.id === this.currentUserId) {
        return this.$t('INTERNAL_CHAT.YOU');
      }
      return memberName(message.sender);
    },
    // ¿Este mensaje abre un bloque nuevo (otra persona o pasaron 5 minutos)?
    startsBlock(index) {
      if (index === 0) return true;
      const previous = this.messages[index - 1];
      const current = this.messages[index];
      const sameSender =
        previous.sender &&
        current.sender &&
        previous.sender.id === current.sender.id;
      return (
        !sameSender ||
        current.created_at - previous.created_at > GROUP_WINDOW_SECONDS
      );
    },
    time(message) {
      return messageStamp(message.created_at, 'HH:mm');
    },
    scrollToBottom() {
      const list = this.$refs.list;
      if (list) list.scrollTop = list.scrollHeight;
    },
    scrollToBottomIfNear() {
      const list = this.$refs.list;
      if (!list) return;
      const near = list.scrollHeight - list.scrollTop - list.clientHeight < 200;
      if (near) this.scrollToBottom();
    },
    async loadOlder() {
      const list = this.$refs.list;
      const fromBottom = list ? list.scrollHeight - list.scrollTop : 0;
      this.loadingOlder = true;
      try {
        await this.$store.dispatch('internalChat/fetchOlder', this.room.id);
        this.$nextTick(() => {
          if (list) list.scrollTop = list.scrollHeight - fromBottom;
        });
      } finally {
        this.loadingOlder = false;
      }
    },
    onEnter(event) {
      if (event.shiftKey) return;
      event.preventDefault();
      this.send();
    },
    async send() {
      if (!this.canSend) return;
      const content = this.draft.trim();
      this.draft = '';
      try {
        await this.$store.dispatch('internalChat/sendMessage', {
          roomId: this.room.id,
          content,
        });
        this.$nextTick(this.scrollToBottom);
      } catch (error) {
        this.draft = content;
        useAlert(this.$t('INTERNAL_CHAT.SEND_ERROR'));
      }
    },
    async leave() {
      // eslint-disable-next-line no-alert
      if (!window.confirm(this.$t('INTERNAL_CHAT.LEAVE_CONFIRM'))) return;
      await this.$store.dispatch('internalChat/leaveRoom', this.room.id);
      this.$router.push({ name: 'internal_chat' });
    },
  },
};
</script>

<template>
  <section class="flex flex-col flex-1 h-full min-w-0 min-h-0">
    <header
      class="flex items-center justify-between h-14 gap-2 px-4 border-b shrink-0 border-slate-50 dark:border-slate-800/50"
    >
      <div class="min-w-0">
        <h3
          class="m-0 text-sm font-semibold truncate text-slate-800 dark:text-slate-100"
        >
          {{ title }}
        </h3>
        <p class="m-0 text-xs truncate text-slate-500 dark:text-slate-400">
          {{ subtitle }}
        </p>
      </div>
      <woot-button
        v-if="isGroup"
        size="small"
        variant="clear"
        color-scheme="secondary"
        icon="power"
        @click="leave"
      >
        {{ $t('INTERNAL_CHAT.LEAVE') }}
      </woot-button>
    </header>

    <div ref="list" class="flex-1 min-h-0 px-4 py-3 overflow-auto">
      <div v-if="hasMore" class="flex justify-center mb-3">
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          :is-loading="loadingOlder"
          @click="loadOlder"
        >
          {{ $t('INTERNAL_CHAT.LOAD_OLDER') }}
        </woot-button>
      </div>
      <p
        v-if="!messages.length && !uiFlags.loadingMessages"
        class="mt-8 text-sm text-center text-slate-500 dark:text-slate-400"
      >
        {{ $t('INTERNAL_CHAT.NO_MESSAGES') }}
      </p>
      <div
        v-for="(message, index) in messages"
        :key="message.id"
        class="flex gap-2"
        :class="startsBlock(index) ? 'mt-3' : 'mt-0.5'"
      >
        <div class="w-8 shrink-0">
          <Thumbnail
            v-if="startsBlock(index) && message.sender"
            :src="message.sender.avatar_url"
            :username="senderName(message)"
            size="32px"
          />
        </div>
        <div class="min-w-0">
          <div v-if="startsBlock(index)" class="flex items-baseline gap-2">
            <span
              class="text-sm font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ senderName(message) }}
            </span>
            <span class="text-xs text-slate-400 dark:text-slate-500">
              {{ time(message) }}
            </span>
          </div>
          <p
            v-if="message.deleted"
            class="m-0 text-sm italic text-slate-400 dark:text-slate-500"
          >
            {{ $t('INTERNAL_CHAT.DELETED') }}
          </p>
          <p
            v-else
            class="m-0 text-sm break-words whitespace-pre-wrap text-slate-700 dark:text-slate-200"
          >
            {{ message.content }}
          </p>
        </div>
      </div>
    </div>

    <footer
      class="flex items-end gap-2 px-4 py-3 border-t shrink-0 border-slate-50 dark:border-slate-800/50"
    >
      <ResizableTextArea
        v-model="draft"
        class="flex-1 !mb-0 px-3 py-2 text-sm rounded-lg border border-slate-100 dark:border-slate-700 bg-white dark:bg-slate-800"
        :placeholder="$t('INTERNAL_CHAT.PLACEHOLDER')"
        :min-height="2"
        @keydown.enter.native="onEnter"
      />
      <woot-button
        icon="send"
        :is-disabled="!canSend"
        :is-loading="uiFlags.sending"
        @click="send"
      >
        {{ $t('INTERNAL_CHAT.SEND') }}
      </woot-button>
    </footer>
  </section>
</template>
