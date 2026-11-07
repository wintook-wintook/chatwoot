<!--
  Asistente (Dali) — barra «Pregúntale a Dali…» arriba de todas las pantallas del
  dashboard, para tenerlo siempre a la vista. Escribir + Enter abre el panel con la
  pregunta ya enviada; Enter sin texto abre el panel vacío. El texto de la caja
  cambia según lo que se está viendo (caso, contacto, organización, conversación).
  Las pantallas de campo (Mi ruta) no usan Dashboard.vue y no la muestran.
-->
<script>
import {
  assistantState,
  toggleAssistant,
  DEFAULT_ASSISTANT_NAME,
} from 'dashboard/helper/assistantState';

const T = 'ASSISTANT.TOP_BAR';

export default {
  name: 'AssistantTopBar',
  data() {
    return { state: assistantState, text: '' };
  },
  computed: {
    name() {
      return this.state.name || DEFAULT_ASSISTANT_NAME;
    },
    // Mismo criterio que AssistantPanel#context.
    placeholder() {
      const { name: route, params } = this.$route;
      let key = 'PLACEHOLDER';
      if (route === 'gestorTickets_detail' && params.id) key = 'ON_CASE';
      else if (params.conversation_id) key = 'ON_CONVERSATION';
      else if (params.contactId) key = 'ON_CONTACT';
      else if (params.organizationId) key = 'ON_ORGANIZATION';
      return this.$t(`${T}.${key}`, { name: this.name });
    },
  },
  methods: {
    submit() {
      const text = this.text.trim();
      toggleAssistant(true);
      if (!text) return;
      this.text = '';
      this.$refs.input?.blur();
      // El panel ya escucha (está montado siempre); se abre y luego recibe la pregunta.
      this.$nextTick(() => this.$emitter.emit('assistant:ask', text));
    },
  },
};
</script>

<template>
  <div
    class="flex items-center flex-shrink-0 h-10 px-3 bg-white border-b border-slate-100 dark:bg-slate-900 dark:border-slate-800"
  >
    <form
      class="flex items-center flex-1 max-w-xl gap-2 px-3 mx-auto rounded-lg h-7 bg-slate-50 dark:bg-slate-800 focus-within:ring-1 focus-within:ring-woot-300"
      @submit.prevent="submit"
    >
      <fluent-icon icon="wand" size="14" class="flex-shrink-0 text-woot-500" />
      <input
        ref="input"
        v-model="text"
        type="text"
        class="flex-1 min-w-0 !h-7 !mb-0 !p-0 text-sm !bg-transparent !border-0 !shadow-none focus:!ring-0 placeholder:text-slate-400"
        :placeholder="placeholder"
        :aria-label="placeholder"
      />
      <kbd
        class="flex-shrink-0 hidden px-1.5 text-[10px] font-sans border rounded sm:inline text-slate-400 border-slate-200 dark:border-slate-700"
      >
        {{ $t('ASSISTANT.SHORTCUT') }}
      </kbd>
    </form>
  </div>
</template>
