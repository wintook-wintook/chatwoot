<!--
  Asistente (Dali) — panel lateral del asistente, en toda la plataforma.
  Se abre con el botón de la barra lateral, desde el menú del logo o con Ctrl + J,
  y sigue abierto al navegar. Le dice al asistente qué está viendo el usuario
  (caso, contacto, organización, conversación o pantalla) para que «esto» se
  entienda sin repetirlo. Las acciones llegan como tarjetas (ProposalCard) que el
  usuario confirma. El nombre lo pone cada cuenta (Ajustes → Asistente).
-->
<script>
import AssistantAPI from 'dashboard/api/platformAssistant';
import MessageFormatter from 'shared/helpers/MessageFormatter';
import {
  assistantState,
  toggleAssistant,
  DEFAULT_ASSISTANT_NAME,
} from 'dashboard/helper/assistantState';
import ProposalCard from './ProposalCard.vue';

const T = 'ASSISTANT';

export default {
  name: 'AssistantPanel',
  components: { ProposalCard },
  data() {
    return {
      state: assistantState,
      messages: [],
      available: true,
      loaded: false,
      draft: '',
      sending: false,
      error: '',
    };
  },
  computed: {
    name() {
      return this.state.name || DEFAULT_ASSISTANT_NAME;
    },
    // Lo que el usuario está viendo, sacado de la ruta.
    context() {
      const { name, params } = this.$route;
      const ctx = { page: name || '' };
      if (name === 'gestorTickets_detail' && params.id) ctx.case_id = params.id;
      if (params.contactId) ctx.contact_id = params.contactId;
      if (params.organizationId) ctx.organization_id = params.organizationId;
      if (params.conversation_id) ctx.conversation_id = params.conversation_id;
      return ctx;
    },
  },
  watch: {
    'state.open'(open) {
      if (open) this.openPanel();
    },
  },
  mounted() {
    window.addEventListener('keydown', this.onKeydown);
    // Otra pantalla le pide algo al asistente (p. ej. «¿cómo va el seguimiento?»).
    this.$emitter.on('assistant:ask', this.ask);
    this.load();
  },
  beforeDestroy() {
    window.removeEventListener('keydown', this.onKeydown);
    this.$emitter.off('assistant:ask', this.ask);
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, { name: this.name, ...params });
    },
    async load() {
      try {
        const { data } = await AssistantAPI.show();
        this.state.name = data.name || DEFAULT_ASSISTANT_NAME;
        this.available = data.available;
        this.messages = data.messages || [];
        this.loaded = true;
      } catch (_e) {
        this.loaded = false;
      }
    },
    openPanel() {
      if (!this.loaded) this.load();
      this.$nextTick(() => {
        this.$refs.input?.focus();
        this.scrollDown();
      });
    },
    close() {
      toggleAssistant(false);
    },
    onKeydown(event) {
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'j') {
        event.preventDefault();
        toggleAssistant();
      } else if (event.key === 'Escape' && this.state.open) {
        this.close();
      }
    },
    onInputKeydown(event) {
      if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault();
        this.send();
      }
    },
    ask(text) {
      this.draft = text;
      this.send();
    },
    async send() {
      const content = this.draft.trim();
      if (!content || this.sending) return;
      this.sending = true;
      this.error = '';
      this.draft = '';
      this.messages.push({
        id: `tmp-${Date.now()}`,
        role: 'user',
        content,
      });
      this.scrollDown();
      try {
        const { data } = await AssistantAPI.send(content, this.context);
        // El servidor devuelve el turno guardado (pregunta + respuesta).
        this.messages.splice(-1, 1, ...data.messages);
        if (data.message.navigate) this.go(data.message.navigate);
      } catch (_e) {
        this.error = this.t('ERROR');
        this.draft = content;
        this.messages.pop();
      } finally {
        this.sending = false;
        this.scrollDown();
        this.$nextTick(() => this.$refs.input?.focus());
      }
    },
    async reset() {
      const { data } = await AssistantAPI.reset();
      this.messages = data.messages || [];
    },
    onProposalUpdated(message, proposal) {
      const idx = message.proposals.findIndex(p => p.id === proposal.id);
      if (idx > -1) message.proposals.splice(idx, 1, proposal);
      // La pantalla abierta (p. ej. el caso) se refresca con lo que se acaba de hacer.
      if (proposal.status === 'done') {
        this.$emitter.emit('assistant:done', proposal);
      }
    },
    go(path) {
      if (path && path !== this.$route.path) this.$router.push(path);
    },
    html(content) {
      return new MessageFormatter(content || '').formattedMessage;
    },
    scrollDown() {
      this.$nextTick(() => {
        const box = this.$refs.list;
        if (box) box.scrollTop = box.scrollHeight;
      });
    },
  },
};
</script>

