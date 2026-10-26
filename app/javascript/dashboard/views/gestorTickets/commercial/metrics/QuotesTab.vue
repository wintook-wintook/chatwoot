<!--
  Plan-Catalogo-Cotizaciones V1 — Dashboard de ventas › Cotizaciones: las que
  se mandan, cuántas se aceptan, cuánto hay en juego y por responsable. Cuenta
  también las cotizaciones sueltas (sin oportunidad).
-->
<script>
import QuotesAPI from 'dashboard/api/quotes';
import { formatMoney } from 'dashboard/helper/caseCommercial';

export default {
  name: 'QuotesTab',
  data() {
    return { summary: null, loading: true };
  },
  computed: {
    cards() {
      const s = this.summary;
      if (!s) return [];
      return [
        { key: 'SENT', value: s.sent },
        {
          key: 'ACCEPTANCE',
          value: s.acceptance_rate === null ? '—' : `${s.acceptance_rate}%`,
        },
        { key: 'IN_PLAY', value: this.amounts(s.in_play) },
        { key: 'WON', value: this.amounts(s.won_amounts) },
        { key: 'EXPIRED', value: s.expired },
        {
          key: 'RESPONSE',
          value:
            s.avg_response_days === null
              ? '—'
              : this.$t('QUOTES.SUMMARY.DAYS', { days: s.avg_response_days }),
        },
      ];
    },
  },
  async mounted() {
    try {
      const { data } = await QuotesAPI.summary();
      this.summary = data;
    } finally {
      this.loading = false;
    }
  },
  methods: {
    amounts(list) {
      if (!list || !list.length) return '—';
      return list.map(a => formatMoney(a.amount, a.currency)).join(' · ');
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
      <div
        v-for="card in cards"
        :key="card.key"
        class="flex flex-col min-w-0 gap-1 p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <span class="text-xs text-slate-500 dark:text-slate-400">{{
          $t(`QUOTES.SUMMARY.${card.key}`)
        }}</span>
        <span
          class="text-lg font-semibold truncate text-slate-800 dark:text-slate-100"
          :title="String(card.value)"
        >
          {{ card.value }}
        </span>
      </div>
    </div>
    <section
      v-if="summary && summary.by_assignee.length"
      class="p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
    >
      <h3
        class="m-0 mb-2 text-sm font-semibold text-slate-700 dark:text-slate-200"
      >
        {{ $t('QUOTES.SUMMARY.BY_ASSIGNEE') }}
      </h3>
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-slate-500 dark:text-slate-400">
            <th class="py-1 font-medium">
              {{ $t('QUOTES.COLUMNS.ASSIGNEE') }}
            </th>
            <th class="py-1 font-medium text-right">
              {{ $t('QUOTES.SUMMARY.QUOTES') }}
            </th>
            <th class="py-1 font-medium text-right">
              {{ $t('QUOTES.SUMMARY.WON') }}
            </th>
            <th class="py-1 font-medium text-right">
              {{ $t('QUOTES.SUMMARY.ACCEPTANCE') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-50 dark:divide-slate-700">
          <tr v-for="row in summary.by_assignee" :key="row.assignee_id">
            <td class="py-1">{{ row.name }}</td>
            <td class="py-1 text-right">{{ row.quotes }}</td>
            <td class="py-1 text-right">{{ row.won }}</td>
            <td class="py-1 text-right">
              {{
                row.acceptance_rate === null ? '—' : `${row.acceptance_rate}%`
              }}
            </td>
          </tr>
        </tbody>
      </table>
    </section>
  </div>
</template>
