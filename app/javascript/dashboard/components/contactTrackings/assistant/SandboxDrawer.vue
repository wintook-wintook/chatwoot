<script>
// ================================================================================
// proyecto@ai_agent_assistant - F3
// ================================================================================
// Componente: SandboxDrawer
// Descripción: El probador. En F3 muestra «Ver prompt»: el system prompt EXACTO
//              que recibiría el modelo en las dos rutas, con su modelo, su tope de
//              tokens y los avisos que solo se entienden viendo el texto armado.
//
// No envía nada ni crea seguimientos: el backend ensambla con el mismo
// PromptBuilder que usa el motor y devuelve el texto.
// ================================================================================
import AiAgentAssistantAPI from 'dashboard/api/aiAgentAssistant';

export default {
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    // Cuerpo del Agente IA tal y como se guardaría. Se pasa desde el editor para
    // que lo previsualizado sea el borrador actual, no lo último guardado.
    payload: {
      type: Object,
      default: () => ({}),
    },
  },
  emits: ['close'],
  data() {
    return {
      preview: null,
      isLoading: false,
      attempt: 1,
      activeRoute: 'scheduled',
    };
  },
  computed: {
    routes() {
      return ['scheduled', 'conversational'];
    },
    section() {
      return this.preview ? this.preview[this.activeRoute] : null;
    },
    // Regla de dedo estándar para español: ~4 caracteres por token. Sirve para ver
    // el orden de magnitud del desajuste, no para facturar.
    estimatedTokens() {
      return this.section ? Math.round(this.section.system_chars / 4) : 0;
    },
    isOverBudget() {
      return this.section
        ? this.estimatedTokens > this.section.max_tokens * 4
        : false;
    },
  },
  watch: {
    show(value) {
      if (value) this.fetchPreview();
    },
    attempt() {
      this.fetchPreview();
    },
  },
  methods: {
    async fetchPreview() {
      this.isLoading = true;
      try {
        const { data } = await AiAgentAssistantAPI.previewPrompt({
          ...this.payload,
          attempt: this.attempt,
        });
        this.preview = data;
      } catch (error) {
        this.preview = null;
      } finally {
        this.isLoading = false;
      }
    },
    onClose() {
      this.$emit('close');
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="onClose" size="medium">
    <div class="flex flex-col h-full max-h-[80vh]">
      <div class="px-8 pt-6">
        <h2 class="text-lg font-semibold text-slate-800 dark:text-slate-100">
          {{ $t('AI_AGENT_ASSISTANT.SANDBOX.TITLE') }}
        </h2>
        <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">
          {{ $t('AI_AGENT_ASSISTANT.SANDBOX.DESCRIPTION') }}
        </p>
      </div>

      <div class="flex items-center gap-2 px-8 mt-4">
        <woot-button
          v-for="route in routes"
          :key="route"
          size="small"
          :variant="activeRoute === route ? 'smooth' : 'clear'"
          @click.prevent="activeRoute = route"
        >
          {{ $t(`AI_AGENT_ASSISTANT.SANDBOX.ROUTE_${route.toUpperCase()}`) }}
        </woot-button>
        <div
          v-if="activeRoute === 'scheduled'"
          class="flex items-center gap-1 ml-auto"
        >
          <label class="mb-0 text-xs text-slate-500 dark:text-slate-400">
            {{ $t('AI_AGENT_ASSISTANT.SANDBOX.ATTEMPT') }}
          </label>
          <select v-model.number="attempt" class="h-8 py-0 mb-0 text-sm w-16">
            <option v-for="n in 3" :key="n" :value="n">{{ n }}</option>
          </select>
        </div>
      </div>

      <div v-if="isLoading" class="px-8 py-8 text-sm text-slate-500">
        {{ $t('AI_AGENT_ASSISTANT.SANDBOX.LOADING') }}
      </div>

      <div
        v-else-if="section"
        class="flex-1 min-h-0 px-8 pb-6 mt-4 overflow-y-auto"
      >
        <!-- Presupuesto: el desajuste entre lo que escribes y lo que cabe -->
        <div
          class="flex flex-wrap items-center gap-4 px-4 py-3 mb-4 text-xs border rounded-lg"
          :class="
            isOverBudget
              ? 'bg-red-50 border-red-200 dark:bg-red-800/20 dark:border-red-800'
              : 'bg-slate-25 border-slate-75 dark:bg-slate-800 dark:border-slate-700'
          "
        >
          <span class="text-slate-600 dark:text-slate-300">
            {{ $t('AI_AGENT_ASSISTANT.SANDBOX.MODEL') }}
            <code class="font-bold">{{ section.model }}</code>
          </span>
          <span class="text-slate-600 dark:text-slate-300">
            {{
              $t('AI_AGENT_ASSISTANT.SANDBOX.SIZE', {
                chars: section.system_chars,
                tokens: estimatedTokens,
              })
            }}
          </span>
          <span
            class="font-semibold"
            :class="
              isOverBudget
                ? 'text-red-700 dark:text-red-300'
                : 'text-slate-600 dark:text-slate-300'
            "
          >
            {{
              $t('AI_AGENT_ASSISTANT.SANDBOX.BUDGET', {
                tokens: section.max_tokens,
              })
            }}
          </span>
        </div>

        <!-- Avisos que solo se ven con el prompt armado -->
        <div
          v-for="note in section.notes"
          :key="note"
          class="px-4 py-3 mb-3 text-xs border rounded-lg bg-amber-50 border-amber-200 dark:bg-amber-800/20 dark:border-amber-800 text-amber-800 dark:text-amber-200"
        >
          {{ $t(`AI_AGENT_ASSISTANT.SANDBOX.NOTE_${note.toUpperCase()}`) }}
        </div>

        <p
          class="mt-4 mb-1 text-xs font-semibold text-slate-500 dark:text-slate-400"
        >
          {{ $t('AI_AGENT_ASSISTANT.SANDBOX.SYSTEM') }}
        </p>
        <pre
          class="p-4 overflow-x-auto text-xs whitespace-pre-wrap rounded-lg bg-slate-50 dark:bg-slate-800 text-slate-700 dark:text-slate-200"
          >{{ section.system }}</pre
        >

        <p
          class="mt-4 mb-1 text-xs font-semibold text-slate-500 dark:text-slate-400"
        >
          {{ $t('AI_AGENT_ASSISTANT.SANDBOX.USER') }}
        </p>
        <pre
          class="p-4 overflow-x-auto text-xs whitespace-pre-wrap rounded-lg bg-slate-50 dark:bg-slate-800 text-slate-700 dark:text-slate-200"
          >{{ section.user }}</pre
        >
      </div>

      <div class="px-8 py-4 border-t border-slate-200 dark:border-slate-700">
        <woot-button variant="clear" @click.prevent="onClose">
          {{ $t('AI_AGENT_ASSISTANT.SANDBOX.CLOSE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
