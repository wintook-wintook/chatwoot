<script>
// Probador de agentes › Lotes: pruebas agrupadas (lo que escribe el cliente y lo que se espera)
// que se corren completas contra un agente 1.0 o 2.0, con el motor real en el canal de pruebas.
import { useAlert } from 'dashboard/composables';
import AgentTestBatchesApi from 'dashboard/api/agentTestBatches';

export default {
  props: {
    agents: { type: Array, default: () => [] },
    batches: { type: Array, default: () => [] },
  },
  emits: ['changed', 'ran'],
  data() {
    return {
      newName: '',
      open: null,
      form: { name: '', messages: '', expected: '' },
      runAgent: {},
      agentFilter: '',
      runningAll: false,
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
  methods: {
    async runAll() {
      this.runningAll = true;
      try {
        await AgentTestBatchesApi.runCorrections(Number(this.agentFilter));
        useAlert(this.t('RUNNING'));
        this.$emit('ran');
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
        await AgentTestBatchesApi.run(batch.id, templateId);
        useAlert(this.t('RUNNING'));
        this.$emit('ran');
      } catch (e) {
        const data = e && e.response ? e.response.data : null;
        useAlert((data && data.error) || this.t('ERROR'));
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
            <template v-if="batch.last_run">
              {{
                t('LAST_RUN', {
                  agent: batch.last_run.agent,
                  passed: batch.last_run.passed,
                  total: batch.last_run.total,
                })
              }}
            </template>
          </span>
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
          :disabled="!runAgent[batch.id] || !batch.cases.length"
          @click="run(batch)"
        >
          {{ t('RUN') }}
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
            <span class="block font-medium">{{ c.name }}</span>
            <span
              v-for="(m, i) in c.messages"
              :key="i"
              class="block text-slate-600"
              >{{ t('CUSTOMER', { text: m }) }}</span
            >
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
