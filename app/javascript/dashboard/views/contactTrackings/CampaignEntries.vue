<script>
// ================================================================================
// proyecto@automatizacion_campanas — Pestaña "Inscritos" del detalle de campaña
// ================================================================================
// Plan: docs/automatizacion_campanas_plan.md (§7.2). Cada intento de meter a un contacto
// en la campaña (TrackingCampaignEntry): por lote o por qué automatización, y si entró o
// por qué no. Arriba, el resumen; abajo, la lista paginada, la más reciente primero.
// ================================================================================
import TrackingCampaignsAPI from 'dashboard/api/trackingCampaigns';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';

const T = 'TRACKING_CAMPAIGN_DETAIL.ENTRIES';

export default {
  components: { TableFooter },
  props: {
    campaignId: { type: [String, Number], required: true },
  },
  data() {
    return {
      entries: [],
      summary: null,
      totalCount: 0,
      pageSize: 25,
      currentPage: 1,
      isLoading: false,
    };
  },
  computed: {
    summaryParts() {
      const s = this.summary;
      if (!s) return [];
      return [
        {
          key: 'enrolled',
          label: `${this.$t(`${T}.SUMMARY_ENROLLED`)} ${s.enrolled}`,
        },
        { key: 'batch', label: `${this.$t(`${T}.SUMMARY_BATCH`)} ${s.batch}` },
        {
          key: 'automation',
          label: `${this.$t(`${T}.SUMMARY_AUTOMATION`)} ${s.automation}`,
        },
        {
          key: 'skipped',
          label: `${this.$t(`${T}.SUMMARY_SKIPPED`)} ${s.skipped}`,
        },
      ];
    },
  },
  watch: {
    campaignId() {
      this.fetchEntries(1);
    },
  },
  mounted() {
    this.fetchEntries(1);
  },
  methods: {
    async fetchEntries(page) {
      this.isLoading = true;
      try {
        const { data } = await TrackingCampaignsAPI.getEntries(
          this.campaignId,
          page
        );
        this.entries = data.entries || [];
        this.summary = data.summary;
        this.totalCount = data.meta?.count || 0;
        this.pageSize = data.meta?.per_page || this.pageSize;
        this.currentPage = page;
      } catch (error) {
        this.entries = [];
        this.summary = null;
        this.totalCount = 0;
      } finally {
        this.isLoading = false;
      }
    },
    sourceLabel(entry) {
      if (entry.source === 'automation' && entry.automation_rule_name) {
        return this.$t(`${T}.SOURCE.automation_named`, {
          name: entry.automation_rule_name,
        });
      }
      return this.$t(`${T}.SOURCE.${entry.source}`);
    },
    statusLabel(entry) {
      const status = this.$t(`${T}.STATUS.${entry.status}`);
      return entry.reason
        ? `${status}: ${this.$t(`${T}.REASON.${entry.reason}`)}`
        : status;
    },
    statusClass(entry) {
      return entry.status === 'enrolled'
        ? 'text-green-600 dark:text-green-400'
        : 'text-slate-500 dark:text-slate-400';
    },
    formatDate(value) {
      if (!value) return '—';
      return new Date(value).toLocaleString('es-MX', {
        day: '2-digit',
        month: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
  },
  T,
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <p
      v-if="summaryParts.length"
      class="mb-2 text-sm text-slate-600 dark:text-slate-300 shrink-0"
    >
      <span v-for="(part, i) in summaryParts" :key="part.key">
        <span v-if="i > 0" class="text-slate-300"> · </span>{{ part.label }}
      </span>
    </p>

    <div v-if="isLoading" class="py-10 text-center text-slate-400">
      {{ $t(`${$options.T}.LOADING`) }}
    </div>
    <div
      v-else-if="!entries.length"
      class="py-10 text-center text-slate-400 shrink-0"
    >
      {{ $t(`${$options.T}.EMPTY`) }}
    </div>

    <template v-else>
      <div
        class="flex-1 min-h-0 overflow-y-auto border border-slate-75 dark:border-slate-700 rounded-md"
      >
        <table class="w-full text-sm border-collapse">
          <thead class="sticky top-0 z-10 bg-white dark:bg-slate-800 shadow-sm">
            <tr class="text-left text-slate-500 dark:text-slate-400">
              <th class="p-3">{{ $t(`${$options.T}.COL.CONTACT`) }}</th>
              <th class="p-3">{{ $t(`${$options.T}.COL.SOURCE`) }}</th>
              <th class="p-3">{{ $t(`${$options.T}.COL.STATUS`) }}</th>
              <th class="p-3">{{ $t(`${$options.T}.COL.WHEN`) }}</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="entry in entries"
              :key="entry.id"
              class="border-t border-slate-75 dark:border-slate-700"
            >
              <td class="p-3 text-slate-800 dark:text-slate-100">
                {{ entry.contact_name || '—' }}
              </td>
              <td class="p-3 text-slate-600 dark:text-slate-300">
                {{ sourceLabel(entry) }}
              </td>
              <td class="p-3" :class="statusClass(entry)">
                {{ statusLabel(entry) }}
              </td>
              <td class="p-3 text-slate-500 dark:text-slate-400">
                {{ formatDate(entry.created_at) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <TableFooter
        class="shrink-0"
        :current-page="currentPage"
        :page-size="pageSize"
        :total-count="totalCount"
        @page-change="fetchEntries"
      />
    </template>
  </div>
</template>
