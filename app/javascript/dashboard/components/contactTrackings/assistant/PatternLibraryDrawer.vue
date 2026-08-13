<script>
// ================================================================================
// proyecto@ai_agent_assistant - F6
// ================================================================================
// Componente: PatternLibraryDrawer
// Descripción: La biblioteca de patrones dentro del editor del Agente IA, donde
//              SÍ hay un prompt al que llevarse el bloque.
//
// Aquí solo queda la carcasa: el contenido es PatternLibraryList, que también se
// lee como pestaña propia en el asistente. Un bloque tiene que leerse igual en
// los dos sitios; si el cajón tuviera su propia copia, dejarían de coincidir a la
// primera corrección.
// ================================================================================
import PatternLibraryList from './PatternLibraryList.vue';

export default {
  components: { PatternLibraryList },
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    // El prompt que se está escribiendo. Decide qué bloques serían letra muerta.
    prompt: {
      type: String,
      default: '',
    },
    inboxId: {
      type: [Number, String],
      default: null,
    },
    trackingTemplateId: {
      type: [Number, String],
      default: null,
    },
  },
  emits: ['close', 'insert'],
  methods: {
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
          {{ $t('AI_AGENT_ASSISTANT.PATTERNS.TITLE') }}
        </h2>
        <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">
          {{ $t('AI_AGENT_ASSISTANT.PATTERNS.DESCRIPTION') }}
        </p>
      </div>

      <div class="flex-1 min-h-0 px-8 pb-6 mt-4 overflow-y-auto">
        <!-- `v-if` para que abrir el cajón sea lo que dispara la consulta: los
             bloques se resuelven contra el prompt que hay AHORA, no el de hace
             tres ediciones. -->
        <PatternLibraryList
          v-if="show"
          insertable
          :prompt="prompt"
          :inbox-id="inboxId"
          :tracking-template-id="trackingTemplateId"
          @insert="body => $emit('insert', body)"
        />
      </div>

      <div class="px-8 py-4 border-t border-slate-200 dark:border-slate-700">
        <woot-button variant="clear" @click.prevent="onClose">
          {{ $t('AI_AGENT_ASSISTANT.PATTERNS.CLOSE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