<template>
  <transition name="assistant-slide">
    <aside
      v-if="state.open"
      class="fixed top-0 right-0 z-[60] flex flex-col h-full bg-white border-l shadow-xl w-[26rem] max-w-full dark:bg-slate-900 border-slate-100 dark:border-slate-800"
    >
      <header
        class="flex items-center gap-2 px-4 py-3 border-b border-slate-100 dark:border-slate-800"
      >
        <span
          class="flex items-center justify-center w-8 h-8 rounded-full bg-woot-50 text-woot-600 dark:bg-woot-900/40"
        >
          <fluent-icon icon="wand" size="16" />
        </span>
        <div class="flex flex-col flex-1 min-w-0">
          <span
            class="text-sm font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ name }}
          </span>
          <span class="text-xs text-slate-500">
            {{ t('SUBTITLE') }} · {{ t('SHORTCUT') }}
          </span>
        </div>
        <woot-button
          v-tooltip="t('NEW')"
          size="small"
          variant="clear"
          color-scheme="secondary"
          icon="add"
          @click="reset"
        />
        <woot-button
          v-tooltip="t('CLOSE')"
          size="small"
          variant="clear"
          color-scheme="secondary"
          icon="dismiss"
          @click="close"
        />
      </header>

      <div ref="list" class="flex flex-col flex-1 gap-3 p-4 overflow-y-auto">
        <p
          v-if="!available"
          class="p-3 m-0 text-sm rounded-lg bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-200"
        >
          {{ t('UNAVAILABLE') }}
        </p>
        <div
          v-if="!messages.length"
          class="p-3 text-sm rounded-lg bg-slate-50 text-slate-600 dark:bg-slate-800 dark:text-slate-300"
        >
          {{ t('HELLO') }}
        </div>
        <div
          v-for="message in messages"
          :key="message.id"
          class="flex flex-col gap-2"
          :class="message.role === 'user' ? 'items-end' : 'items-start'"
        >
          <div
            v-if="message.content"
            class="px-3 py-2 text-sm rounded-lg max-w-[90%] assistant-text"
            :class="
              message.role === 'user'
                ? 'bg-woot-500 text-white'
                : 'bg-slate-50 text-slate-800 dark:bg-slate-800 dark:text-slate-100'
            "
            v-html="html(message.content)"
          />
          <ProposalCard
            v-for="proposal in message.proposals || []"
            :key="proposal.id"
            :proposal="proposal"
            class="w-full"
            @updated="p => onProposalUpdated(message, p)"
            @navigate="go"
          />
        </div>
        <p v-if="sending" class="m-0 text-xs text-slate-500">
          {{ t('THINKING') }}
        </p>
        <p v-if="error" class="m-0 text-xs text-red-600">{{ error }}</p>
      </div>

      <footer class="p-3 border-t border-slate-100 dark:border-slate-800">
        <div class="flex items-end gap-2">
          <textarea
            ref="input"
            v-model="draft"
            rows="2"
            class="flex-1 !mb-0 text-sm resize-none"
            :placeholder="t('PLACEHOLDER')"
            :disabled="!available"
            @keydown="onInputKeydown"
          />
          <woot-button
            icon="send"
            :is-loading="sending"
            :is-disabled="!draft.trim() || !available"
            @click="send"
          />
        </div>
      </footer>
    </aside>
  </transition>
</template>

<style scoped>
.assistant-slide-enter-active,
.assistant-slide-leave-active {
  transition: transform 0.2s ease;
}
.assistant-slide-enter,
.assistant-slide-leave-to {
  transform: translateX(100%);
}
.assistant-text ::v-deep p {
  margin: 0 0 0.25rem;
}
.assistant-text ::v-deep ul,
.assistant-text ::v-deep ol {
  margin: 0.25rem 0 0.25rem 1.1rem;
}
</style>
