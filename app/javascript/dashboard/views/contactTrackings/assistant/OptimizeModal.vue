<script>
// proyecto@asistente_agentes_ia — fase E de PROMPT STUDIO (§29)
// ============================================================================
// Optimizar: hallazgos y un Entrenamiento propuesto, que NUNCA se aplica solo.
//
// Lo que se muestra antes de decidir, en este orden:
//   1. las reglas que la propuesta pierde (LostRules) — lo que más cuesta ver
//   2. lo que hubo que devolver (ruteo, secciones borradas)
//   3. los hallazgos del modelo
//   4. el diff
// Si pierde reglas, la opción principal es la versión que no pierde ninguna.
// ============================================================================
import { diffHunks } from './lineDiff';

export default {
  props: {
    show: { type: Boolean, default: false },
    // { findings, summary, proposed_draft, safe_draft, lost_rules, restored,
    //   stats, discarded, version } o null.
    result: { type: Object, default: null },
    isRunning: { type: Boolean, default: false },
    error: { type: String, default: '' },
    draft: { type: String, default: '' },
    draftVersion: { type: Number, default: 0 },
  },
  emits: ['close', 'run', 'apply'],
  data() {
    return { showSafe: true };
  },
  computed: {
    lostRules() {
      return this.result?.lost_rules || [];
    },
    hasSafe() {
      return Boolean(this.result?.safe_draft);
    },
    // La que se está mirando en el diff.
    shown() {
      if (!this.result?.proposed_draft) return null;
      return this.hasSafe && this.showSafe
        ? this.result.safe_draft
        : this.result.proposed_draft;
    },
    hunks() {
      return this.shown ? diffHunks(this.draft, this.shown) : [];
    },
    // Si el Entrenamiento cambió después de analizar, aplicar pisaría esos cambios.
    isStale() {
      return Boolean(this.result) && this.result.version !== this.draftVersion;
    },
  },
  watch: {
    result() {
      this.showSafe = true;
    },
  },
};
</script>

