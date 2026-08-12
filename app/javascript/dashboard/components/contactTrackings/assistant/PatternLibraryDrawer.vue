<script>
// ================================================================================
// proyecto@ai_agent_assistant - F6
// ================================================================================
// Componente: PatternLibraryDrawer
// Descripción: La biblioteca de patrones. Bloques insertables sacados de los
//              agentes de producción que sí funcionan, con la evidencia de dónde
//              salió cada uno.
//
// No es una galería para clonar: cada bloque resuelve UNA cosa y deja <huecos>
// para el negocio. Y sobre todo sabe callarse — con una directiva de búsqueda
// activa, todo bloque de prompt sale marcado como letra muerta y no se puede
// insertar, porque el motor lo descartaría.
//
// Los textos de los bloques y su evidencia vienen del backend en español: son
// contenido que acaba dentro del prompt del agente, no etiquetas de interfaz.
// Lo que sí está en i18n es el marco (títulos, secciones, estados).
// ================================================================================
import AiAgentAssistantAPI from 'dashboard/api/aiAgentAssistant';

export default {
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
  data() {
    return {
      blocks: [],
      sections: [],
      rules: [],
      skeleton: '',
      promptIsDiscarded: false,
      isLoading: false,
      showRules: false,
    };
  },
  computed: {
    // Solo se muestran las secciones que tienen algo dentro.
    populatedSections() {
      return this.sections.filter(section =>
        this.blocks.some(block => block.section === section)
      );
    },
  },
  watch: {
    show(value) {
      if (value) this.fetch();
    },
  },
  methods: {
    async fetch() {
      this.isLoading = true;
      try {
        const { data } = await AiAgentAssistantAPI.patterns({
          complementaryPrompt: this.prompt,
          inboxId: this.inboxId,
          trackingTemplateId: this.trackingTemplateId,
        });
        this.blocks = data.blocks;
        this.sections = data.sections;
        this.rules = data.rules;
        this.skeleton = data.skeleton;
        this.promptIsDiscarded = data.prompt_is_discarded;
      } catch (error) {
        this.blocks = [];
      } finally {
        this.isLoading = false;
      }
    },
    blocksIn(section) {
      return this.blocks.filter(block => block.section === section);
    },
    // Los bloques de configuración no van en el prompt: no hay nada que insertar.
    canInsert(block) {
      return block.kind === 'prompt' && block.status === 'ready';
    },
    onInsert(block) {
      this.$emit('insert', block.body);
    },
    statusClasses(status) {
      if (status === 'ready') {
        return 'text-green-700 bg-green-50 dark:text-green-300 dark:bg-green-800/20';
      }
      if (status === 'dead_letter') {
        return 'text-red-700 bg-red-50 dark:text-red-300 dark:bg-red-800/20';
      }
      return 'text-amber-700 bg-amber-50 dark:text-amber-300 dark:bg-amber-800/20';
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
          {{ $t('AI_AGENT_ASSISTANT.PATTERNS.TITLE') }}
        </h2>
        <p class="mt-1 text-sm text-slate-600 dark:text-slate-400">
          {{ $t('AI_AGENT_ASSISTANT.PATTERNS.DESCRIPTION') }}
        </p>
      </div>

      <!-- Con una búsqueda activa el motor descarta el prompt entero: insertar
           cualquier bloque de texto sería regalar caracteres. -->
      <div v-if="promptIsDiscarded" class="px-8 mt-4">
        <div
          class="px-4 py-3 text-xs border rounded-lg bg-red-50 border-red-200 dark:bg-red-800/20 dark:border-red-800 text-red-800 dark:text-red-200"
        >
          {{ $t('AI_AGENT_ASSISTANT.PATTERNS.DISCARDED_WARNING') }}
        </div>
      </div>

      <div v-if="isLoading" class="px-8 py-8 text-sm text-slate-500">
        {{ $t('AI_AGENT_ASSISTANT.PATTERNS.LOADING') }}
      </div>

      <div v-else class="flex-1 min-h-0 px-8 pb-6 mt-4 overflow-y-auto">
        <!-- Guía de forma: las siete reglas y el esqueleto -->
        <div
          class="p-4 mb-4 border rounded-lg bg-slate-25 border-slate-75 dark:bg-slate-800 dark:border-slate-700"
        >
          <div class="flex items-center gap-2">
            <p
              class="m-0 text-xs font-semibold text-slate-700 dark:text-slate-200"
            >
              {{ $t('AI_AGENT_ASSISTANT.PATTERNS.RULES_TITLE') }}
            </p>
            <woot-button
              size="tiny"
              variant="clear"
              class="ml-auto"
              @click.prevent="showRules = !showRules"
            >
              {{
                showRules
                  ? $t('AI_AGENT_ASSISTANT.PATTERNS.HIDE')
                  : $t('AI_AGENT_ASSISTANT.PATTERNS.SHOW')
              }}
            </woot-button>
          </div>
          <template v-if="showRules">
            <ol
              class="pl-4 mt-2 mb-3 text-xs list-decimal text-slate-600 dark:text-slate-300"
            >
              <li v-for="rule in rules" :key="rule.key" class="mb-1">
                {{ rule.rule }}
              </li>
            </ol>
            <p
              class="mb-1 text-xs font-semibold text-slate-500 dark:text-slate-400"
            >
              {{ $t('AI_AGENT_ASSISTANT.PATTERNS.SKELETON') }}
            </p>
            <pre
              class="p-3 overflow-x-auto text-xs whitespace-pre-wrap rounded bg-slate-50 dark:bg-slate-900 text-slate-700 dark:text-slate-200"
              >{{ skeleton }}</pre
            >
            <woot-button
              size="tiny"
              variant="smooth"
              class="mt-2"
              :is-disabled="promptIsDiscarded"
              @click.prevent="$emit('insert', skeleton)"
            >
              {{ $t('AI_AGENT_ASSISTANT.PATTERNS.USE_SKELETON') }}
            </woot-button>
          </template>
        </div>

        <!-- Bloques por sección -->
        <div v-for="section in populatedSections" :key="section" class="mb-5">
          <p
            class="mb-2 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
          >
            {{ $t(`AI_AGENT_ASSISTANT.PATTERNS.SECTION.${section}`) }}
          </p>

          <div
            v-for="block in blocksIn(section)"
            :key="block.key"
            class="p-3 mb-2 border rounded-lg border-slate-100 dark:border-slate-700"
          >
            <div class="flex items-center gap-2">
              <span
                class="text-sm font-semibold text-slate-800 dark:text-slate-100"
              >
                {{ $t(`AI_AGENT_ASSISTANT.PATTERNS.BLOCK.${block.key}`) }}
              </span>
              <span
                class="px-2 py-0.5 text-xs rounded"
                :class="statusClasses(block.status)"
              >
                {{
                  $t(
                    `AI_AGENT_ASSISTANT.PATTERNS.STATUS.${block.status.toUpperCase()}`
                  )
                }}
              </span>
              <span class="text-xs text-slate-400 dark:text-slate-500">
                {{
                  $t('AI_AGENT_ASSISTANT.PATTERNS.CHARS', {
                    chars: block.chars,
                  })
                }}
              </span>
              <woot-button
                v-if="canInsert(block)"
                size="tiny"
                class="ml-auto"
                @click.prevent="onInsert(block)"
              >
                {{ $t('AI_AGENT_ASSISTANT.PATTERNS.INSERT') }}
              </woot-button>
            </div>

            <pre
              class="p-2 mt-2 overflow-x-auto text-xs whitespace-pre-wrap rounded bg-slate-50 dark:bg-slate-800 text-slate-700 dark:text-slate-200"
              >{{ block.body }}</pre
            >

            <!-- La evidencia: un bloque sin ella sería solo una opinión -->
            <p
              class="mt-2 mb-0 text-xs italic text-slate-500 dark:text-slate-400"
            >
              {{ block.source }}
            </p>
          </div>
        </div>
      </div>

      <div class="px-8 py-4 border-t border-slate-200 dark:border-slate-700">
        <woot-button variant="clear" @click.prevent="onClose">
          {{ $t('AI_AGENT_ASSISTANT.PATTERNS.CLOSE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
