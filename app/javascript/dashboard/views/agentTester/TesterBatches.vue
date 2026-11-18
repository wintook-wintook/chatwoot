<script>
// Probador de agentes › Lotes: pruebas agrupadas (lo que escribe el cliente y lo que se espera)
// que se corren completas contra un agente 1.0 o 2.0, con el motor real en el canal de pruebas.
// proyecto@predefinidas_que_contestan: se corre con la búsqueda de predefinidas que se elija (la
// de la cuenta, la nueva o la de siempre) sin tocar la cuenta; «Comparar búsquedas» corre las dos;
// «Importar preguntas» arma un lote pegando filas de una hoja o con la pila vieja del agente.
import { useAlert } from 'dashboard/composables';
import AgentTestBatchesApi from 'dashboard/api/agentTestBatches';

export default {
  props: {
    agents: { type: Array, default: () => [] },
    batches: { type: Array, default: () => [] },
  },
  emits: ['changed'],
  data() {
    return {
      newName: '',
      open: null,
      form: { name: '', messages: '', expected: '' },
      runAgent: {},
      agentFilter: '',
      runningAll: false,
      timer: null,
      seleccion: '',
      selecciones: ['', 'on', 'off'],
      showImport: false,
      importText: '',
      importName: '',
      importing: false,
      importResult: null,
    };
  },
  computed: {
    // Los lotes del agente elegido (las correcciones de cada día y los propios); sin filtro, todos.
    shown() {
      if (!this.agentFilter) return this.batches;
      return this.batches.filter(
        b => b.template_id === Number(this.agentFilter)
      );
    },
  },
  // Mientras alguna corrida va, la tarjeta se actualiza sola (cada 4 s).
  mounted() {
    this.timer = setInterval(() => {
      if (this.batches.some(b => this.inProgress(b.last_run)))
        this.$emit('changed');
    }, 4000);
  },
  beforeDestroy() {
    clearInterval(this.timer);
  },
  methods: {
    inProgress(run) {
      return !!run && (run.status === 'queued' || run.status === 'running');
    },
    // Lo que se ve de la última corrida, bajo el nombre del lote.
    runLine(run) {
      if (this.inProgress(run))
        return this.t('PROGRESS', {
          agent: run.agent,
          n: Math.min(run.done + 1, run.total),
          total: run.total,
        });
      if (run.status === 'failed')
        return this.t('RUN_FAILED', { reason: run.error || this.t('ERROR') });
      return `${this.t('LAST_RUN', {
        agent: run.agent,
        passed: run.passed,
        total: run.total,
      })}${this.seleccionText(run)}`;
    },
    seleccionText(run) {
      return run && run.seleccion
        ? ` · ${this.t(`SELECCION.${run.seleccion.toUpperCase()}`)}`
        : '';
    },
    variablesText(variables) {
      return Object.entries(variables || {})
        .map(([k, v]) => `${k} = ${v}`)
        .join(' · ');
    },
    finishedResults(run) {
      return run && !this.inProgress(run) ? run.results || [] : [];
    },
    async runAll() {
      this.runningAll = true;
      try {
        await AgentTestBatchesApi.runCorrections(
          Number(this.agentFilter),
          this.seleccion
        );
        useAlert(this.t('RUNNING'));
        this.$emit('changed');
      } catch (e) {
        const data = e && e.response ? e.response.data : null;
        useAlert((data && data.error) || this.t('ERROR'));
      } finally {
        this.runningAll = false;
      }
    },
    t(key, args) {
      return this.$t(`AGENT_TESTER.BATCHES.${key}`, args);
    },
    async create() {
      if (!this.newName.trim()) return;
      await AgentTestBatchesApi.create({ name: this.newName.trim() });
      this.newName = '';
      this.$emit('changed');
    },
    async remove(batch) {
      // eslint-disable-next-line no-alert
      if (!window.confirm(this.t('DELETE_CONFIRM', { name: batch.name })))
        return;
      await AgentTestBatchesApi.delete(batch.id);
      this.$emit('changed');
    },
    async addCase(batch) {
      const messages = this.form.messages
        .split('\n')
        .map(m => m.trim())
        .filter(Boolean);
      if (!messages.length) return;
      try {
        await AgentTestBatchesApi.addCase(batch.id, {
          name: this.form.name || messages[0].slice(0, 60),
          messages,
          expected: this.form.expected,
        });
        this.form = { name: '', messages: '', expected: '' };
        this.$emit('changed');
      } catch (e) {
        useAlert(this.t('ERROR'));
      }
    },
    async removeCase(batch, testCase) {
      await AgentTestBatchesApi.removeCase(batch.id, testCase.id);
      this.$emit('changed');
    },
    async run(batch) {
      const templateId = Number(this.runAgent[batch.id]);
      if (!templateId) return;
      try {
        await AgentTestBatchesApi.run(batch.id, templateId, this.seleccion);
        useAlert(this.t('RUNNING'));
        this.$emit('changed');
      } catch (e) {
        const data = e && e.response ? e.response.data : null;
        useAlert((data && data.error) || this.t('ERROR'));
      }
    },
    // Las mismas pruebas con la búsqueda nueva y con la de siempre (dos corridas).
    async compare(batch) {
      const templateId = Number(this.runAgent[batch.id]);
      if (!templateId) return;
      try {
        await AgentTestBatchesApi.compare(batch.id, templateId);
        useAlert(this.t('COMPARING'));
        this.$emit('changed');
      } catch (e) {
        const data = e && e.response ? e.response.data : null;
        useAlert((data && data.error) || this.t('ERROR'));
      }
    },
    async importRows(pila = false) {
      const templateId = Number(this.agentFilter);
      if (!templateId || (!pila && !this.importText.trim())) return;
      this.importing = true;
      try {
        const { data } = pila
          ? await AgentTestBatchesApi.importPila(templateId)
          : await AgentTestBatchesApi.importRows(
              templateId,
              this.importText,
              this.importName.trim()
            );
        this.importResult = data;
        this.importText = '';
        this.importName = '';
        this.$emit('changed');
      } catch (e) {
        const data = e && e.response ? e.response.data : null;
        useAlert((data && data.error) || this.t('ERROR'));
      } finally {
        this.importing = false;
      }
    },
  },
};
</script>

