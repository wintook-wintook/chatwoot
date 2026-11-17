<script>
// Probador de agentes › Bitácora: las corridas de lotes (cuántas pasaron, por prueba qué contestó)
// y las correcciones: cada 👎 con la causa exacta, qué hacer a mano y su seguimiento (pendiente →
// «Ya lo corregí» corre su prueba otra vez → quedó / sigue fallando). Queda aunque se cierre el
// probador, y desde aquí se sigue la plática. Lo del motor lleva el estado de su reporte.
import { useAlert } from 'dashboard/composables';
import AgentTestBatchesApi from 'dashboard/api/agentTestBatches';
import AgentTesterAPI from 'dashboard/api/agentTester';

const ICONS = {
  prompt: '✏️',
  content: '📚',
  search: '🔎',
  model: '🧠',
  engine: '🔧',
  question: '❓',
};
const STATUS_CLASS = {
  pending: 'bg-amber-50 text-amber-800',
  retesting: 'bg-slate-100 text-slate-700',
  passed: 'bg-green-50 text-green-800',
  failing: 'bg-red-50 text-red-800',
};

export default {
  props: {
    stamp: { type: Number, default: 0 },
    // Corridas de lotes: solo quien puede cambiar agentes. Los demás ven sus correcciones.
    canEdit: { type: Boolean, default: false },
  },
  emits: ['resume'],
  data() {
    return {
      tab: this.canEdit ? 'runs' : 'logs',
      filter: 'open',
      runs: [],
      logs: [],
      open: null,
      detail: null,
      timer: null,
    };
  },
  computed: {
    shownLogs() {
      if (this.filter === 'all') return this.logs;
      return this.logs.filter(l => l.status !== 'passed');
    },
  },
  watch: {
    stamp() {
      this.load();
    },
    canEdit(value) {
      if (!value) this.tab = 'logs';
      this.load();
    },
  },
  mounted() {
    this.load();
    this.timer = setInterval(() => {
      const busy =
        this.runs.some(r => r.status === 'queued' || r.status === 'running') ||
        this.logs.some(l => l.status === 'retesting');
      if (busy) this.load();
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
    statusClass(status) {
      return STATUS_CLASS[status] || STATUS_CLASS.pending;
    },
    async load() {
      const [runs, logs] = await Promise.all([
        this.canEdit ? AgentTestBatchesApi.runs() : Promise.resolve(null),
        AgentTesterAPI.logs(),
      ]);
      this.runs = runs ? runs.data : [];
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
    // La indicación del 👎 sigue aquí aunque se haya cerrado la plática del probador.
    copy(text) {
      if (navigator.clipboard) navigator.clipboard.writeText(text);
      useAlert(this.t('COPIED'));
    },
    suggestion(log) {
      const d = log.diagnosis || {};
      return log.kind === 'search' ? d.add || '' : d.suggestion || '';
    },
    canFix(log) {
      return ['prompt', 'content', 'search', 'model'].includes(log.kind);
    },
    openAgent(log) {
      const id = String(log.template_id);
      const route =
        log.engine === '2'
          ? { name: 'motor2_agent', params: { templateId: id } }
          : {
              name: 'contact_trackings_agent',
              params: { templateId: id },
              query: { seccion: 'training' },
            };
      window.open(this.$router.resolve(route).href, '_blank');
    },
    async retest(log) {
      try {
        const { data } = await AgentTesterAPI.retest(log.id);
        Object.assign(log, data);
        useAlert(this.t('RETESTING'));
      } catch (e) {
        const msg = e && e.response && e.response.data && e.response.data.error;
        useAlert(msg || this.t('ERROR'));
      }
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
        v-if="canEdit"
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
      <div class="flex gap-2">
        <woot-button
          size="tiny"
          :variant="filter === 'open' ? 'smooth' : 'clear'"
          @click="filter = 'open'"
        >
          {{ t('FILTER_OPEN') }}
        </woot-button>
        <woot-button
          size="tiny"
          :variant="filter === 'all' ? 'smooth' : 'clear'"
          @click="filter = 'all'"
        >
          {{ t('FILTER_ALL') }}
        </woot-button>
      </div>
      <p v-if="!shownLogs.length" class="text-sm text-slate-500">
        {{ t('NO_LOGS') }}
      </p>
      <div
        v-for="log in shownLogs"
        :key="log.id"
        class="p-3 text-xs border rounded-lg border-slate-100 dark:border-slate-700"
      >
        <span class="flex items-center gap-2 text-sm font-medium">
          <span class="flex-1">
            {{ icon(log.kind) }} {{ t(`KINDS.${log.kind}`) }} · {{ log.agent }}
          </span>
          <span
            class="px-2 py-0.5 text-[11px] rounded-full"
            :class="statusClass(log.status)"
          >
            {{ t(`FOLLOW.${log.status || 'pending'}`) }}
          </span>
        </span>
        <span class="block text-slate-500">
          {{ when(log.created_at) }} · {{ log.user }}
          <template v-if="log.report_status">
            ·
            {{
              t('REPORT', { status: t(`REPORT_STATUS.${log.report_status}`) })
            }}
          </template>
        </span>
        <span class="block mt-1">
          {{ t('FEEDBACK', { text: log.feedback }) }}
        </span>
        <span v-if="log.reply" class="block text-slate-600">
          {{ t('REPLY', { text: log.reply }) }}
        </span>

        <div
          v-if="log.diagnosis && log.diagnosis.text"
          class="p-2 mt-2 rounded bg-slate-50 dark:bg-slate-800"
        >
          <span class="block font-medium">{{ t('CAUSE') }}</span>
          <span class="block mt-1">{{ log.diagnosis.text }}</span>
        </div>

        <div
          v-if="canFix(log)"
          class="p-2 mt-2 rounded bg-slate-50 dark:bg-slate-800"
        >
          <span class="block font-medium">{{ t('TODO') }}</span>
          <template v-if="log.kind === 'prompt'">
            <span v-if="log.diagnosis.where" class="block mt-1">
              {{ t('WHERE', { where: log.diagnosis.where }) }}
            </span>
            <span
              v-if="suggestion(log)"
              class="block p-2 mt-1 whitespace-pre-line bg-white rounded dark:bg-slate-900"
            >
              {{ suggestion(log) }}
            </span>
            <span class="block mt-1 text-slate-500">{{
              t('TODO_PROMPT')
            }}</span>
          </template>
          <template v-else-if="log.kind === 'search'">
            <span class="block mt-1">
              {{ t('SEARCH_ITEM', { item: log.diagnosis.item }) }}
            </span>
            <span
              v-if="suggestion(log)"
              class="block p-2 mt-1 whitespace-pre-line bg-white rounded dark:bg-slate-900"
            >
              {{ suggestion(log) }}
            </span>
            <span class="block mt-1 text-slate-500">{{
              t('TODO_SEARCH')
            }}</span>
          </template>
          <template v-else-if="log.kind === 'content'">
            <span class="block mt-1">
              {{
                t('SOURCE', {
                  source: log.diagnosis.source || '—',
                  item: log.diagnosis.item || '—',
                })
              }}
            </span>
            <span
              v-if="log.diagnosis.found"
              class="block mt-1 whitespace-pre-line"
            >
              {{ t('FOUND', { text: log.diagnosis.found }) }}
            </span>
            <span
              v-if="log.diagnosis.should"
              class="block mt-1 whitespace-pre-line"
            >
              {{ t('SHOULD', { text: log.diagnosis.should }) }}
            </span>
            <span class="block mt-1 text-slate-500">{{
              t('TODO_CONTENT')
            }}</span>
          </template>
          <template v-else-if="log.kind === 'model'">
            <span class="block mt-1">
              {{ t('MODEL_WHERE', { where: log.diagnosis.where }) }}
            </span>
          </template>
        </div>

        <div
          v-if="log.status === 'passed' || log.status === 'failing'"
          class="p-2 mt-2 rounded"
          :class="statusClass(log.status)"
        >
          <span class="block font-medium">
            {{
              log.status === 'passed' ? t('RETEST_PASSED') : t('RETEST_FAILED')
            }}
          </span>
          <span v-if="log.retest.reply" class="block mt-1 whitespace-pre-line">
            {{ t('REPLY', { text: log.retest.reply }) }}
          </span>
          <span v-if="log.retest.reason" class="block mt-1">
            {{ log.retest.reason }}
          </span>
        </div>
        <span
          v-else-if="log.status === 'retesting'"
          class="block mt-2 text-slate-500"
        >
          {{ t('RETESTING') }}
        </span>

        <span class="flex flex-wrap gap-2 mt-2">
          <woot-button
            v-if="suggestion(log)"
            size="tiny"
            variant="smooth"
            @click="copy(suggestion(log))"
          >
            {{ t('COPY') }}
          </woot-button>
          <woot-button
            v-if="canEdit && log.template_id && canFix(log)"
            size="tiny"
            variant="smooth"
            @click="openAgent(log)"
          >
            {{ t('OPEN_AGENT') }}
          </woot-button>
          <woot-button
            v-if="log.conversation_id"
            size="tiny"
            variant="smooth"
            @click="$emit('resume', log.conversation_id)"
          >
            {{ t('RESUME') }}
          </woot-button>
          <woot-button
            v-if="log.has_case && log.status !== 'retesting'"
            size="tiny"
            @click="retest(log)"
          >
            {{ log.status === 'pending' ? t('RETEST') : t('RETEST_AGAIN') }}
          </woot-button>
        </span>
      </div>
    </template>
  </div>
</template>
