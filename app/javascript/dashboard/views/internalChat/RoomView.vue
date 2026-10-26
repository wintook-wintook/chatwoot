<script>
// feat/chat_interno — UNA SALA ABIERTA, con las piezas REALES de una conversación
// ============================================================================
// Encabezado con el marcado de ConversationHeader, burbujas con Message.vue dentro del
// mismo <ul class="conversation-panel"> que MessagesView (lo mío a la derecha, lo de
// otros a la izquierda con su foto: showSenderAvatar; sin menú: hideContextMenu) y caja de
// respuesta como ReplyBox en los canales sin texto enriquecido (ResizableTextArea).
// Enter envía; Shift+Enter hace otra línea. Ver adapters.js.
// ============================================================================
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import Message from 'dashboard/components/widgets/conversation/Message.vue';
import ResizableTextArea from 'shared/components/ResizableTextArea.vue';
import { roomContact, toMessage } from './adapters';

export default {
  components: { Thumbnail, Message, ResizableTextArea },
  props: {
    room: { type: Object, required: true },
  },
  data() {
    return { draft: '', loadingOlder: false, isFocused: false };
  },
  computed: {
    ...mapGetters({
      currentUserId: 'getCurrentUserID',
      messagesFor: 'internalChat/messagesFor',
      hasMoreFor: 'internalChat/hasMoreFor',
      uiFlags: 'internalChat/uiFlags',
      globalConfig: 'globalConfig/get',
    }),
    contact() {
      return roomContact(
        this.room,
        this.currentUserId,
        this.$t('INTERNAL_CHAT.GENERAL')
      );
    },
    messages() {
      return this.messagesFor(this.room.id).map(message =>
        toMessage(message, this.currentUserId, this.room)
      );
    },
    hasMore() {
      return this.hasMoreFor(this.room.id);
    },
    subtitle() {
      if (this.room.kind === 'general') return this.$t('INTERNAL_CHAT.EVERYONE');
      if (this.room.kind === 'team') {
        return this.$t('INTERNAL_CHAT.TEAM_MEMBERS', {
          count: (this.room.member_ids || []).length,
        });
      }
      return this.$t('INTERNAL_CHAT.DIRECT');
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
  },
};
</script>

<template>
  <section
    class="flex flex-col flex-1 h-full min-w-0 min-h-0 bg-white dark:bg-slate-900"
  >
    <div
      class="flex items-center justify-between px-4 py-2 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex items-center justify-start max-w-full min-w-0 w-fit">
        <Thumbnail
          :src="contact.thumbnail"
          :username="contact.name"
          :status="contact.availability_status"
        />
        <div
          class="flex flex-col items-start min-w-0 ml-2 overflow-hidden rtl:ml-0 rtl:mr-2 w-fit"
        >
          <span
            class="text-base font-medium leading-tight truncate text-slate-900 dark:text-slate-100"
          >
            {{ contact.name }}
          </span>
          <span
            class="text-xs truncate conversation--header--actions text-slate-500 dark:text-slate-400"
          >
            {{ subtitle }}
          </span>
        </div>
      </div>
    </div>

    <div ref="list" class="flex flex-col flex-1 min-h-0 overflow-auto">
      <ul class="conversation-panel" :style="globalConfig.conversationStyleCss">
        <li v-if="hasMore" class="flex justify-center min-h-[4rem]">
          <woot-button
            size="small"
            variant="clear"
            color-scheme="secondary"
            :is-loading="loadingOlder"
            @click="loadOlder"
          >
            {{ $t('INTERNAL_CHAT.LOAD_OLDER') }}
          </woot-button>
        </li>
        <li
          v-if="!messages.length && !uiFlags.loadingMessages"
          class="flex justify-center min-h-[4rem] text-sm text-slate-500 dark:text-slate-400"
        >
          {{ $t('INTERNAL_CHAT.NO_MESSAGES') }}
        </li>
        <Message
          v-for="message in messages"
          :key="message.id"
          :data="message"
          show-sender-avatar
          hide-context-menu
        />
      </ul>
    </div>

    <div class="reply-box" :class="{ 'is-focused': isFocused }">
      <div class="reply-box__top">
        <ResizableTextArea
          v-model="draft"
          class="input"
          :placeholder="$t('INTERNAL_CHAT.PLACEHOLDER')"
          :min-height="4"
          @focus="isFocused = true"
          @blur="isFocused = false"
          @keydown.enter.native="onEnter"
        />
      </div>
      <div class="flex justify-end px-4 py-3">
        <woot-button
          size="small"
          :is-disabled="!canSend"
          :is-loading="uiFlags.sending"
          @click="send"
        >
          {{ $t('INTERNAL_CHAT.SEND') }}
        </woot-button>
      </div>
    </div>
  </section>
</template>

<style lang="scss" scoped>
// El mismo marco que ReplyBox.vue (sus estilos son scoped, así que se repiten aquí).
.reply-box {
  transition: box-shadow 0.35s cubic-bezier(0.37, 0, 0.63, 1);
  @apply relative border-t border-slate-50 dark:border-slate-700 bg-white dark:bg-slate-900;

  &.is-focused {
    box-shadow:
      0 1px 3px 0 rgba(0, 0, 0, 0.1),
      0 1px 2px 0 rgba(0, 0, 0, 0.06);
  }
}

.reply-box__top {
  @apply relative py-0 px-4 -mt-px border-t border-solid border-slate-50 dark:border-slate-700;

  ::v-deep textarea {
    @apply shadow-none border-transparent bg-transparent m-0 max-h-60 min-h-[3rem] pt-4 pb-0 px-0 resize-none;
  }
}
</style>