<template>
  <woot-modal :show="show" size="dry-run-wide" :on-close="() => $emit('close')">
    <div class="flex flex-col gap-3 p-8 h-[80vh] text-sm">
      <div class="shrink-0">
        <h2 class="mb-1 text-lg font-medium text-slate-800 dark:text-slate-100">
          {{ $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_TITLE') }}
        </h2>
        <p class="!m-0 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_HINT') }}
        </p>
      </div>

      <div class="flex flex-col flex-1 min-h-0 gap-3 overflow-y-auto text-xs">
        <p v-if="error" class="!m-0 text-red-600 dark:text-red-400">
          {{ error }}
        </p>
        <p v-if="isRunning" class="!m-0 text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_RUNNING') }}
        </p>

        <template v-if="result && !isRunning">
          <p
            v-if="result.summary"
            class="!m-0 text-slate-700 dark:text-slate-200"
          >
            {{ result.summary }}
          </p>
          <p v-if="isStale" class="!m-0 text-amber-800 dark:text-amber-800">
            {{ $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_STALE') }}
          </p>
          <p
            v-if="result.discarded === 'worse'"
            class="!m-0 text-amber-800 dark:text-amber-800"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_DISCARDED_WORSE') }}
          </p>
          <p
            v-else-if="result.discarded === 'empty'"
            class="!m-0 text-slate-500 dark:text-slate-400"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_NOTHING') }}
          </p>

          <div
            v-if="lostRules.length"
            class="flex flex-col gap-1 p-3 border rounded border-red-200 bg-red-50 text-red-900 dark:bg-red-900/30 dark:border-red-800 dark:text-red-100"
          >
            <p class="!m-0 font-semibold">
              {{
                $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_LOST_TITLE', {
                  count: lostRules.length,
                })
              }}
            </p>
            <p class="!m-0">
              {{ $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_LOST_HINT') }}
            </p>
            <p
              v-for="(perdida, index) in lostRules"
              :key="index"
              class="!m-0 font-mono"
            >
              {{ perdida.section }} · {{ perdida.rule }}
            </p>
          </div>

          <p
            v-if="result.restored && result.restored.length"
            class="!m-0 text-slate-600 dark:text-slate-300"
          >
            {{
              $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_RESTORED', {
                keys: result.restored.join(' · '),
              })
            }}
          </p>

          <div v-if="result.findings && result.findings.length">
            <p
              class="!m-0 mb-1 font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_FINDINGS') }}
            </p>
            <p
              v-for="(hallazgo, index) in result.findings"
              :key="index"
              class="!m-0 mb-1"
            >
              <span
                class="px-1.5 py-0.5 mr-1 rounded bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
              >
                {{
                  $t(
                    `TRACKING_ASSISTANT_VIEW.OPTIMIZE_KIND_${hallazgo.kind.toUpperCase()}`
                  )
                }}
              </span>
              <span class="font-mono">{{ hallazgo.where }}</span>
              · {{ hallazgo.detail }}
            </p>
          </div>

          <div v-if="shown" class="flex flex-col gap-1">
            <div class="flex flex-wrap items-center gap-2">
              <p class="!m-0 font-semibold text-slate-800 dark:text-slate-100">
                {{ $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_DIFF') }}
              </p>
              <template v-if="hasSafe">
                <woot-button
                  size="tiny"
                  :variant="showSafe ? 'smooth' : 'clear'"
                  color-scheme="secondary"
                  @click="showSafe = true"
                >
                  {{ $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_SHOW_SAFE') }}
                </woot-button>
                <woot-button
                  size="tiny"
                  :variant="showSafe ? 'clear' : 'smooth'"
                  color-scheme="secondary"
                  @click="showSafe = false"
                >
                  {{ $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_SHOW_FULL') }}
                </woot-button>
              </template>
              <span
                v-if="result.stats"
                class="text-slate-500 dark:text-slate-400"
              >
                {{
                  $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_STATS', {
                    before: result.stats.chars_before,
                    after: (shown || '').length,
                  })
                }}
              </span>
            </div>
            <p class="!m-0 text-slate-500 dark:text-slate-400">
              {{ $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_ROUTING_NOTE') }}
            </p>
            <div class="overflow-x-auto rounded bg-slate-50 dark:bg-slate-900">
              <pre class="!m-0 p-2 font-mono text-xs leading-5"><template
                v-for="(line, lineIndex) in hunks"
              ><span
                v-if="line.type === 'skip'"
                :key="`s${lineIndex}`"
                class="block text-slate-400 dark:text-slate-500"
              >{{ $t('TRACKING_ASSISTANT_VIEW.VERSION_DIFF_SKIP', { count: line.count }) }}</span><span
                v-else
                :key="`l${lineIndex}`"
                class="block whitespace-pre-wrap"
                :class="{
                  'bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-200': line.type === 'del',
                  'bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200': line.type === 'add',
                }"
              >{{ line.type === 'del' ? '− ' : line.type === 'add' ? '+ ' : '  ' }}{{ line.text }}</span></template></pre>
            </div>
          </div>
        </template>
      </div>

      <div class="flex flex-wrap justify-end gap-2 shrink-0">
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click="$emit('close')"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_CLOSE') }}
        </woot-button>
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          :is-loading="isRunning"
          :is-disabled="isRunning || !draft.trim()"
          @click="$emit('run')"
        >
          {{
            result
              ? $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_RERUN')
              : $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_RUN')
          }}
        </woot-button>
        <template v-if="result && result.proposed_draft && !isRunning">
          <woot-button
            v-if="hasSafe"
            :is-disabled="isStale"
            @click="$emit('apply', result.safe_draft)"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_APPLY_SAFE') }}
          </woot-button>
          <woot-button
            :color-scheme="lostRules.length ? 'alert' : 'primary'"
            :variant="lostRules.length ? 'smooth' : 'solid'"
            :is-disabled="isStale"
            @click="$emit('apply', result.proposed_draft)"
          >
            {{
              lostRules.length
                ? $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_APPLY_ANYWAY', {
                    count: lostRules.length,
                  })
                : $t('TRACKING_ASSISTANT_VIEW.OPTIMIZE_APPLY')
            }}
          </woot-button>
        </template>
      </div>
    </div>
  </woot-modal>
</template>
