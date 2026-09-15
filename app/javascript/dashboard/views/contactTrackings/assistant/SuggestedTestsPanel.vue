<script>
// proyecto@asistente_agentes_ia — fase E de PROMPT STUDIO (§32)
// ============================================================================
// Los tests sugeridos, arriba del banco de pruebas. Cada mensaje lo escribió el
// modelo; a dónde cae lo decide el clasificador real. Los casos límite van sin
// veredicto: la rama que el modelo cree correcta se muestra como su opinión.
//
// "Probar a fondo" manda el mensaje al banco de pruebas de abajo, que además
// busca en la fuente y dice qué contestaría.
// ============================================================================
export default {
  props: {
    // { cases: [...], generated_by, version } o null si todavía no se generaron.
    result: { type: Object, default: null },
    isRunning: { type: Boolean, default: false },
    stage: { type: Object, default: null },
    draftVersion: { type: Number, default: 0 },
    canRun: { type: Boolean, default: false },
  },
  emits: ['generate', 'probe'],
  computed: {
    cases() {
      return this.result?.cases || [];
    },
    routeCases() {
      return this.cases.filter(c => c.kind === 'route');
    },
    edgeCases() {
      return this.cases.filter(c => c.kind === 'edge');
    },
    passed() {
      return this.routeCases.filter(c => c.pass).length;
    },
    isStale() {
      return Boolean(this.result) && this.result.version !== this.draftVersion;
    },
    progressLabel() {
      if (!this.stage || this.stage.stage !== 'testing') {
        return this.$t('TRACKING_ASSISTANT_VIEW.TESTS_WRITING');
      }
      return this.$t('TRACKING_ASSISTANT_VIEW.TESTS_PROGRESS', {
        done: this.stage.done + 1,
        total: this.stage.total,
      });
    },
  },
  methods: {
    mark(caso) {
      if (caso.pass === true) return '✓';
      if (caso.pass === false) return '✗';
      return '·';
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col gap-2 p-3 mb-3 text-xs border rounded shrink-0 border-slate-100 dark:border-slate-700 max-h-[45%] overflow-y-auto"
  >
    <div class="flex flex-wrap items-center justify-between gap-2">
      <div>
        <p class="!m-0 font-semibold text-slate-800 dark:text-slate-100">
          {{ $t('TRACKING_ASSISTANT_VIEW.TESTS_TITLE') }}
        </p>
        <p v-if="!result" class="!m-0 text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_ASSISTANT_VIEW.TESTS_HINT') }}
        </p>
        <p
          v-else-if="routeCases.length"
          class="!m-0 text-slate-600 dark:text-slate-300"
        >
          {{
            $t('TRACKING_ASSISTANT_VIEW.TESTS_SUMMARY', {
              passed,
              total: routeCases.length,
              edge: edgeCases.length,
            })
          }}
        </p>
        <p v-if="isStale" class="!m-0 text-amber-700 dark:text-amber-300">
          {{ $t('TRACKING_ASSISTANT_VIEW.TESTS_STALE') }}
        </p>
      </div>
      <woot-button
        size="small"
        variant="smooth"
        :is-loading="isRunning"
        :is-disabled="!canRun || isRunning"
        @click="$emit('generate')"
      >
        {{
          result
            ? $t('TRACKING_ASSISTANT_VIEW.TESTS_RERUN')
            : $t('TRACKING_ASSISTANT_VIEW.TESTS_RUN')
        }}
      </woot-button>
    </div>

    <p v-if="isRunning" class="!m-0 text-slate-500 dark:text-slate-400">
      {{ progressLabel }}
    </p>

    <p
      v-if="result && result.generated_by === 'descriptions'"
      class="!m-0 text-slate-500 dark:text-slate-400"
    >
      {{ $t('TRACKING_ASSISTANT_VIEW.TESTS_FROM_DESCRIPTIONS') }}
    </p>

    <div v-if="cases.length" class="overflow-x-auto">
      <table class="w-full text-xs">
        <thead>
          <tr class="text-left text-slate-500 dark:text-slate-400">
            <th class="py-1 pr-2 font-normal" />
            <th class="py-1 pr-2 font-normal">
              {{ $t('TRACKING_ASSISTANT_VIEW.TESTS_COL_MESSAGE') }}
            </th>
            <th class="py-1 pr-2 font-normal">
              {{ $t('TRACKING_ASSISTANT_VIEW.TESTS_COL_EXPECTED') }}
            </th>
            <th class="py-1 pr-2 font-normal">
              {{ $t('TRACKING_ASSISTANT_VIEW.TESTS_COL_CHOSEN') }}
            </th>
            <th class="py-1 font-normal" />
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="(caso, index) in cases"
            :key="index"
            class="border-t border-slate-100 dark:border-slate-700 align-top"
          >
            <td
              class="py-1 pr-2 font-semibold"
              :class="{
                'text-green-600 dark:text-green-400': caso.pass === true,
                'text-red-600 dark:text-red-400': caso.pass === false,
                'text-slate-400': caso.pass === null,
              }"
            >
              {{ mark(caso) }}
            </td>
            <td class="py-1 pr-2 text-slate-800 dark:text-slate-100">
              {{ caso.message }}
              <span
                v-if="caso.kind === 'edge'"
                class="block text-slate-500 dark:text-slate-400"
              >
                {{ $t('TRACKING_ASSISTANT_VIEW.TESTS_EDGE') }}
                <template v-if="caso.note">· {{ caso.note }}</template>
              </span>
            </td>
            <td class="py-1 pr-2 font-mono">
              {{ caso.expected || '—' }}
              <span
                v-if="caso.kind === 'edge' && caso.expected"
                class="block font-sans text-slate-400"
              >
                {{ $t('TRACKING_ASSISTANT_VIEW.TESTS_EDGE_OPINION') }}
              </span>
            </td>
            <td class="py-1 pr-2 font-mono">
              {{ caso.chosen || $t('TRACKING_ASSISTANT_VIEW.TESTS_NO_ROUTE') }}
            </td>
            <td class="py-1">
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                @click="$emit('probe', caso.message)"
              >
                {{ $t('TRACKING_ASSISTANT_VIEW.TESTS_PROBE') }}
              </woot-button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
