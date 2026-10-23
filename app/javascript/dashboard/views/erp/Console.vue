<!--
  @query_databases — Consola ERP. "Conversar con la BD" en modo solo lectura:
  el agente elige conexión + consulta predefinida, llena parámetros y ejecuta.
  Tailwind + dark mode, estilo del módulo de tickets.
-->
<script>
import { mapGetters } from 'vuex';

export default {
  data() {
    return {
      connectionId: null,
      queryId: null,
      paramValues: {},
      result: null,
      error: null,
      question: '',
      aiAnswer: null,
      // proyecto@erp_productos — "Probar como el agente"
      agentMessage: '',
      agentResult: null,
      agentError: null,
    };
  },
  computed: {
    ...mapGetters({
      catalog: 'externalDb/getCatalog',
      uiFlags: 'externalDb/getUIFlags',
    }),
    isRunning() {
      return this.uiFlags.runningQuery;
    },
    selectedConnection() {
      return this.catalog.find(c => c.id === this.connectionId);
    },
    queries() {
      return this.selectedConnection ? this.selectedConnection.queries : [];
    },
    selectedQuery() {
      return this.queries.find(q => q.id === this.queryId);
    },
    paramsSchema() {
      return this.selectedQuery ? this.selectedQuery.params_schema || [] : [];
    },
    // Una consulta de búsqueda (con texto libre) se puede probar como la usaría el agente.
    isSearchQuery() {
      return this.paramsSchema.some(p => p.type === 'words');
    },
  },
  watch: {
    queryId() {
      this.paramValues = {};
      this.result = null;
      this.error = null;
      this.agentResult = null;
      this.agentError = null;
    },
  },
  async mounted() {
    await this.$store.dispatch('externalDb/fetchCatalog');
    if (this.catalog.length) {
      this.connectionId = this.catalog[0].id;
      this.onConnectionChange();
    }
  },
  methods: {
    onConnectionChange() {
      this.queryId = this.queries.length ? this.queries[0].id : null;
    },
    inputType(type) {
      if (type === 'integer' || type === 'number') return 'number';
      if (type === 'date') return 'date';
      return 'text';
    },
    formatCell(value) {
      if (value === null || value === undefined) return '—';
      return value;
    },
    async run() {
      this.error = null;
      this.result = null;
      try {
        this.result = await this.$store.dispatch('externalDb/runQuery', {
          queryId: this.queryId,
          params: this.paramValues,
        });
      } catch (e) {
        this.error = e.response?.data?.error || e.message;
      }
    },
    // proyecto@erp_productos — el mensaje de un cliente → la IA llena los "?" → la consulta.
    async tryAsAgent() {
      this.agentError = null;
      this.agentResult = null;
      try {
        this.agentResult = await this.$store.dispatch('externalDb/tryAsked', {
          queryId: this.queryId,
          message: this.agentMessage,
        });
      } catch (e) {
        this.agentError = e.response?.data?.error || e.message;
      }
    },
    async ask() {
      this.aiAnswer = null;
      try {
        this.aiAnswer = await this.$store.dispatch('externalDb/askQuestion', {
          connectionId: this.connectionId,
          question: this.question,
        });
      } catch (e) {
        this.aiAnswer = {
          answer: e.response?.data?.error || e.message,
          query_name: null,
        };
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <!-- Header -->
    <div
      class="flex items-center justify-between flex-shrink-0 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex flex-col">
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('ERP.CONSOLE.TITLE') }}
        </h1>
        <span class="text-sm text-slate-400 dark:text-slate-500">{{
          $t('ERP.CONSOLE.SUBTITLE')
        }}</span>
      </div>
    </div>

    <div
      v-if="!catalog.length"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      <span>{{ $t('ERP.CONSOLE.NO_CONNECTIONS') }}</span>
    </div>

    <div v-else class="flex-1 p-6 overflow-y-auto">
      <div class="flex flex-col w-full max-w-3xl gap-6 mx-auto">
        <!-- Modo A — consulta predefinida -->
        <section
          class="flex flex-col gap-4 p-5 bg-white border shadow-sm rounded-xl border-slate-100 dark:bg-slate-800 dark:border-slate-700"
        >
          <h2
            class="m-0 text-sm font-semibold text-slate-700 dark:text-slate-200"
          >
            {{ $t('ERP.CONSOLE.QUERY_TITLE') }}
          </h2>

          <!-- Conexión + consulta -->
          <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >
                {{ $t('ERP.CONSOLE.CONNECTION') }}
              </span>
              <select
                v-model="connectionId"
                class="w-full"
                @change="onConnectionChange"
              >
                <option v-for="c in catalog" :key="c.id" :value="c.id">
                  {{ c.name }}
                </option>
              </select>
            </label>
            <label class="flex flex-col gap-1">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >
                {{ $t('ERP.CONSOLE.QUERY') }}
              </span>
              <select
                v-model="queryId"
                class="w-full"
                :disabled="!queries.length"
              >
                <option v-for="q in queries" :key="q.id" :value="q.id">
                  {{ q.name }}{{ q.description ? ` — ${q.description}` : '' }}
                </option>
              </select>
            </label>
          </div>

          <p
            v-if="selectedConnection && !queries.length"
            class="text-sm text-slate-400 dark:text-slate-500"
          >
            {{ $t('ERP.CONSOLE.NO_QUERIES') }}
          </p>

          <!-- Parámetros dinámicos -->
          <div v-if="paramsSchema.length" class="flex flex-col gap-3">
            <span
              class="text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
            >
              {{ $t('ERP.CONSOLE.PARAMS') }}
            </span>
            <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
              <label
                v-for="p in paramsSchema"
                :key="p.key"
                class="flex flex-col gap-1"
              >
                <span class="text-sm text-slate-600 dark:text-slate-300">
                  {{ p.label || p.key
                  }}<span v-if="p.required" class="text-red-500"> *</span>
                </span>
                <!-- proyecto@erp_productos: sí/no como selector -->
                <select
                  v-if="p.type === 'boolean'"
                  v-model="paramValues[p.key]"
                  class="w-full"
                >
                  <option value="">—</option>
                  <option value="si">{{ $t('ERP.CONSOLE.YES') }}</option>
                  <option value="no">{{ $t('ERP.CONSOLE.NO') }}</option>
                </select>
                <input
                  v-else
                  v-model="paramValues[p.key]"
                  :type="inputType(p.type)"
                  class="w-full"
                  :placeholder="p.key"
                />
              </label>
            </div>
          </div>

          <div>
            <woot-button
              :is-loading="isRunning"
              :disabled="!queryId"
              icon="arrow-right"
              @click="run"
            >
              {{
                isRunning ? $t('ERP.CONSOLE.RUNNING') : $t('ERP.CONSOLE.RUN')
              }}
            </woot-button>
          </div>

          <!-- Error -->
          <div
            v-if="error"
            class="px-4 py-3 text-sm border rounded-lg text-red-700 bg-red-50 border-red-100 dark:bg-red-900/20 dark:border-red-800 dark:text-red-300"
          >
            {{ $t('ERP.CONSOLE.ERROR', { error }) }}
          </div>

          <!-- Resultado -->
          <div
            v-if="result"
            class="flex flex-col gap-2 pt-4 border-t border-slate-100 dark:border-slate-700"
          >
            <div class="flex items-center gap-3">
              <span
                class="text-sm font-semibold text-slate-700 dark:text-slate-200"
              >
                {{ $t('ERP.CONSOLE.RESULT') }}
              </span>
              <span class="text-xs text-slate-400 dark:text-slate-500">
                {{
                  $t('ERP.CONSOLE.META', {
                    count: result.row_count,
                    ms: result.duration_ms,
                  })
                }}
              </span>
            </div>

            <div
              v-if="!result.rows.length"
              class="text-sm text-slate-400 dark:text-slate-500"
            >
              {{ $t('ERP.CONSOLE.EMPTY_RESULT') }}
            </div>
            <div
              v-else
              class="overflow-auto border rounded-lg border-slate-100 dark:border-slate-700"
            >
              <table class="min-w-full text-sm">
                <thead class="bg-slate-50 dark:bg-slate-800">
                  <tr>
                    <th
                      v-for="col in result.columns"
                      :key="col"
                      class="px-3 py-2 font-semibold text-left text-slate-600 dark:text-slate-300 whitespace-nowrap"
                    >
                      {{ col }}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="(row, i) in result.rows"
                    :key="i"
                    class="border-t border-slate-50 dark:border-slate-800"
                  >
                    <td
                      v-for="col in result.columns"
                      :key="col"
                      class="px-3 py-1.5 text-slate-700 dark:text-slate-200 whitespace-nowrap"
                    >
                      {{ formatCell(row[col]) }}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <details class="mt-1">
              <summary
                class="text-xs cursor-pointer text-slate-400 dark:text-slate-500"
              >
                {{ $t('ERP.CONSOLE.SQL_PREVIEW') }}
              </summary>
              <pre
                class="p-3 mt-1 overflow-auto font-mono text-xs rounded bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-200"
                >{{ result.query.sql_preview }}</pre
              >
            </details>
          </div>
        </section>

        <!-- proyecto@erp_productos — "Probar como el agente": lo que haría un agente con
             {{consulta:…(texto=?, precio_max=?, …)}} ante este mensaje. -->
        <section
          v-if="isSearchQuery"
          class="flex flex-col gap-4 p-5 bg-white border shadow-sm rounded-xl border-slate-100 dark:bg-slate-800 dark:border-slate-700"
        >
          <div class="flex flex-col gap-1">
            <h2
              class="m-0 text-sm font-semibold text-slate-700 dark:text-slate-200"
            >
              {{ $t('ERP.CONSOLE.AGENT_TITLE') }}
            </h2>
            <span class="text-xs text-slate-500 dark:text-slate-400">
              {{ $t('ERP.CONSOLE.AGENT_HINT') }}
            </span>
          </div>
          <textarea
            v-model="agentMessage"
            rows="2"
            class="w-full !mb-0"
            :placeholder="$t('ERP.CONSOLE.AGENT_PLACEHOLDER')"
          />
          <div>
            <woot-button
              :is-loading="isRunning"
              :disabled="!agentMessage.trim()"
              icon="chat"
              @click="tryAsAgent"
            >
              {{ $t('ERP.CONSOLE.AGENT_RUN') }}
            </woot-button>
          </div>

          <div
            v-if="agentError"
            class="px-4 py-3 text-sm border rounded-lg text-red-700 bg-red-50 border-red-100 dark:bg-red-900/20 dark:border-red-800 dark:text-red-300"
          >
            {{ $t('ERP.CONSOLE.ERROR', { error: agentError }) }}
          </div>

          <div
            v-if="agentResult"
            class="flex flex-col gap-2 pt-4 border-t border-slate-100 dark:border-slate-700"
          >
            <p
              v-if="!agentResult.use"
              class="m-0 text-sm text-slate-500 dark:text-slate-400"
            >
              {{ $t('ERP.CONSOLE.AGENT_NOT_USED') }}
            </p>
            <template v-else>
              <div class="flex flex-wrap items-center gap-2 text-xs">
                <span class="font-semibold text-slate-600 dark:text-slate-300">
                  {{ $t('ERP.CONSOLE.AGENT_FILLED') }}
                </span>
                <span
                  v-for="(value, key) in agentResult.params"
                  :key="key"
                  class="px-2 py-0.5 rounded-full bg-woot-50 text-woot-700 dark:bg-woot-800/40 dark:text-woot-200"
                >
                  {{ key }} = {{ value }}
                </span>
                <span
                  v-if="agentResult.partial"
                  class="px-2 py-0.5 rounded-full bg-amber-50 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300"
                >
                  {{ $t('ERP.CONSOLE.AGENT_PARTIAL') }}
                </span>
              </div>
              <p
                v-if="!agentResult.rows.length"
                class="m-0 text-sm text-slate-400 dark:text-slate-500"
              >
                {{ $t('ERP.CONSOLE.EMPTY_RESULT') }}
              </p>
              <div
                v-else
                class="overflow-auto border rounded-lg border-slate-100 dark:border-slate-700"
              >
                <table class="min-w-full text-sm">
                  <thead class="bg-slate-50 dark:bg-slate-800">
                    <tr>
                      <th
                        v-for="col in agentResult.columns"
                        :key="col"
                        class="px-3 py-2 font-semibold text-left text-slate-600 dark:text-slate-300 whitespace-nowrap"
                      >
                        {{ col }}
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr
                      v-for="(row, i) in agentResult.rows"
                      :key="i"
                      class="border-t border-slate-50 dark:border-slate-800"
                    >
                      <td
                        v-for="col in agentResult.columns"
                        :key="col"
                        class="px-3 py-1.5 text-slate-700 dark:text-slate-200 whitespace-nowrap"
                      >
                        {{ formatCell(row[col]) }}
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </template>
          </div>
        </section>

        <!-- Modo B — pregunta en lenguaje natural (IA) -->
        <section
          class="flex flex-col gap-3 p-5 bg-white border shadow-sm rounded-xl border-slate-100 dark:bg-slate-800 dark:border-slate-700"
        >
          <h2
            class="m-0 text-sm font-semibold text-slate-700 dark:text-slate-200"
          >
            {{ $t('ERP.CONSOLE.ASK_TITLE') }}
          </h2>
          <div class="flex gap-2">
            <input
              v-model="question"
              type="text"
              class="flex-1"
              :placeholder="$t('ERP.CONSOLE.ASK_PLACEHOLDER')"
              @keyup.enter="ask"
            />
            <woot-button
              :is-loading="isRunning"
              :disabled="!question || !connectionId"
              icon="chat-multiple"
              @click="ask"
            >
              {{ $t('ERP.CONSOLE.ASK_BUTTON') }}
            </woot-button>
          </div>
          <div
            v-if="aiAnswer"
            class="p-4 text-sm border rounded-lg bg-woot-25 dark:bg-slate-900/40 border-woot-100 dark:border-slate-700"
          >
            <p
              class="m-0 mb-1 text-xs font-semibold text-slate-500 dark:text-slate-400"
            >
              {{ $t('ERP.CONSOLE.ASK_ANSWER') }}
            </p>
            <p
              class="m-0 whitespace-pre-line text-slate-700 dark:text-slate-100"
            >
              {{ aiAnswer.answer }}
            </p>
            <p
              v-if="aiAnswer.query_name"
              class="m-0 mt-2 text-xs text-slate-400 dark:text-slate-500"
            >
              {{
                $t('ERP.CONSOLE.ASK_QUERY_USED', { name: aiAnswer.query_name })
              }}
            </p>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>
