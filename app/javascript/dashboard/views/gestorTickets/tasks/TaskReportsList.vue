<!--
  Reporte de cierre — lista de reportes con los filtros que reciba: { contact_id,
  organization_id, case_task_id, case_meeting_id, user_id, from, to }.
-->
<script>
import TaskReportsAPI from 'dashboard/api/taskReports';
import Spinner from 'shared/components/Spinner.vue';

export default {
  name: 'TaskReportsList',
  components: { Spinner },
  props: {
    filters: { type: Object, default: () => ({}) },
  },
  data() {
    return { reports: [], count: 0, page: 1, loading: true };
  },
  computed: {
    hasMore() {
      return this.reports.length < this.count;
    },
  },
  watch: {
    filters: {
      deep: true,
      handler() {
        this.page = 1;
        this.fetch();
      },
    },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await TaskReportsAPI.list({
          ...this.filters,
          page: this.page,
        });
        this.reports =
          this.page === 1
            ? data.task_reports
            : [...this.reports, ...data.task_reports];
        this.count = data.meta.count;
      } catch {
        this.reports = [];
        this.count = 0;
      } finally {
        this.loading = false;
      }
    },
    more() {
      this.page += 1;
      this.fetch();
    },
    when(date) {
      return new Date(date).toLocaleString(undefined, {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    client(report) {
      const client = report.contact || report.organization;
      return client ? client.name : '';
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <p
      v-if="!loading && !reports.length"
      class="m-0 text-sm text-slate-500 dark:text-slate-400"
    >
      {{ $t('TASK_REPORT.EMPTY') }}
    </p>
    <article
      v-for="report in reports"
      :key="report.id"
      class="p-3 bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
    >
      <div class="flex flex-wrap items-center gap-2">
        <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
          {{ report.title }}
        </span>
        <span
          v-if="report.outcome"
          class="px-2 py-0.5 text-xs rounded-full bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-200"
        >
          {{ report.outcome }}
        </span>
      </div>
      <p
        class="mt-1 mb-1 text-sm whitespace-pre-line text-slate-700 dark:text-slate-200"
      >
        {{ report.content }}
      </p>
      <ul
        v-if="report.evidence.length"
        class="flex flex-wrap gap-2 m-0 mb-1 list-none"
      >
        <li v-for="file in report.evidence" :key="file.id">
          <a
            :href="file.url"
            target="_blank"
            rel="noopener noreferrer"
            class="text-xs text-woot-600 hover:underline"
          >
            {{ file.name }}
          </a>
        </li>
      </ul>
      <template v-if="report.arrival">
        <a
          v-if="report.arrival.lat !== undefined"
          :href="`https://www.google.com/maps?q=${report.arrival.lat},${report.arrival.lng}`"
          target="_blank"
          rel="noopener noreferrer"
          class="block mb-1 text-xs text-woot-600 hover:underline"
        >
          {{ $t('TASK_REPORT.ARRIVAL') }}: {{ when(report.arrival.at) }}
        </a>
        <p v-else class="m-0 mb-1 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('TASK_REPORT.ARRIVAL') }}: {{ when(report.arrival.at) }} ·
          {{ $t('VISIT_ARRIVALS.NO_LOCATION') }}
        </p>
      </template>
      <a
        v-if="report.service_report_url"
        :href="report.service_report_url"
        target="_blank"
        rel="noopener noreferrer"
        class="block mb-1 text-xs text-woot-600 hover:underline"
      >
        {{ $t('TASK_REPORT.SERVICE_REPORT') }}
      </a>
      <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ report.user && report.user.name }} · {{ when(report.created_at) }}
        <template v-if="client(report)"> · {{ client(report) }}</template>
        <template v-if="report.case_ticket">
          · {{ report.case_ticket.folio }}
        </template>
      </p>
    </article>
    <Spinner v-if="loading" />
    <woot-button
      v-else-if="hasMore"
      size="small"
      variant="clear"
      class="self-start"
      @click="more"
    >
      {{ $t('TASK_REPORT.MORE') }}
    </woot-button>
  </div>
</template>
