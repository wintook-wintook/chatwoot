<script>
// proyecto@crear_agente_conversando §15 P3 — EL RESULTADO DE UNA FUENTE EN VIVO
// ============================================================================
// Lo que regresa SourceProbeLive:
//   foro / @discourse   los temas que encontró (semántica o búsqueda normal con los
//                       términos que sacó la IA) y cuáles tomaría el agente (los 3 primeros)
//   CONTPAQi            la respuesta ya escrita por su servicio, con sus fuentes
// ============================================================================
const K = 'TRACKING_ASSISTANT_VIEW.PROBE.';

export default {
  props: {
    result: { type: Object, required: true },
  },
  computed: {
    isForum() {
      return this.result.service === 'forum';
    },
    header() {
      if (!this.isForum) {
        return this.$t(`${K}CONTPAQ_${this.result.status.toUpperCase()}`, {
          reason: this.result.reason || '',
        });
      }
      if (this.result.status === 'no_results')
        return this.$t(`${K}FORUM_NO_RESULTS`);
      return this.$t(`${K}FORUM_${this.result.mode.toUpperCase()}`, {
        terms: (this.result.terms || []).join(' · '),
        max: this.result.max_results,
      });
    },
    results() {
      return this.result.results || [];
    },
    sources() {
      return (this.result.sources || []).filter(s => s.title);
    },
  },
};
</script>

<template>
  <div class="flex flex-col min-h-0 gap-3 text-sm">
    <p class="!m-0 text-xs text-slate-700 dark:text-slate-200">
      {{ header }}
    </p>

    <div
      v-if="isForum && results.length"
      class="flex flex-col min-h-0 gap-2 overflow-y-auto"
    >
      <div
        v-for="(item, index) in results"
        :key="`${index}-${item.url}`"
        class="flex flex-col gap-1 p-3 border rounded-md border-slate-100 dark:border-slate-700"
        :class="item.used ? '' : 'opacity-70'"
      >
        <div class="flex items-center gap-2">
          <span class="text-xs text-slate-400">{{ `#${index + 1}` }}</span>
          <a
            :href="item.url"
            target="_blank"
            rel="noopener noreferrer"
            class="flex-1 min-w-0 font-medium truncate text-woot-600 dark:text-woot-400 hover:underline"
          >
            {{ item.title }}
          </a>
          <span
            class="px-1.5 py-0.5 text-xs rounded"
            :class="
              item.used
                ? 'bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-300'
                : 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300'
            "
          >
            {{
              item.used
                ? $t('TRACKING_ASSISTANT_VIEW.PROBE.USED')
                : $t('TRACKING_ASSISTANT_VIEW.PROBE.REASON_OVER_LIMIT')
            }}
          </span>
        </div>
        <p class="!m-0 text-xs text-slate-600 dark:text-slate-300 line-clamp-2">
          {{ item.excerpt }}
        </p>
      </div>
    </div>

    <template v-if="!isForum && result.answer">
      <p
        class="!m-0 px-3 py-2 whitespace-pre-line rounded-md bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100"
      >
        {{ result.answer }}
      </p>
      <div v-if="sources.length" class="flex flex-col gap-0.5">
        <span class="text-xs text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_ASSISTANT_VIEW.PROBE.CONTPAQ_SOURCES') }}
        </span>
        <template v-for="fuente in sources">
          <a
            v-if="fuente.url"
            :key="fuente.title"
            :href="fuente.url"
            target="_blank"
            rel="noopener noreferrer"
            class="text-xs text-woot-600 dark:text-woot-400 hover:underline"
          >
            {{ fuente.title }}
          </a>
          <span
            v-else
            :key="fuente.title"
            class="text-xs text-slate-600 dark:text-slate-300"
          >
            {{ fuente.title }}
          </span>
        </template>
      </div>
    </template>
  </div>
</template>
