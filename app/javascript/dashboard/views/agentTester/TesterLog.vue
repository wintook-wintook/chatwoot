<script>
// Probador de agentes › Bitácora: las corridas de lotes (cuántas pasaron, por prueba qué contestó)
// y las correcciones (cada 👎 con de quién fue el error). Lo del motor lleva el estado de su reporte.
import AgentTestBatchesApi from 'dashboard/api/agentTestBatches';
import AgentTesterAPI from 'dashboard/api/agentTester';

const ICONS = {
  prompt: '✏️',
  content: '📚',
  model: '🧠',
  engine: '🔧',
  question: '❓',
};

export default {
  props: {
    stamp: { type: Number, default: 0 },
  },
  data() {
    return {
      tab: 'runs',
      runs: [],
      logs: [],
      open: null,
      detail: null,
      timer: null,
    };
  },
  watch: {
    stamp() {
      this.load();
    },
  },
  mounted() {
    this.load();
    this.timer = setInterval(() => {
      if (this.runs.some(r => r.status === 'queued' || r.status === 'running'))
        this.load();
    }, 5000);
  },
  beforeDestroy() {
    clearInterval(this.timer);
  },
  methods: {
    t(key, args) {
      return this.$t(`AGENT_TESTER.LOG.${key}`, args);
    },
    icon(kind) {
      return ICONS[kind] || '🎓';
    },
    async load() {
      const [runs, logs] = await Promise.all([
        AgentTestBatchesApi.runs(),
        AgentTesterAPI.logs(),
      ]);
      this.runs = runs.data;
      this.logs = logs.data;
    },
    async toggle(run) {
      if (this.open === run.id) {
        this.open = null;
        return;
      }
      this.open = run.id;
      const { data } = await AgentTestBatchesApi.runs(run.id);
      this.detail = data;
    },
    when(date) {
      return new Date(date).toLocaleString();
    },
  },
};
</script>

<template>
  <div class="max-w-4xl space-y-3">
    <div class="flex gap-2">
      <woot-button
        size="small"
        :variant="tab === 'runs' ? 'smooth' : 'clear'"
        @click="tab = 'runs'"
      >
        {{ t('RUNS') }}
      </woot-button>
      <woot-button
        size="small"
        :variant="tab === 'logs' ? 'smooth' : 'clear'"
        @click="tab = 'logs'"
      >
        {{ t('CORRECTIONS') }}
      </woot-button>
    </div>

    <template v-if="tab === 'runs'">
      <p v-if="!runs.length" class="text-sm text-slate-500">
        {{ t('NO_RUNS') }}
      </p>
      <div
        v-for="run in runs"
        :key="run.id"
        class="border rounded-lg border-slate-100 dark:border-slate-700"
      >
        <button
          type="button"
          class="flex items-center w-full gap-3 p-3 text-left"
          @click="toggle(run)"
        >
          <span class="flex-1 text-sm">
            <span class="block font-medium">{{
              t('RUN_TITLE', { batch: run.batch, agent: run.agent })
            }}</span>
            <span class="block text-xs text-slate-500"
              >{{ when(run.created_at) }} ·
              {{ t(`STATUS.${run.status}`) }}</span
            >
          </span>
          <span
            class="text-sm font-semibold"
            :class="
              run.passed === run.total ? 'text-green-700' : 'text-amber-700'
            "
          >
            {{ t('SCORE', { passed: run.passed, total: run.total }) }}
          </span>
        </button>
        <div
          v-if="open === run.id && detail"
          class="p-3 space-y-2 border-t border-slate-100 dark:border-slate-700"
        >
          <div v-for="(r, i) in detail.results" :key="i" class="text-xs">
            <span class="font-medium"
              >{{ r.ok ? '✅' : '❌' }} {{ r.name }}</span
            >
            <span class="block text-slate-600">{{
              t('REPLY', { text: r.reply })
            }}</span>
            <span
              class="block"
              :class="r.ok ? 'text-green-700' : 'text-red-700'"
              >{{ r.reason }}</span
            >
          </div>
        </div>
      </div>
    </template>

    <template v-else>
      <p v-if="!logs.length" class="text-sm text-slate-500">
        {{ t('NO_LOGS') }}
      </p>
      <div
        v-for="log in logs"
        :key="log.id"
        class="p-3 text-xs border rounded-lg border-slate-100 dark:border-slate-700"
      >
        <span class="block text-sm font-medium">
          {{ icon(log.kind) }} {{ t(`KINDS.${log.kind}`) }} · {{ log.agent }}
        </span>
        <span class="block text-slate-500">
          {{ when(log.created_at) }} · {{ log.user }}
          <template v-if="log.report_status"
            >·
            {{
              t('REPORT', { status: t(`REPORT_STATUS.${log.report_status}`) })
            }}</template
          >
        </span>
        <span class="block mt-1">{{
          t('FEEDBACK', { text: log.feedback })
        }}</span>
        <span v-if="log.reply" class="block text-slate-600">{{
          t('REPLY', { text: log.reply })
        }}</span>
      </div>
    </template>
  </div>
</template>
