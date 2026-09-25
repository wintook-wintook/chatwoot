<script>
// proyecto@asistente_agentes_ia — LA BITÁCORA (pestaña «Cambios»)
// ============================================================================
// Qué cambió en cada versión del Entrenamiento, quién y cuándo, de la más nueva a
// la más vieja. Para ver el texto de una versión o volver a ella: «Versiones».
// ============================================================================
import { logEntries, changeLogMarkdown } from './changeLog';
import { downloadMarkdown } from './engineCatalogMarkdown';

const SOURCE_STYLE = {
  saved: 'bg-green-50 text-green-700 dark:bg-green-900/20 dark:text-green-300',
  assistant: 'bg-woot-50 text-woot-700 dark:bg-woot-800/40 dark:text-woot-200',
};

export default {
  props: {
    versions: { type: Array, default: () => [] },
    title: { type: String, default: '' },
  },
  computed: {
    entries() {
      return logEntries(this.versions);
    },
  },
  methods: {
    sourceClass(source) {
      return (
        SOURCE_STYLE[source] ||
        'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300'
      );
    },
    formatDate(value) {
      if (!value) return '';
      return new Date(value).toLocaleString(undefined, {
        day: '2-digit',
        month: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    label(key, args) {
      return this.$t(`TRACKING_ASSISTANT_VIEW.${key}`, args);
    },
    download() {
      const md = changeLogMarkdown(
        this.versions,
        (k, a) => this.label(k, a),
        this.formatDate,
        this.title
      );
      downloadMarkdown(md, 'bitacora_entrenamiento.md');
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-2 text-xs">
    <div class="flex items-center justify-between gap-2 shrink-0">
      <p class="!m-0 text-slate-500 dark:text-slate-400">
        {{ label('LOG_HINT') }}
      </p>
      <woot-button
        v-if="entries.length"
        size="tiny"
        variant="smooth"
        color-scheme="secondary"
        icon="arrow-download"
        @click="download"
      >
        {{ label('LOG_DOWNLOAD') }}
      </woot-button>
    </div>
    <p v-if="!entries.length" class="!m-0 text-slate-600 dark:text-slate-300">
      {{ label('LOG_EMPTY') }}
    </p>
    <div class="flex-1 min-h-0 overflow-y-auto">
      <div
        v-for="entry in entries"
        :key="entry.n"
        class="py-2 border-b border-slate-100 dark:border-slate-700"
      >
        <div class="flex flex-wrap items-center gap-2">
          <span class="tabular-nums text-slate-500 dark:text-slate-400">
            {{ formatDate(entry.at) }}
          </span>
          <span class="px-1.5 rounded" :class="sourceClass(entry.source)">
            {{ label(`LOG_SOURCE_${entry.source.toUpperCase()}`) }}
          </span>
          <span class="text-slate-500 dark:text-slate-400">
            {{ label('LOG_VERSION', { n: entry.n }) }}
          </span>
          <span
            v-if="entry.added !== null"
            class="tabular-nums text-slate-500 dark:text-slate-400"
          >
            {{
              label('LOG_LINES', { added: entry.added, removed: entry.removed })
            }}
          </span>
        </div>
        <p
          v-if="entry.summary"
          class="!m-0 mt-1 text-slate-700 dark:text-slate-200"
        >
          {{ entry.summary }}
        </p>
        <ul v-if="entry.changes.length" class="!m-0 mt-1 pl-4 list-disc">
          <li
            v-for="cambio in entry.changes"
            :key="cambio"
            class="font-mono text-slate-700 dark:text-slate-200"
          >
            {{ cambio }}
          </li>
        </ul>
        <ul
          v-if="entry.notes.length"
          class="!m-0 mt-1 pl-4 list-disc text-slate-500 dark:text-slate-400"
        >
          <li v-for="nota in entry.notes" :key="nota">{{ nota }}</li>
        </ul>
      </div>
    </div>
  </div>
</template>
