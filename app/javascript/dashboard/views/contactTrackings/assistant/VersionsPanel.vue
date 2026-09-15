<script>
// proyecto@asistente_agentes_ia — fase D de PROMPT STUDIO
// ============================================================================
// Las versiones del Entrenamiento en esta conversación, de la más nueva a la más
// vieja: cada entrega del asistente y cada tanda de edición a mano. Se puede ver
// qué la separa de lo que hay ahora en el editor, y volver a ella.
//
// La lista llega sin los textos (ver TrackingAssistantSession#version_list); el
// de cada versión se pide al compararla o restaurarla, y se guarda acá mientras
// dure la conversación.
// ============================================================================
import AssistantAPI from 'dashboard/api/assistant';
import { diffHunks, diffStats } from './lineDiff';

export default {
  props: {
    versions: { type: Array, default: () => [] },
    sessionId: { type: Number, default: null },
    currentDraft: { type: String, default: '' },
  },
  emits: ['restore'],
  data() {
    return { texts: {}, openNumber: null, loadingNumber: null, error: '' };
  },
  computed: {
    ordered() {
      return [...this.versions].reverse();
    },
    openText() {
      return this.openNumber === null ? null : this.texts[this.openNumber];
    },
    hunks() {
      return this.openText === undefined || this.openText === null
        ? []
        : diffHunks(this.openText, this.currentDraft);
    },
    openStats() {
      return this.openText ? diffStats(this.openText, this.currentDraft) : null;
    },
  },
  watch: {
    // Otra conversación: los textos guardados son de la anterior.
    sessionId() {
      this.texts = {};
      this.openNumber = null;
    },
  },
  methods: {
    async text(number) {
      if (this.texts[number] !== undefined) return this.texts[number];
      this.loadingNumber = number;
      this.error = '';
      try {
        const { data } = await AssistantAPI.getVersion(this.sessionId, number);
        this.$set(this.texts, number, data.draft || '');
        return this.texts[number];
      } catch (error) {
        this.error = this.$t('TRACKING_ASSISTANT_VIEW.VERSIONS_ERROR');
        return null;
      } finally {
        this.loadingNumber = null;
      }
    },
    async toggleCompare(number) {
      if (this.openNumber === number) {
        this.openNumber = null;
        return;
      }
      const texto = await this.text(number);
      if (texto !== null) this.openNumber = number;
    },
    async restore(version) {
      const texto = await this.text(version.n);
      if (texto !== null)
        this.$emit('restore', { number: version.n, draft: texto });
    },
    sourceLabel(source) {
      return this.$t(
        `TRACKING_ASSISTANT_VIEW.VERSION_SOURCE_${String(source).toUpperCase()}`
      );
    },
    time(iso) {
      const date = new Date(iso);
      return Number.isNaN(date.getTime())
        ? ''
        : date.toLocaleString([], {
            day: '2-digit',
            month: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
          });
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-2 overflow-y-auto text-xs">
    <p v-if="!versions.length" class="!m-0 text-slate-500 dark:text-slate-400">
      {{ $t('TRACKING_ASSISTANT_VIEW.VERSIONS_EMPTY') }}
    </p>
    <p v-if="error" class="!m-0 text-red-600 dark:text-red-400">{{ error }}</p>

    <div
      v-for="(version, index) in ordered"
      :key="version.n"
      class="flex flex-col gap-1 p-2 border rounded border-slate-100 dark:border-slate-700"
    >
      <div class="flex flex-wrap items-center gap-2">
        <span class="font-mono font-semibold">
          {{
            $t('TRACKING_ASSISTANT_VIEW.VERSION_LABEL', { number: version.n })
          }}
        </span>
        <span
          class="px-1.5 py-0.5 rounded bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
        >
          {{ sourceLabel(version.source) }}
        </span>
        <span class="text-slate-400 dark:text-slate-500">
          {{ time(version.at) }}
        </span>
        <span class="text-slate-500 dark:text-slate-400">
          {{
            $t('TRACKING_ASSISTANT_VIEW.VERSION_ROUTES', {
              count: version.routes || 0,
            })
          }}
        </span>
        <span v-if="version.blocking" class="text-red-600 dark:text-red-400">
          {{
            $t('TRACKING_ASSISTANT_VIEW.REPORT_BLOCKING', {
              count: version.blocking,
            })
          }}
        </span>
        <span v-if="index === 0" class="text-slate-400 dark:text-slate-500">
          {{ $t('TRACKING_ASSISTANT_VIEW.VERSION_LATEST') }}
        </span>
      </div>
      <p
        v-if="version.summary"
        class="!m-0 text-slate-700 dark:text-slate-200 truncate"
        :title="version.summary"
      >
        {{ version.summary }}
      </p>
      <div class="flex gap-2">
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          :is-loading="loadingNumber === version.n"
          @click="toggleCompare(version.n)"
        >
          {{
            openNumber === version.n
              ? $t('TRACKING_ASSISTANT_VIEW.VERSION_HIDE_DIFF')
              : $t('TRACKING_ASSISTANT_VIEW.VERSION_COMPARE')
          }}
        </woot-button>
        <woot-button size="tiny" variant="smooth" @click="restore(version)">
          {{ $t('TRACKING_ASSISTANT_VIEW.VERSION_RESTORE') }}
        </woot-button>
      </div>

      <div v-if="openNumber === version.n" class="flex flex-col gap-1">
        <p class="!m-0 text-slate-500 dark:text-slate-400">
          {{
            openStats && (openStats.added || openStats.removed)
              ? $t('TRACKING_ASSISTANT_VIEW.VERSION_DIFF_STATS', openStats)
              : $t('TRACKING_ASSISTANT_VIEW.VERSION_DIFF_SAME')
          }}
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
    </div>
  </div>
</template>
