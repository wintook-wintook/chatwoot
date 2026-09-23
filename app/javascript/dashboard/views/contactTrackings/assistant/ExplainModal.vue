<script>
// proyecto@asistente_agentes_ia — fase E de PROMPT STUDIO (§30)
// ============================================================================
// "¿Por qué existe esta regla?" sobre lo seleccionado en el editor. Dos bloques
// que no se mezclan: lo que lee el motor (hecho, sale del parser) y la lectura
// del asistente (interpretación).
// ============================================================================
export default {
  props: {
    show: { type: Boolean, default: false },
    excerpt: { type: String, default: '' },
    // { section, engine: { routes, default_route, loose_directives },
    //   interpretation: { explanation, applies_to, if_removed } } o null
    result: { type: Object, default: null },
    isRunning: { type: Boolean, default: false },
    error: { type: String, default: '' },
  },
  emits: ['close'],
  computed: {
    engine() {
      return this.result?.engine || {};
    },
    hasEngineFacts() {
      return Boolean(
        (this.engine.routes || []).length ||
          this.engine.default_route ||
          (this.engine.loose_directives || []).length
      );
    },
    interpretation() {
      return this.result?.interpretation || null;
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')">
    <div class="flex flex-col gap-3 p-8 text-sm max-h-[80vh] overflow-y-auto">
      <h2 class="!m-0 text-lg font-medium text-slate-800 dark:text-slate-100">
        {{ $t('TRACKING_ASSISTANT_VIEW.EXPLAIN_TITLE') }}
      </h2>
      <pre
        class="!m-0 p-2 font-mono text-xs whitespace-pre-wrap rounded bg-slate-50 dark:bg-slate-900 max-h-40 overflow-y-auto"
        >{{ excerpt }}</pre
      >
      <p
        v-if="result && result.section"
        class="!m-0 text-xs text-slate-500 dark:text-slate-400"
      >
        {{
          $t('TRACKING_ASSISTANT_VIEW.EXPLAIN_SECTION', {
            section: result.section,
          })
        }}
      </p>
      <p v-if="error" class="!m-0 text-red-600 dark:text-red-400">
        {{ error }}
      </p>
      <p v-if="isRunning" class="!m-0 text-slate-500 dark:text-slate-400">
        {{ $t('TRACKING_ASSISTANT_VIEW.EXPLAIN_RUNNING') }}
      </p>

      <template v-if="result && !isRunning">
        <div v-if="hasEngineFacts" class="flex flex-col gap-1">
          <p class="!m-0 font-semibold text-slate-800 dark:text-slate-100">
            {{ $t('TRACKING_ASSISTANT_VIEW.EXPLAIN_ENGINE') }}
          </p>
          <p
            v-for="ruta in engine.routes"
            :key="ruta.name"
            class="!m-0 text-xs"
          >
            {{
              $t('TRACKING_ASSISTANT_VIEW.EXPLAIN_ROUTE', {
                name: ruta.name,
                tag: ruta.tag || $t('TRACKING_ASSISTANT_VIEW.EXPLAIN_NO_TAG'),
                source:
                  ruta.source ||
                  $t('TRACKING_ASSISTANT_VIEW.EXPLAIN_NO_SOURCE'),
                escalation:
                  ruta.escalation ||
                  $t('TRACKING_ASSISTANT_VIEW.EXPLAIN_NO_ESCALATION'),
              })
            }}
          </p>
          <p v-if="engine.default_route" class="!m-0 text-xs">
            {{
              $t('TRACKING_ASSISTANT_VIEW.EXPLAIN_DEFAULT', {
                name: engine.default_route,
              })
            }}
          </p>
          <p
            v-for="directiva in engine.loose_directives || []"
            :key="directiva"
            class="!m-0 text-xs text-amber-800 dark:text-amber-800"
          >
            {{
              $t('TRACKING_ASSISTANT_VIEW.EXPLAIN_LOOSE', {
                directive: directiva,
              })
            }}
          </p>
        </div>

        <div v-if="interpretation" class="flex flex-col gap-1">
          <p class="!m-0 font-semibold text-slate-800 dark:text-slate-100">
            {{ $t('TRACKING_ASSISTANT_VIEW.EXPLAIN_INTERPRETATION') }}
          </p>
          <p class="!m-0 text-xs text-slate-500 dark:text-slate-400">
            {{ $t('TRACKING_ASSISTANT_VIEW.EXPLAIN_INTERPRETATION_HINT') }}
          </p>
          <p v-if="interpretation.explanation" class="!m-0">
            {{ interpretation.explanation }}
          </p>
          <p
            v-if="interpretation.applies_to && interpretation.applies_to.length"
            class="!m-0 text-xs"
          >
            {{
              $t('TRACKING_ASSISTANT_VIEW.EXPLAIN_APPLIES_TO', {
                routes: interpretation.applies_to.join(' · '),
              })
            }}
          </p>
          <p v-if="interpretation.if_removed" class="!m-0 text-xs">
            {{
              $t('TRACKING_ASSISTANT_VIEW.EXPLAIN_IF_REMOVED', {
                text: interpretation.if_removed,
              })
            }}
          </p>
        </div>
      </template>
    </div>
  </woot-modal>
</template>
