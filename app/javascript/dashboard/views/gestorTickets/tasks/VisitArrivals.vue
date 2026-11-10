<!-- Reportes › Llegadas: dónde y cuándo llegó cada quien, técnicos y vendedores. -->
<script>
import { useAlert } from 'dashboard/composables';
import AgendaVisitsAPI from 'dashboard/api/agendaVisits';
import Spinner from 'shared/components/Spinner.vue';

const CSV_FIELDS = [
  'at',
  'user',
  'kind',
  'title',
  'folio',
  'contact',
  'organization',
  'lat',
  'lng',
  'accuracy',
];
const csvCell = value => `"${String(value ?? '').replace(/"/g, '""')}"`;

export default {
  name: 'VisitArrivals',
  components: { Spinner },
  props: {
    filters: { type: Object, default: () => ({}) },
  },
  data() {
    return { rows: [], loading: true };
  },
  watch: {
    filters: { deep: true, handler: 'fetch' },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await AgendaVisitsAPI.arrivals(this.filters);
        this.rows = data.arrivals;
      } catch {
        useAlert(this.$t('VISIT_ARRIVALS.ERROR'));
      } finally {
        this.loading = false;
      }
    },
    when(date) {
      return new Date(date).toLocaleString(undefined, {
        day: '2-digit',
        month: 'short',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    mapUrl(row) {
      return `https://www.google.com/maps?q=${row.lat},${row.lng}`;
    },
    exportCsv() {
      const lines = [CSV_FIELDS.join(',')].concat(
        this.rows.map(row => CSV_FIELDS.map(f => csvCell(row[f])).join(','))
      );
      const blob = new Blob([String.fromCharCode(0xfeff), lines.join('\n')], {
        type: 'text/csv;charset=utf-8',
      });
      const link = document.createElement('a');
      link.href = URL.createObjectURL(blob);
      link.download = 'llegadas.csv';
      link.click();
      URL.revokeObjectURL(link.href);
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <woot-button
      size="small"
      variant="smooth"
      class="self-end"
      :disabled="!rows.length"
      @click="exportCsv"
    >
      {{ $t('VISIT_ARRIVALS.EXPORT') }}
    </woot-button>
    <Spinner v-if="loading" />
    <p
      v-else-if="!rows.length"
      class="m-0 text-sm text-slate-500 dark:text-slate-400"
    >
      {{ $t('VISIT_ARRIVALS.EMPTY') }}
    </p>
    <table v-else class="w-full text-sm">
      <thead>
        <tr class="text-left text-slate-500 dark:text-slate-400">
          <th>{{ $t('VISIT_ARRIVALS.WHEN') }}</th>
          <th>{{ $t('VISIT_ARRIVALS.WHO') }}</th>
          <th>{{ $t('VISIT_ARRIVALS.CLIENT') }}</th>
          <th>{{ $t('VISIT_ARRIVALS.VISIT') }}</th>
          <th>{{ $t('VISIT_ARRIVALS.LOCATION') }}</th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="(row, index) in rows"
          :key="index"
          class="border-t border-slate-100 dark:border-slate-800 text-slate-700 dark:text-slate-200"
        >
          <td class="py-2">{{ when(row.at) }}</td>
          <td>{{ row.user }}</td>
          <td>{{ row.contact || row.organization }}</td>
          <td>
            <template v-if="row.folio">{{ row.folio }} · </template>
            {{ row.title }}
          </td>
          <td>
            <a
              v-if="row.lat !== null && row.lat !== undefined"
              :href="mapUrl(row)"
              target="_blank"
              rel="noopener noreferrer"
              class="text-woot-600 hover:underline"
            >
              {{ row.lat }}, {{ row.lng }}
            </a>
            <span v-else class="text-slate-400">
              {{ $t('VISIT_ARRIVALS.NO_LOCATION') }}
            </span>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
