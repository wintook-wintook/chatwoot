<!--
  Plan-Organizaciones O5 — Informes › Dashboard de clientes: prospectos y clientes,
  cuántos llegaron en el periodo, la conversión de prospecto a cliente, los días promedio
  que tarda y la llegada por mes.
-->
<script>
import OrganizationsAPI from 'dashboard/api/organizations';
import Spinner from 'shared/components/Spinner.vue';

const PERIODS = [3, 6, 12];

export default {
  name: 'OrganizationsDashboard',
  components: { Spinner },
  data() {
    return { metrics: null, months: 6, loading: true };
  },
  computed: {
    periods() {
      return PERIODS;
    },
    tiles() {
      const m = this.metrics;
      return [
        { key: 'PROSPECTS', value: m.totals.prospect },
        { key: 'CUSTOMERS', value: m.totals.customer },
        { key: 'NEW_PROSPECTS', value: m.new_prospects },
        { key: 'NEW_CUSTOMERS', value: m.new_customers },
        { key: 'CONVERSION', value: `${m.conversion_rate}%` },
        {
          key: 'AVG_DAYS',
          value:
            m.avg_days_to_customer === null ? '—' : m.avg_days_to_customer,
        },
      ];
    },
    // La barra más larga del mes con más llegadas = 100 %.
    maxMonthly() {
      return Math.max(
        1,
        ...this.metrics.monthly.map(row => Math.max(row.prospects, row.customers))
      );
    },
  },
  watch: {
    months: 'fetch',
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await OrganizationsAPI.metrics({
          months: this.months,
        });
        this.metrics = data;
      } catch {
        this.metrics = null;
      } finally {
        this.loading = false;
      }
    },
    width(value) {
      return `${(value * 100) / this.maxMonthly}%`;
    },
    monthLabel(month) {
      const [year, number] = month.split('-').map(Number);
      return new Date(year, number - 1, 1).toLocaleDateString(undefined, {
        month: 'short',
        year: 'numeric',
      });
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-auto bg-white dark:bg-slate-900"
  >
    <header
      class="flex flex-wrap items-start justify-between gap-3 px-6 pt-5 pb-3"
    >
      <div>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('ORGANIZATIONS.DASHBOARD.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
          {{ $t('ORGANIZATIONS.DASHBOARD.DESCRIPTION') }}
        </p>
      </div>
      <select v-model.number="months" class="!mb-0 w-44">
        <option v-for="period in periods" :key="period" :value="period">
          {{ $t('ORGANIZATIONS.DASHBOARD.PERIOD', { months: period }) }}
        </option>
      </select>
    </header>

    <Spinner v-if="loading" class="mt-8" />
    <p
      v-else-if="!metrics"
      class="py-12 text-sm text-center text-slate-500 dark:text-slate-400"
    >
      {{ $t('ORGANIZATIONS.ERROR') }}
    </p>
    <div v-else class="flex flex-col gap-6 px-6 pb-6">
      <div class="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
        <div
          v-for="tile in tiles"
          :key="tile.key"
          class="flex flex-col gap-1 p-4 border rounded-lg border-slate-100 dark:border-slate-700"
        >
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ $t(`ORGANIZATIONS.DASHBOARD.TILES.${tile.key}`) }}
          </span>
          <span
            class="text-2xl font-semibold tabular-nums text-slate-800 dark:text-slate-100"
          >
            {{ tile.value }}
          </span>
        </div>
      </div>

      <section>
        <h2
          class="mb-1 text-sm font-semibold text-slate-700 dark:text-slate-200"
        >
          {{ $t('ORGANIZATIONS.DASHBOARD.MONTHLY') }}
        </h2>
        <p class="flex gap-4 mt-0 mb-3 text-xs text-slate-500">
          <span class="flex items-center gap-1">
            <span class="w-3 h-2 rounded-sm bg-amber-400" />
            {{ $t('ORGANIZATIONS.DASHBOARD.TILES.NEW_PROSPECTS') }}
          </span>
          <span class="flex items-center gap-1">
            <span class="w-3 h-2 bg-green-500 rounded-sm" />
            {{ $t('ORGANIZATIONS.DASHBOARD.TILES.NEW_CUSTOMERS') }}
          </span>
        </p>
        <div class="flex flex-col gap-2">
          <div
            v-for="row in metrics.monthly"
            :key="row.month"
            class="grid grid-cols-[5.5rem_1fr] items-center gap-3 text-sm"
          >
            <span class="text-slate-600 dark:text-slate-300">
              {{ monthLabel(row.month) }}
            </span>
            <div class="flex flex-col gap-1">
              <span class="flex items-center gap-2">
                <span
                  class="h-2.5 rounded-sm bg-amber-400"
                  :style="{ width: width(row.prospects) }"
                />
                <span class="text-xs tabular-nums text-slate-500">
                  {{ row.prospects }}
                </span>
              </span>
              <span class="flex items-center gap-2">
                <span
                  class="h-2.5 rounded-sm bg-green-500"
                  :style="{ width: width(row.customers) }"
                />
                <span class="text-xs tabular-nums text-slate-500">
                  {{ row.customers }}
                </span>
              </span>
            </div>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>