<template>
  <div class="space-y-3 max-w-4xl">
    <p class="m-0 text-sm text-slate-500">{{ t('HINT') }}</p>
    <div class="flex flex-wrap items-center gap-2">
      <select v-model="agentFilter" class="!mb-0 h-9 text-sm w-64">
        <option value="">{{ t('ALL_AGENTS') }}</option>
        <option v-for="a in agents" :key="a.id" :value="a.id">
          {{
            $t('AGENT_TESTER.AGENT_OPTION', {
              name: a.name,
              engine: a.engine === '2' ? '2.0' : '1.0',
            })
          }}
        </option>
      </select>
      <!-- Con qué búsqueda de predefinidas corren (sin tocar la cuenta). -->
      <select
        v-model="seleccion"
        class="!mb-0 h-9 text-sm w-56"
        :title="t('SELECCION.HINT')"
        data-test="seleccion"
      >
        <option v-for="s in selecciones" :key="s" :value="s">
          {{ t(`SELECCION.${(s || 'account').toUpperCase()}`) }}
        </option>
      </select>
      <woot-button
        v-if="agentFilter"
        size="small"
        variant="smooth"
        :is-loading="runningAll"
        :title="t('RUN_ALL_HINT')"
        @click="runAll"
      >
        {{ t('RUN_ALL') }}
      </woot-button>
      <woot-button
        v-if="agentFilter"
        size="small"
        variant="smooth"
        color-scheme="secondary"
        icon="arrow-download"
        @click="showImport = !showImport"
      >
        {{ t('IMPORT.OPEN') }}
      </woot-button>
    </div>
    <div
      v-if="showImport && agentFilter"
      class="grid gap-2 p-3 border rounded-lg border-slate-100 dark:border-slate-700"
      data-test="import"
    >
      <p class="m-0 text-xs text-slate-500">{{ t('IMPORT.HINT') }}</p>
      <input
        v-model="importName"
        type="text"
        class="!mb-0 h-8 text-xs"
        :placeholder="t('IMPORT.NAME_PH')"
      />
      <textarea
        v-model="importText"
        rows="6"
        class="!mb-0 text-xs font-mono"
        :placeholder="t('IMPORT.ROWS_PH')"
      />
      <div class="flex flex-wrap gap-2">
        <woot-button
          size="tiny"
          :is-loading="importing"
          :disabled="!importText.trim()"
          @click="importRows(false)"
        >
          {{ t('IMPORT.GO') }}
        </woot-button>
        <woot-button
          size="tiny"
          variant="smooth"
          color-scheme="secondary"
          :is-loading="importing"
          @click="importRows(true)"
        >
          {{ t('IMPORT.PILA') }}
        </woot-button>
      </div>
      <p v-if="importResult" class="m-0 text-xs text-slate-600">
        {{
          t('IMPORT.DONE', {
            n: importResult.created,
            name: importResult.batch.name,
          })
        }}
        <span
          v-for="s in importResult.skipped"
          :key="s.line"
          class="block text-amber-700"
          >{{ t('IMPORT.SKIPPED', { line: s.line, reason: s.reason }) }}</span
        >
      </p>
    </div>
    <form class="flex gap-2" @submit.prevent="create">
      <input
        v-model="newName"
        type="text"
        class="flex-1 !mb-0 h-9 text-sm"
        :placeholder="t('NEW_PH')"
      />
      <woot-button size="small" :disabled="!newName.trim()">
        {{ t('NEW') }}
      </woot-button>
    </form>
    <p v-if="!shown.length" class="text-sm text-slate-500">
      {{ t('EMPTY') }}
    </p>
    <div
      v-for="batch in shown"
      :key="batch.id"
      class="border rounded-lg border-slate-100 dark:border-slate-700"
    >
      <div class="flex flex-wrap items-center gap-2 p-3">
        <button
          type="button"
          class="flex-1 text-left"
          @click="open = open === batch.id ? null : batch.id"
        >
          <span class="block text-sm font-medium">{{ batch.name }}</span>
          <span class="block text-xs text-slate-500">
            {{ t('COUNT', { n: batch.cases.length }) }}
          </span>
          <span
            v-if="batch.last_run"
            class="block text-xs"
            :class="{
              'text-woot-600': inProgress(batch.last_run),
              'text-red-700': batch.last_run.status === 'failed',
              'text-slate-500': batch.last_run.status === 'done',
            }"
            >{{ runLine(batch.last_run) }}</span
          >
          <span
            v-for="r in finishedResults(batch.last_run)"
            :key="r.case_id"
            class="block text-xs"
            :class="r.ok ? 'text-green-700' : 'text-red-700'"
            >{{ r.ok ? '✅' : '❌' }} {{ r.name }} — {{ r.reason }}</span
          >
        </button>
        <select v-model="runAgent[batch.id]" class="!mb-0 h-8 text-xs w-56">
          <option :value="undefined">{{ t('PICK_AGENT') }}</option>
          <option v-for="a in agents" :key="a.id" :value="a.id">
            {{
              $t('AGENT_TESTER.AGENT_OPTION', {
                name: a.name,
                engine: a.engine === '2' ? '2.0' : '1.0',
              })
            }}
          </option>
        </select>
        <woot-button
          size="tiny"
          :disabled="
            !runAgent[batch.id] ||
            !batch.cases.length ||
            inProgress(batch.last_run)
          "
          @click="run(batch)"
        >
          {{ t('RUN') }}
        </woot-button>
        <woot-button
          size="tiny"
          variant="smooth"
          :title="t('COMPARE_HINT')"
          :disabled="
            !runAgent[batch.id] ||
            !batch.cases.length ||
            inProgress(batch.last_run)
          "
          @click="compare(batch)"
        >
          {{ t('COMPARE') }}
        </woot-button>
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="delete"
          @click="remove(batch)"
        />
      </div>
      <div
        v-if="open === batch.id"
        class="p-3 space-y-2 border-t border-slate-100 dark:border-slate-700"
      >
        <div v-for="c in batch.cases" :key="c.id" class="flex gap-2 text-xs">
          <div class="flex-1">
            <span class="block font-medium">
              {{ c.name }}
              <span class="ml-1 font-normal text-slate-500">
                {{ t(`ORIGIN.${c.origin || 'manual'}`) }}
              </span>
            </span>
            <span
              v-for="(m, i) in c.messages"
              :key="i"
              class="block text-slate-600"
              >{{ t('CUSTOMER', { text: m }) }}</span
            >
            <span
              v-if="variablesText(c.variables)"
              class="block text-slate-500"
              >{{ t('VARIABLES', { text: variablesText(c.variables) }) }}</span
            >
            <span v-if="c.bad_reply" class="block text-slate-500">{{
              t('BAD_REPLY', { text: c.bad_reply })
            }}</span>
            <span v-if="c.expected" class="block text-slate-500">{{
              t('EXPECTED', { text: c.expected })
            }}</span>
          </div>
          <woot-button
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            icon="dismiss"
            @click="removeCase(batch, c)"
          />
        </div>
        <div class="grid gap-2 p-2 rounded bg-slate-25 dark:bg-slate-800/50">
          <input
            v-model="form.name"
            type="text"
            class="!mb-0 h-8 text-xs"
            :placeholder="t('CASE_NAME_PH')"
          />
          <textarea
            v-model="form.messages"
            rows="3"
            class="!mb-0 text-xs"
            :placeholder="t('MESSAGES_PH')"
          />
          <textarea
            v-model="form.expected"
            rows="2"
            class="!mb-0 text-xs"
            :placeholder="t('EXPECTED_PH')"
          />
          <woot-button
            size="tiny"
            variant="smooth"
            :disabled="!form.messages.trim()"
            @click="addCase(batch)"
          >
            {{ t('ADD_CASE') }}
          </woot-button>
        </div>
      </div>
    </div>
  </div>
</template>
