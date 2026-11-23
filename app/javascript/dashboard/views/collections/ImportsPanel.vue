<!-- Cobranza › Cortes: cada carga de la cartera (Excel o, después, la sincronización) con lo que cambió. -->
<script>
import CollectionsAPI from 'dashboard/api/collections';
import { money, shortDate } from './money';

export default {
  name: 'ImportsPanel',
  data() {
    return { rows: [], loading: false };
  },
  async mounted() {
    this.loading = true;
    try {
      const { data } = await CollectionsAPI.imports();
      this.rows = data;
    } finally {
      this.loading = false;
    }
  },
  methods: {
    money,
    shortDate,
    t(key, params) {
      return this.$t(`COLLECTIONS.IMPORTS.${key}`, params);
    },
    diff(row) {
      const d = row.stats.diff || {};
      return this.t('DIFF', {
        new: d.new || 0,
        payments: d.payment || 0,
        paid: d.paid || 0,
        collected: money((d.payment_amount || 0) + (d.paid_amount || 0)),
      });
    },
  },
};
</script>

<template>
  <div>
    <p v-if="loading" class="m-0 text-sm text-slate-500">{{ t('LOADING') }}</p>
    <p v-else-if="!rows.length" class="m-0 text-sm text-slate-500">
      {{ t('EMPTY') }}
    </p>
    <table v-else class="w-full text-sm">
      <thead>
        <tr class="text-xs text-left text-slate-500">
          <th class="py-1 pr-2">{{ t('COLS.DATE') }}</th>
          <th class="py-1 pr-2">{{ t('COLS.SOURCE') }}</th>
          <th class="py-1 pr-2">{{ t('COLS.INVOICES') }}</th>
          <th class="py-1">{{ t('COLS.CHANGES') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="row in rows"
          :key="row.id"
          class="border-t border-slate-100 dark:border-slate-700"
        >
          <td class="py-2 pr-2">
            {{ shortDate(row.created_at) }}
            <span class="block text-xs text-slate-500">{{ row.user }}</span>
          </td>
          <td class="py-2 pr-2 text-xs">
            {{ t(`SOURCES.${row.source}`) }}
            <span class="block text-slate-500">{{ row.source_ref }}</span>
          </td>
          <td class="py-2 pr-2">
            {{
              t('COUNTS', {
                invoices: row.stats.invoices || 0,
                customers: row.stats.customers || 0,
              })
            }}
          </td>
          <td class="py-2 text-xs">{{ diff(row) }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
