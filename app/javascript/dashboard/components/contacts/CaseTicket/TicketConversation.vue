<!--
  @tickets_cases U1 — Unir ticket + conversación.
  Muestra el hilo de la conversación vinculada y permite responder (público o nota
  privada) sin salir del ticket, reusando la API de mensajes del inbox.
-->
<script>
import MessageApi from 'dashboard/api/inbox/message';
import { MESSAGE_TYPE } from 'shared/constants/messages';
import { frontendURL } from 'dashboard/helper/URLHelper';

export default {
  name: 'TicketConversation',
  props: {
    conversationId: { type: [Number, String], required: true },
  },
  data() {
    return {
      messages: [],
      replyText: '',
      isPrivate: false,
      isLoading: false,
      isSending: false,
    };
  },
  computed: {
    conversationLink() {
      const accountId = this.$route.params.accountId;
      return frontendURL(`accounts/${accountId}/conversations/${this.conversationId}`);
    },
  },
  watch: {
    conversationId() {
      this.load();
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    // @tickets_cases U1 — permite que el detalle precargue la sugerencia de la IA.
    setReply(text) {
      this.replyText = text || '';
      this.isPrivate = false;
    },
    async load() {
      if (!this.conversationId) return;
      this.isLoading = true;
      try {
        const { data } = await MessageApi.getPreviousMessages({
          conversationId: this.conversationId,
        });
        const list = data.payload || data || [];
        this.messages = [...list].sort((a, b) => a.id - b.id);
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.CONVERSATION.LOAD_ERROR'),
        });
      } finally {
        this.isLoading = false;
      }
    },
    async send() {
      const content = this.replyText.trim();
      if (!content || this.isSending) return;
      this.isSending = true;
      try {
        const { data } = await MessageApi.create({
          conversationId: this.conversationId,
          message: content,
          private: this.isPrivate,
        });
        if (data) this.messages.push(data);
        this.replyText = '';
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.CONVERSATION.SEND_ERROR'),
        });
      } finally {
        this.isSending = false;
      }
    },
    isIncoming(m) {
      return m.message_type === MESSAGE_TYPE.INCOMING;
    },
    isActivity(m) {
      return m.message_type === MESSAGE_TYPE.ACTIVITY;
    },
    senderName(m) {
      return m.sender?.name || (this.isIncoming(m) ? '' : this.$t('CASE_TICKETS.CONVERSATION.SYSTEM'));
    },
    formatTime(m) {
      const ts = typeof m.created_at === 'number' ? m.created_at * 1000 : m.created_at;
      return new Date(ts).toLocaleString();
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-full min-h-0">
    <!-- Acceso a la conversación completa -->
    <div class="flex items-center justify-between flex-shrink-0 mb-2">
      <span class="text-xs text-slate-400 dark:text-slate-500">
        {{ $t('CASE_TICKETS.CONVERSATION.SUBTITLE') }}
      </span>
      <a
        :href="conversationLink"
        class="text-xs font-medium text-woot-500 hover:underline"
      >
        {{ $t('CASE_TICKETS.CONVERSATION.OPEN_FULL') }} →
      </a>
    </div>

    <!-- Hilo -->
    <div
      class="flex-1 min-h-0 p-3 space-y-3 overflow-y-auto border rounded-lg bg-slate-25 dark:bg-slate-800/40 border-slate-100 dark:border-slate-700"
    >
      <div v-if="isLoading" class="py-6 text-sm text-center text-slate-400">
        {{ $t('CASE_TICKETS.CONVERSATION.LOADING') }}
      </div>
      <div
        v-else-if="!messages.length"
        class="py-6 text-sm text-center text-slate-400"
      >
        {{ $t('CASE_TICKETS.CONVERSATION.EMPTY') }}
      </div>

      <template v-for="m in messages">
        <!-- Actividad del sistema -->
        <div
          v-if="isActivity(m)"
          :key="m.id"
          class="text-[11px] text-center text-slate-400 dark:text-slate-500"
        >
          {{ m.content }}
        </div>
        <!-- Mensaje (entrante / saliente / nota privada) -->
        <div
          v-else
          :key="m.id"
          class="flex"
          :class="isIncoming(m) ? 'justify-start' : 'justify-end'"
        >
          <div
            class="max-w-[80%] rounded-lg px-3 py-2 text-sm whitespace-pre-wrap break-words"
            :class="
              m.private
                ? 'bg-amber-50 text-amber-900 border border-amber-200 dark:bg-amber-900/30 dark:text-amber-100 dark:border-amber-900/50'
                : isIncoming(m)
                  ? 'bg-white text-slate-800 border border-slate-100 dark:bg-slate-800 dark:text-slate-100 dark:border-slate-700'
                  : 'bg-woot-500 text-white'
            "
          >
            <div
              v-if="m.private"
              class="mb-0.5 text-[10px] font-semibold uppercase tracking-wide opacity-70"
            >
              {{ $t('CASE_TICKETS.CONVERSATION.PRIVATE') }}
            </div>
            <div>{{ m.content }}</div>
            <div class="mt-1 text-[10px] opacity-60">
              {{ senderName(m) }} · {{ formatTime(m) }}
            </div>
          </div>
        </div>
      </template>
    </div>

    <!-- Caja de respuesta -->
    <div class="flex-shrink-0 mt-3">
      <textarea
        v-model="replyText"
        rows="3"
        class="w-full"
        :placeholder="
          isPrivate
            ? $t('CASE_TICKETS.CONVERSATION.NOTE_PLACEHOLDER')
            : $t('CASE_TICKETS.CONVERSATION.REPLY_PLACEHOLDER')
        "
      />
      <div class="flex items-center justify-between mt-1">
        <label class="flex items-center gap-2 text-xs text-slate-600 dark:text-slate-300">
          <input v-model="isPrivate" type="checkbox" />
          {{ $t('CASE_TICKETS.CONVERSATION.PRIVATE_TOGGLE') }}
        </label>
        <woot-button
          size="small"
          :is-loading="isSending"
          :disabled="!replyText.trim()"
          @click="send"
        >
          {{
            isPrivate
              ? $t('CASE_TICKETS.CONVERSATION.ADD_NOTE')
              : $t('CASE_TICKETS.CONVERSATION.SEND')
          }}
        </woot-button>
      </div>
    </div>
  </div>
</template>
