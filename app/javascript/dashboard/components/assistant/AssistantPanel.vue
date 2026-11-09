<!--
  Asistente (Dali) — panel lateral del asistente, en toda la plataforma.
  Se abre con el botón de la barra lateral, desde el menú del logo o con Ctrl + J,
  y sigue abierto al navegar. Le dice al asistente qué está viendo el usuario
  (caso, contacto, organización, conversación o pantalla) para que «esto» se
  entienda sin repetirlo. Se monta oculto (v-show) para que la plática cargue y el
  nombre del asistente llegue a la barra de arriba aunque no se abra. La plática en sí (mensajes, tarjetas, cuadro) es
  AssistantChat, la misma del portal de Dali en el teléfono.
  El nombre lo pone cada cuenta (Ajustes → Asistente).
-->
<script>
import {
  assistantState,
  toggleAssistant,
  DEFAULT_ASSISTANT_NAME,
} from 'dashboard/helper/assistantState';
import AssistantChat from './AssistantChat.vue';

const T = 'ASSISTANT';

export default {
  name: 'AssistantPanel',
  components: { AssistantChat },
  data() {
    return { state: assistantState };
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
  },
  beforeDestroy() {
    window.removeEventListener('keydown', this.onKeydown);
    this.$emitter.off('assistant:ask', this.ask);
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, { name: this.name, ...params });
    },
    chat() {
      return this.$refs.chat;
    },
    openPanel() {
      this.$nextTick(() => {
        const chat = this.chat();
        if (!chat) return;
        if (!chat.loaded) chat.load();
        chat.focus();
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
    ask(text) {
      this.chat()?.ask(text);
    },
    reset() {
      this.chat()?.reset();
    },
    onDone(proposal) {
      this.$emitter.emit('assistant:done', proposal);
    },
    go(path) {
      if (path && path !== this.$route.path) this.$router.push(path);
    },
  },
};
</script>

<template>
  <transition name="assistant-slide">
    <aside
      v-show="state.open"
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

      <AssistantChat
        ref="chat"
        :context="context"
        @navigate="go"
        @done="onDone"
      />
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
</style>
