<script>
// proyecto@crear_agente_conversando — FD: LAS RUTAS PROBADAS, DIBUJADAS
// ============================================================================
// Plan: docs/creacion_conversacional_agentes_plan.md §7 (D10). Mientras se conversa
// todavía no hay Entrenamiento, y el diagrama dibuja un Entrenamiento. Se dibuja el
// BOCETO: las líneas @ruta(…) que el chat ya probó con el clasificador real. Debajo,
// las frases probadas; elegir una ilumina su camino (el mismo AgentDiagram y el mismo
// pathFromDryRun que la pestaña «Pruebas y diagrama», con un informe que solo dice a
// qué ruta cayó).
//
// La estructura la arma Ruby (training_preview) a partir del texto del boceto, igual
// que con un Entrenamiento: así el dibujo es exactamente el que tendrá el agente.
// ============================================================================
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';
import AgentDiagram from './AgentDiagram.vue';
import { defaultRouteName } from './trainingBlocks';

export default {
  components: { AgentDiagram },
  props: {
    // Las líneas @ruta(…) del boceto, una por renglón.
    routes: { type: String, default: '' },
    // [{ frase, cae_en, estable, veces, a_veces_en? }]
    tests: { type: Array, default: () => [] },
  },
  data() {
    return { structure: { blocks: [] }, selected: null, loadError: false };
  },
  computed: {
    defaultRoute() {
      return defaultRouteName(this.structure.blocks || []);
    },
    // Lo que AgentDiagram espera de una prueba en seco: solo a qué ruta cayó.
    diagramTest() {
      const prueba = this.tests[this.selected];
      if (!prueba) return null;
      return {
        mode: 'dry',
        result: {
          routes: { chosen: prueba.cae_en, default: this.defaultRoute },
        },
      };
    },
    stableCount() {
      return this.tests.filter(t => t.estable).length;
    },
  },
  watch: {
    routes: { immediate: true, handler: 'loadStructure' },
    tests() {
      if (this.selected !== null && !this.tests[this.selected])
        this.selected = null;
    },
  },
  methods: {
    async loadStructure() {
      this.loadError = false;
      if (!this.routes.trim()) {
        this.structure = { blocks: [] };
        return;
      }
      try {
        const { data } = await TrackingTemplatesAPI.trainingPreview({
          text: this.routes,
        });
        this.structure = data.training_structure || { blocks: [] };
      } catch (error) {
        this.loadError = true;
      }
    },
    toggle(index) {
      this.selected = this.selected === index ? null : index;
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-3">
    <div>
      <h3
        class="!mb-1 text-sm font-semibold text-slate-800 dark:text-slate-100"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.SKETCH_TITLE') }}
      </h3>
      <p class="!m-0 text-xs text-slate-600 dark:text-slate-300">
        {{ $t('TRACKING_ASSISTANT_VIEW.SKETCH_HINT') }}
      </p>
    </div>
    <p
      v-if="!routes.trim()"
      class="!m-0 text-sm text-slate-500 dark:text-slate-400"
    >
      {{ $t('TRACKING_ASSISTANT_VIEW.SKETCH_EMPTY') }}
    </p>
    <p v-if="loadError" class="!m-0 text-sm text-red-600 dark:text-red-400">
      {{ $t('TRACKING_ASSISTANT_VIEW.SKETCH_ERROR') }}
    </p>
    <div v-if="routes.trim()" class="min-h-0 overflow-auto">
      <AgentDiagram
        :structure="structure"
        :test="diagramTest"
        export-name="boceto-agente"
        @clearHighlight="selected = null"
      />
    </div>
    <div v-if="tests.length" class="flex flex-col gap-1">
      <span class="text-xs font-medium text-slate-600 dark:text-slate-300">
        {{
          $t('TRACKING_ASSISTANT_VIEW.SKETCH_TESTS', {
            ok: stableCount,
            total: tests.length,
          })
        }}
      </span>
      <button
        v-for="(prueba, index) in tests"
        :key="prueba.frase"
        type="button"
        class="flex items-center gap-2 px-2 py-1 text-left rounded text-sm"
        :class="
          selected === index
            ? 'bg-woot-50 dark:bg-woot-800/40'
            : 'hover:bg-slate-50 dark:hover:bg-slate-700'
        "
        @click="toggle(index)"
      >
        <span
          class="w-1.5 h-1.5 rounded-full shrink-0"
          :class="prueba.estable ? 'bg-green-500' : 'bg-amber-500'"
        />
        <span
          class="flex-1 min-w-0 truncate text-slate-700 dark:text-slate-200"
        >
          {{ `«${prueba.frase}»` }}
        </span>
        <span class="text-xs text-slate-500 dark:text-slate-400 shrink-0">
          {{ `@${prueba.cae_en}` }}
          <template v-if="!prueba.estable">
            {{ $t('TRACKING_ASSISTANT_VIEW.SKETCH_UNSTABLE') }}
          </template>
        </span>
      </button>
      <p class="!m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ $t('TRACKING_ASSISTANT_VIEW.SKETCH_CARRY') }}
      </p>
    </div>
  </div>
</template>
