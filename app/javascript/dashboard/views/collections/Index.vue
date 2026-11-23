<!--
  Cobranza: la cartera de la empresa y su agente. Pestañas: Tablero · Subir la cartera · Clientes · Promesas ·
  Comprobantes · Cortes. La cartera entra por cortes (Excel/CSV hoy; la sincronización con el sistema administrativo
  después) y el agente «Cobranza» (Agentes listos) le cobra a quien le toca.
-->
<script>
import CollectionsAPI from 'dashboard/api/collections';
import SubTabs from 'dashboard/views/readyAgents/SubTabs.vue';
import AgingTable from './AgingTable.vue';
import UploadPanel from './UploadPanel.vue';
import CustomersPanel from './CustomersPanel.vue';
import PromisesPanel from './PromisesPanel.vue';
import ClaimsPanel from './ClaimsPanel.vue';
import ImportsPanel from './ImportsPanel.vue';
import { money, shortDate } from './money';

const TABS = [
  'overview',
  'upload',
  'customers',
  'promises',
  'claims',
  'imports',
];

export default {
  name: 'CollectionsIndex',
  components: {
    SubTabs,
    AgingTable,
    UploadPanel,
    CustomersPanel,
    PromisesPanel,
    ClaimsPanel,
    ImportsPanel,
  },
  data() {
    return { tab: 'overview', data: null, customersFilter: 'balance' };
  },
  computed: {
    tabs() {
      return TABS.map(key => ({ key, label: this.t(`TABS.${key}`) }));
    },
    totals() {
      return Object.entries(this.data?.totals || {});
    },
    overdue() {
      return Object.entries(this.data?.aging || {}).map(([currency, b]) => [
        currency,
        Object.entries(b)
          .filter(([k]) => k !== 'not_due')
          .reduce((sum, [, v]) => sum + v, 0),
      ]);
    },
    collected() {
      return Object.entries(this.data?.collected_30 || {});
    },
    hasAgent() {
      return (this.data?.agents || []).length > 0;
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    money,
    shortDate,
    t(key, params) {
      return this.$t(`COLLECTIONS.${key}`, params);
    },
    async load() {
      const { data } = await CollectionsAPI.overview();
      this.data = data;
    },
    goCustomers(filter) {
      this.customersFilter = filter;
      this.tab = 'customers';
    },
    goAgents() {
      this.$router.push({ name: 'ready_agents' });
    },
  },
};
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 p-4 overflow-y-auto">
    <div class="flex items-start gap-2 mb-2">
      <woot-sidemenu-icon />
      <div>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ t('TITLE') }}
        </h1>
        <p class="m-0 mt-1 text-sm text-slate-600 dark:text-slate-400">
          {{ t('SUBTITLE') }}
        </p>
      </div>
    </div>
    <SubTabs v-model="tab" :tabs="tabs" />

    <div class="pt-4">
      <!-- Tablero -->
      <template v-if="tab === 'overview'">
        <p v-if="!data" class="text-sm text-slate-500">{{ t('LOADING') }}</p>
        <div v-else class="flex flex-col gap-4">
          <div
            v-if="!hasAgent"
            class="flex flex-wrap items-center justify-between gap-2 p-3 text-sm rounded-md bg-amber-50 dark:bg-amber-900/20 text-amber-800 dark:text-amber-200"
          >
            <span>{{ t('NO_AGENT') }}</span>
            <woot-button size="small" @click="goAgents">
              {{ t('GO_AGENTS') }}
            </woot-button>
          </div>
          <div
            v-if="!data.last_import"
            class="p-4 text-sm border rounded-lg border-slate-100 dark:border-slate-700"
          >
            <p class="m-0 mb-2">{{ t('START') }}</p>
            <woot-button
              size="small"
              icon="arrow-upload"
              @click="tab = 'upload'"
            >
              {{ t('TABS.upload') }}
            </woot-button>
          </div>
          <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <div
              class="p-3 border rounded-lg border-slate-100 dark:border-slate-700"
            >
              <p class="m-0 text-xs text-slate-500">{{ t('CARDS.TOTAL') }}</p>
              <p
                v-for="[c, v] in totals"
                :key="c"
                class="m-0 text-lg font-semibold"
              >
                {{ money(v, c) }}
              </p>
              <p v-if="!totals.length" class="m-0 text-lg font-semibold">—</p>
            </div>
            <div
              class="p-3 border rounded-lg border-slate-100 dark:border-slate-700"
            >
              <p class="m-0 text-xs text-slate-500">{{ t('CARDS.OVERDUE') }}</p>
              <p
                v-for="[c, v] in overdue"
                :key="c"
                class="m-0 text-lg font-semibold text-red-700 dark:text-red-400"
              >
                {{ money(v, c) }}
              </p>
            </div>
            <div
              class="p-3 border rounded-lg border-slate-100 dark:border-slate-700"
            >
              <p class="m-0 text-xs text-slate-500">
                {{ t('CARDS.COLLECTED') }}
              </p>
              <p
                v-for="[c, v] in collected"
                :key="c"
                class="m-0 text-lg font-semibold text-green-700"
              >
                {{ money(v, c) }}
              </p>
              <p v-if="!collected.length" class="m-0 text-lg font-semibold">
                —
              </p>
            </div>
            <div
              class="p-3 border rounded-lg border-slate-100 dark:border-slate-700"
            >
              <p class="m-0 text-xs text-slate-500">
                {{ t('CARDS.CUSTOMERS') }}
              </p>
              <p class="m-0 text-lg font-semibold">
                {{ data.customers.with_balance }}
              </p>
              <p class="m-0 text-xs text-slate-500">
                {{ t('CARDS.CONTACTED', { n: data.customers.contacted_7 }) }}
              </p>
            </div>
          </div>

          <div
            class="p-4 border rounded-lg border-slate-100 dark:border-slate-700"
          >
            <p class="m-0 mb-2 text-sm font-semibold">{{ t('AGING_TITLE') }}</p>
            <AgingTable :aging="data.aging" />
          </div>

          <div class="grid grid-cols-1 gap-3 md:grid-cols-3">
            <button
              type="button"
              class="p-3 text-left border rounded-lg border-slate-100 dark:border-slate-700 hover:border-woot-300"
              @click="tab = 'claims'"
            >
              <p class="m-0 text-lg font-semibold">
                {{ data.claims_pending }}
              </p>
              <p class="m-0 text-xs text-slate-500">
                {{ t('CARDS.CLAIMS') }}
              </p>
            </button>
            <button
              type="button"
              class="p-3 text-left border rounded-lg border-slate-100 dark:border-slate-700 hover:border-woot-300"
              @click="tab = 'promises'"
            >
              <p class="m-0 text-lg font-semibold">
                {{ data.promises.pending }}
              </p>
              <p class="m-0 text-xs text-slate-500">
                {{
                  t('CARDS.PROMISES', {
                    kept: data.promises.kept,
                    broken: data.promises.broken,
                  })
                }}
              </p>
            </button>
            <button
              type="button"
              class="p-3 text-left border rounded-lg border-slate-100 dark:border-slate-700 hover:border-woot-300"
              @click="goCustomers('pending')"
            >
              <p
                class="m-0 text-lg font-semibold"
                :class="{ 'text-amber-700': data.customers.pending_link }"
              >
                {{ data.customers.pending_link }}
              </p>
              <p class="m-0 text-xs text-slate-500">
                {{ t('CARDS.PENDING_LINK') }}
              </p>
            </button>
          </div>

          <p v-if="data.last_import" class="m-0 text-xs text-slate-500">
            {{
              t('LAST_IMPORT', {
                date: shortDate(data.last_import.created_at),
                source: t(`IMPORTS.SOURCES.${data.last_import.source}`),
                file: data.last_import.source_ref || '',
              })
            }}
          </p>
        </div>
      </template>

      <UploadPanel v-else-if="tab === 'upload'" @applied="load" />
      <CustomersPanel
        v-else-if="tab === 'customers'"
        :initial-filter="customersFilter"
        @changed="load"
      />
      <PromisesPanel v-else-if="tab === 'promises'" />
      <ClaimsPanel v-else-if="tab === 'claims'" @changed="load" />
      <ImportsPanel v-else />
    </div>
  </div>
</template>
