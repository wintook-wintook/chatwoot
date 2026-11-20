<!--
  «Cómo le va» de los tres agentes listos (últimos 30 días, Motor2::AgentMetrics): cómo terminan las pláticas y el
  % que logra lo suyo (prospectos: califica o agenda; clientes: lo resuelve sin pasarlo; campaña: le interesa), qué
  piden (clientes), en qué pregunta se van y de qué anuncio vienen (prospectos).
-->
<script>
import ReadyAgentsAPI from 'dashboard/api/readyAgents';

const T = 'READY_AGENTS.METRICS';
const ORDER = [
  'qualified',
  'appointment',
  'interested',
  'not_interested',
  'done',
  'handed_off',
  'discarded',
  'client',
  'no_answer',
  'live',
];

export default {
  name: 'ProspectMetrics',
  props: {
    agent: { type: Object, required: true },
  },
  emits: ['close'],
  data() {
    return { data: null, loading: true, failed: false };
  },
  computed: {
    rows() {
      const results = this.data?.results || {};
      const keys = Object.keys(results).sort(
        (a, b) =>
          ((ORDER.indexOf(a) + 99) % 99) - ((ORDER.indexOf(b) + 99) % 99)
      );
      return keys.map(k => ({ key: k, count: results[k] }));
    },
    groups() {
      return Object.entries(this.data?.groups || {}).map(([key, count]) => ({
        key,
        count,
      }));
    },
    kind() {
      return this.data?.kind || 'prospects';
    },
  },
  async mounted() {
    try {
      const { data } = await ReadyAgentsAPI.metrics(this.agent.id);
      this.data = data;
    } catch (e) {
      this.failed = true;
    } finally {
      this.loading = false;
    }
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    // Resultados con nombre (prospectos, campaña) o la etiqueta tal cual (clientes: #respondida…).
    label(key) {
      const path = `${T}.RESULTS.${key}`;
      return this.$te(path) ? this.$t(path) : `#${key}`;
    },
  },
};
</script>

<template>
  <woot-modal show :on-close="() => $emit('close')" size="medium">
    <div class="flex flex-col gap-4 p-6">
      <h2 class="m-0 text-lg font-semibold text-slate-900 dark:text-slate-25">
        {{ t('TITLE', { name: agent.name }) }}
      </h2>
      <p v-if="loading" class="m-0 text-sm text-slate-500">
        {{ t('LOADING') }}
      </p>
      <p v-else-if="failed" class="m-0 text-sm text-red-600">
        {{ t('ERROR') }}
      </p>
      <p v-else-if="!data.total" class="m-0 text-sm text-slate-500">
        {{ t('EMPTY', { days: data.days }) }}
      </p>
      <template v-else>
        <p class="m-0 text-sm text-slate-700 dark:text-slate-200">
          {{
            t(`SUMMARY.${kind}`, {
              total: data.total,
              days: data.days,
              conversion: data.rate,
            })
          }}
        </p>
        <ul class="m-0 text-sm list-none">
          <li
            v-for="row in rows"
            :key="row.key"
            class="flex justify-between py-1 border-b border-slate-100 dark:border-slate-700"
          >
            <span>{{ label(row.key) }}</span>
            <strong>{{ row.count }}</strong>
          </li>
        </ul>
        <div v-if="groups.length">
          <h3 class="m-0 mb-1 text-sm font-semibold">{{ t('GROUPS') }}</h3>
          <ul class="m-0 text-sm list-none">
            <li
              v-for="row in groups"
              :key="row.key"
              class="flex justify-between gap-3 py-1"
            >
              <span>#{{ row.key }}</span>
              <strong>{{ row.count }}</strong>
            </li>
          </ul>
        </div>
        <div v-if="data.drop_off.length">
          <h3 class="m-0 mb-1 text-sm font-semibold">{{ t('DROP_OFF') }}</h3>
          <ul class="m-0 text-sm list-none">
            <li
              v-for="row in data.drop_off"
              :key="row.question"
              class="flex justify-between gap-3 py-1"
            >
              <span class="truncate">{{ row.question }}</span>
              <strong>{{ row.count }}</strong>
            </li>
          </ul>
        </div>
        <div v-if="data.ads.length">
          <h3 class="m-0 mb-1 text-sm font-semibold">{{ t('ADS') }}</h3>
          <ul class="m-0 text-sm list-none">
            <li
              v-for="row in data.ads"
              :key="row.headline"
              class="flex justify-between gap-3 py-1"
            >
              <span class="truncate">{{ row.headline }}</span>
              <span>{{
                t('AD_LINE', { total: row.total, good: row.good })
              }}</span>
            </li>
          </ul>
        </div>
      </template>
    </div>
  </woot-modal>
</template>
