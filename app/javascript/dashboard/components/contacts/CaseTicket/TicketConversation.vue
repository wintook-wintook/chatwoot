<!--
  @tickets_cases U1 — Unir ticket + conversación.
  Muestra el hilo de la conversación vinculada con el componente NATIVO de Chatwoot
  (widgets/conversation/Message.vue) para que se vea idéntico al inbox, y permite
  responder (público o nota privada) sin salir del ticket.
-->
<script>
import { mapGetters } from 'vuex';
import MessageApi from 'dashboard/api/inbox/message';
import Message from 'dashboard/components/widgets/conversation/Message.vue';
import { frontendURL } from 'dashboard/helper/URLHelper';

export default {
  name: 'TicketConversation',
  components: { Message },
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
      showCanned: false, // @tickets_cases P4 — respuestas predefinidas
    };
  },
  computed: {
    ...mapGetters({ cannedResponses: 'getCannedResponses' }),
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
    // @tickets_cases P4 — respuestas predefinidas (canned) de la cuenta.
    this.$store.dispatch('getCannedResponse');
  },
  methods: {
    // @tickets_cases U1 — permite que el detalle precargue la sugerencia de la IA.
    setReply(text) {
      this.replyText = text || '';
      this.isPrivate = false;
    },
    // @tickets_cases P4 — inserta una respuesta predefinida (texto plano) en la caja.
    pickCanned(cr) {
      this.showCanned = false;
      const tmp = document.createElement('div');
      tmp.innerHTML = cr.content || '';
      const text = (tmp.textContent || tmp.innerText || '').trim();
      this.replyText = this.replyText ? `${this.replyText}\n${text}` : text;
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

    <!-- Hilo con el componente NATIVO de Chatwoot -->
    <div
      class="flex-1 min-h-0 overflow-y-auto border rounded-lg bg-white dark:bg-slate-900 border-slate-100 dark:border-slate-700"
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
      <ul v-else class="conversation-panel !p-3">
        <Message
          v-for="m in messages"
          :key="m.id"
          :data="m"
        />
      </ul>
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
        <div class="flex items-center gap-3">
          <label class="flex items-center gap-2 text-xs text-slate-600 dark:text-slate-300">
            <input v-model="isPrivate" type="checkbox" />
            {{ $t('CASE_TICKETS.CONVERSATION.PRIVATE_TOGGLE') }}
          </label>
          <!-- @tickets_cases P4 — respuestas predefinidas -->
          <div v-if="cannedResponses.length" class="relative">
            <button
              type="button"
              class="flex items-center gap-1 text-xs text-woot-500 hover:underline"
              @click="showCanned = !showCanned"
            >
              <fluent-icon icon="chat-multiple" size="14" />
              {{ $t('CASE_TICKETS.CONVERSATION.CANNED') }}
            </button>
            <ul
              v-if="showCanned"
              class="absolute left-0 z-50 py-1 mb-1 list-none overflow-y-auto bg-white border rounded-md shadow-md bottom-full dark:bg-slate-800 border-slate-100 dark:border-slate-700 w-72 max-h-64"
            >
              <li
                v-for="cr in cannedResponses"
                :key="cr.id"
                class="px-3 py-2 text-sm cursor-pointer text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
                @click="pickCanned(cr)"
              >
                <span class="font-mono text-xs text-woot-500">/{{ cr.short_code }}</span>
              </li>
            </ul>
          </div>
        </div>
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
