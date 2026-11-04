<script>
// proyecto@crear_agente_conversando §15 — «PROBAR FUENTES»
// ============================================================================
// Plan: docs/creacion_conversacional_agentes_plan.md §15. Elegir una fuente del
// agente (una directiva de su Entrenamiento), escribir una frase como la escribiría
// un cliente y ver qué encuentra el agente, con el umbral QUE USA AHÍ (el del grupo o
// el de la cuenta) y su tope: qué tomaría y qué quedó fuera, y por qué. La búsqueda
// la hace el backend igual que el motor (SourceProbe).
//
// P1: búsqueda por parecido. Hojas exactas, ERP y fuentes en vivo salen en la lista y
// avisan que se prueban en la siguiente fase.
// ============================================================================
import AssistantAPI from 'dashboard/api/assistant';

const MAX_HISTORY = 6;

export default {
  props: {
    // El Entrenamiento abierto (el borrador): de ahí salen sus directivas.
    draft: { type: String, default: '' },
    // Si la pestaña está a la vista: las directivas se vuelven a leer al entrar.
    active: { type: Boolean, default: false },
  },
  data() {
    return {
      directives: [],
      selected: null,
      phrase: '',
      result: null,
      history: [],
      isLoading: false,
      isRunning: false,
      loadError: false,
    };
  },
  computed: {
    current() {
      return this.directives[this.selected] || null;
    },
    fromAccount() {
      return this.directives.some(d => d.from_account);
    },
    canRun() {
      return Boolean(this.current && this.phrase.trim() && !this.isRunning);
    },
    results() {
      return (this.result && this.result.results) || [];
    },
    thresholdPercent() {
      return this.result ? Math.round(this.result.threshold * 100) : 0;
    },
    summary() {
      if (!this.result || this.result.threshold === undefined) return '';
      return this.$t('TRACKING_ASSISTANT_VIEW.PROBE.SUMMARY', {
        threshold: this.result.threshold,
        from: this.$t(
          `TRACKING_ASSISTANT_VIEW.PROBE.FROM_${this.result.threshold_from.toUpperCase()}`
        ),
        max: this.result.max_results,
        used: this.result.used,
      });
    },
  },
  watch: {
    active: {
      immediate: true,
      handler(visible) {
        if (visible) this.load();
      },
    },
  },
  methods: {
    async load() {
      this.isLoading = true;
      this.loadError = false;
      const antes = this.current && this.current.directive;
      try {
        const { data } = await AssistantAPI.sourceProbe(this.draft);
        this.directives = data.directives || [];
        const donde = this.directives.findIndex(d => d.directive === antes);
        this.selected = donde >= 0 ? donde : this.firstTestable();
      } catch (error) {
        this.loadError = true;
      } finally {
        this.isLoading = false;
      }
    },
    firstTestable() {
      if (!this.directives.length) return null;
      const donde = this.directives.findIndex(d => d.kind === 'similarity');
      return donde >= 0 ? donde : 0;
    },
    optionLabel(item) {
      const rutas = (item.routes || []).length
        ? this.$t('TRACKING_ASSISTANT_VIEW.PROBE.ROUTES', {
            routes: item.routes.join(', '),
          })
        : '';
      let lista = '';
      if (item.items === 0)
        lista = ` · ${this.$t('TRACKING_ASSISTANT_VIEW.PROBE.EMPTY')}`;
      else if (!item.ready)
        lista = ` · ${this.$t('TRACKING_ASSISTANT_VIEW.PROBE.NOT_READY')}`;
      return `${item.directive}${rutas ? ` — ${rutas}` : ''}${lista}`;
    },
    async run(frase = this.phrase) {
      if (!this.current || !frase.trim() || this.isRunning) return;
      this.phrase = frase;
      this.isRunning = true;
      try {
        const { data } = await AssistantAPI.sourceProbeRun(
          this.current.directive,
          frase
        );
        this.result = data;
        this.remember(frase);
      } catch (error) {
        const datos = (error && error.response && error.response.data) || {};
        const codigo = datos.error || 'failed';
        this.result = { error: codigo };
      } finally {
        this.isRunning = false;
      }
    },
    remember(frase) {
      const limpia = frase.trim();
      this.history = [
        limpia,
        ...this.history.filter(f => f.toLowerCase() !== limpia.toLowerCase()),
      ].slice(0, MAX_HISTORY);
    },
    percent(valor) {
      return Math.max(0, Math.min(100, Math.round(valor * 100)));
    },
    badge(item) {
      if (item.used) return this.$t('TRACKING_ASSISTANT_VIEW.PROBE.USED');
      return this.$t(
        `TRACKING_ASSISTANT_VIEW.PROBE.REASON_${item.reason.toUpperCase()}`
      );
    },
    barClass(item) {
      if (!item.used) return 'bg-slate-300 dark:bg-slate-600';
      return item.weak ? 'bg-amber-400' : 'bg-green-500';
    },
    errorText(codigo) {
      return this.$t(
        `TRACKING_ASSISTANT_VIEW.PROBE.ERROR_${codigo.toUpperCase()}`
      );
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-4 text-sm">
    <div>
      <h3
        class="!mb-1 text-sm font-semibold text-slate-800 dark:text-slate-100"
      >
        {{ $t('TRACKING_ASSISTANT_VIEW.PROBE.TITLE') }}
      </h3>
      <p class="!m-0 text-xs text-slate-600 dark:text-slate-300">
        {{ $t('TRACKING_ASSISTANT_VIEW.PROBE.HINT') }}
      </p>
    </div>

    <p v-if="loadError" class="!m-0 text-red-600 dark:text-red-400">
      {{ $t('TRACKING_ASSISTANT_VIEW.PROBE.LOAD_ERROR') }}
    </p>
    <p
      v-else-if="!isLoading && !directives.length"
      class="!m-0 text-slate-500 dark:text-slate-400"
    >
      {{ $t('TRACKING_ASSISTANT_VIEW.PROBE.NO_SOURCES') }}
    </p>

    <div v-if="directives.length" class="flex flex-col gap-3">
      <div>
        <label
          for="probe-source"
          class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.PROBE.SOURCE') }}
        </label>
        <select
          id="probe-source"
          v-model="selected"
          class="w-full !mb-0 font-mono text-xs"
          @change="result = null"
        >
          <option
            v-for="(item, index) in directives"
            :key="item.directive"
            :value="index"
          >
            {{ optionLabel(item) }}
          </option>
        </select>
        <p
          v-if="fromAccount"
          class="!mt-1 !mb-0 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.PROBE.FROM_ACCOUNT_HINT') }}
        </p>
      </div>

      <p
        v-if="current && current.kind !== 'similarity'"
        class="!m-0 px-3 py-2 text-xs rounded-md bg-slate-50 dark:bg-slate-700 text-slate-600 dark:text-slate-300"
      >
        {{
          $t(`TRACKING_ASSISTANT_VIEW.PROBE.KIND_${current.kind.toUpperCase()}`)
        }}
      </p>

      <div v-else class="flex flex-col gap-2">
        <label
          for="probe-phrase"
          class="!mb-0 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_ASSISTANT_VIEW.PROBE.PHRASE') }}
        </label>
        <div class="flex gap-2">
          <input
            id="probe-phrase"
            v-model="phrase"
            type="text"
            class="flex-1 !mb-0"
            :placeholder="$t('TRACKING_ASSISTANT_VIEW.PROBE.PHRASE_HINT')"
            @keydown.enter="run()"
          />
          <woot-button
            icon="search"
            :is-loading="isRunning"
            :is-disabled="!canRun"
            @click="run()"
          >
            {{ $t('TRACKING_ASSISTANT_VIEW.PROBE.RUN') }}
          </woot-button>
        </div>
        <div v-if="history.length" class="flex flex-wrap gap-1">
          <button
            v-for="frase in history"
            :key="frase"
            type="button"
            class="px-2 py-0.5 text-xs rounded-full bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-600"
            @click="run(frase)"
          >
            {{ frase }}
          </button>
        </div>
      </div>
    </div>

    <p
      v-if="result && result.error"
      class="!m-0 text-amber-800 dark:text-amber-800"
    >
      {{ errorText(result.error) }}
    </p>

    <div
      v-else-if="result && result.threshold !== undefined"
      class="flex flex-col min-h-0 gap-3"
    >
      <div class="flex flex-col gap-1">
        <p class="!m-0 text-xs text-slate-700 dark:text-slate-200">
          {{ summary }}
        </p>
        <div
          class="relative w-full h-1.5 rounded-full bg-slate-100 dark:bg-slate-700"
        >
          <span
            class="absolute top-[-3px] w-0.5 h-3 bg-woot-500"
            :style="{ left: `${thresholdPercent}%` }"
          />
        </div>
      </div>

      <p v-if="!results.length" class="!m-0 text-slate-500 dark:text-slate-400">
        {{ $t('TRACKING_ASSISTANT_VIEW.PROBE.NOTHING') }}
      </p>
      <div class="flex flex-col min-h-0 gap-2 overflow-y-auto">
        <div
          v-for="(item, index) in results"
          :key="`${index}-${item.title}`"
          class="flex flex-col gap-1 p-3 border rounded-md border-slate-100 dark:border-slate-700"
          :class="item.used ? '' : 'opacity-70'"
        >
          <div class="flex items-center gap-2">
            <span class="text-xs text-slate-400">{{ `#${index + 1}` }}</span>
            <span
              class="flex-1 min-w-0 font-medium truncate text-slate-800 dark:text-slate-100"
            >
              {{ item.title || '—' }}
            </span>
            <span
              class="text-xs font-semibold tabular-nums text-slate-700 dark:text-slate-200"
            >
              {{ item.similarity.toFixed(2) }}
            </span>
            <span
              class="px-1.5 py-0.5 text-xs rounded"
              :class="
                item.used
                  ? 'bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-300'
                  : 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300'
              "
            >
              {{ badge(item) }}
            </span>
            <span
              v-if="item.used && item.weak"
              class="px-1.5 py-0.5 text-xs rounded bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-800"
            >
              {{ $t('TRACKING_ASSISTANT_VIEW.PROBE.WEAK') }}
            </span>
          </div>
          <div
            class="relative w-full h-1.5 rounded-full bg-slate-100 dark:bg-slate-700"
          >
            <div
              class="h-1.5 rounded-full"
              :class="barClass(item)"
              :style="{ width: `${percent(item.similarity)}%` }"
            />
            <span
              class="absolute top-[-3px] w-0.5 h-3 bg-woot-500"
              :style="{ left: `${thresholdPercent}%` }"
            />
          </div>
          <p
            class="!m-0 text-xs text-slate-600 dark:text-slate-300 line-clamp-2"
          >
            {{ item.excerpt }}
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
