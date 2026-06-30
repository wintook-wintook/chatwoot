<script>
// ================================================================================
// @campanas_vendedor — Listado de Campañas (Dashboard de Seguimientos)
// Lista las corridas de asignación masiva (TrackingCampaign) con sus estadísticas
// agregadas. Patrón espejo de TrackingsTable.vue (mismo módulo).
// ================================================================================
import TrackingCampaignsAPI from 'dashboard/api/trackingCampaigns';

const STATUS_COLOR = {
  draft: 'text-slate-500 bg-slate-100 dark:bg-slate-700',
  running: 'text-green-700 bg-green-100 dark:bg-green-900/30',
  paused: 'text-amber-600 bg-amber-100 dark:bg-amber-900/30',
  finished: 'text-slate-600 bg-slate-100 dark:bg-slate-700',
};

export default {
  data() {
    return {
      campaigns: [],
      isLoading: false,
    };
  },
  computed: {
    isEmpty() {
      return !this.isLoading && this.campaigns.length === 0;
    },
  },
  mounted() {
    this.fetchCampaigns();
  },
  methods: {
    async fetchCampaigns() {
      this.isLoading = true;
      try {
        const { data } = await TrackingCampaignsAPI.get();
        this.campaigns = data;
      } catch (error) {
        this.campaigns = [];
      } finally {
        this.isLoading = false;
      }
    },
    statusLabel(status) {
      return this.$t(`TRACKING_CAMPAIGNS_VIEW.STATUS.${status}`);
    },
    statusClass(status) {
      return STATUS_COLOR[status] || 'text-slate-500 bg-slate-100';
    },
    formatDate(value) {
      if (!value) return '—';
      return new Date(value).toLocaleString('es-MX', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    progressPct(stats) {
      if (!stats || !stats.total) return 0;
      return Math.round((stats.completed / stats.total) * 100);
    },
    openCampaign(campaign) {
      this.$router.push({
        name: 'contact_trackings_campaign_detail',
        params: { campaignId: campaign.id },
      });
    },
  },
};
</script>

<template>
  <div class="p-4 overflow-auto">
    <div class="flex items-center justify-between mb-4">
      <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">
        {{ $t('TRACKING_CAMPAIGNS_VIEW.TITLE') }}
      </h1>
      <woot-button
        variant="clear"
        icon="arrow-clockwise"
        :is-loading="isLoading"
        @click="fetchCampaigns"
      >
        {{ $t('TRACKING_CAMPAIGNS_VIEW.REFRESH') }}
      </woot-button>
    </div>

    <!-- Cargando -->
    <div v-if="isLoading" class="py-16 text-center text-slate-400">
      {{ $t('TRACKING_CAMPAIGNS_VIEW.LOADING') }}
    </div>

    <!-- Vacío -->
    <div
      v-else-if="isEmpty"
      class="py-16 text-center text-slate-400 dark:text-slate-500"
    >
      <fluent-icon icon="megaphone" size="40" class="mx-auto mb-3 opacity-50" />
      <p>{{ $t('TRACKING_CAMPAIGNS_VIEW.EMPTY_TITLE') }}</p>
      <p class="text-sm">{{ $t('TRACKING_CAMPAIGNS_VIEW.EMPTY_HINT') }}</p>
    </div>

    <!-- Tabla -->
    <table v-else class="w-full text-sm border-collapse">
      <thead>
        <tr
          class="text-left text-slate-500 dark:text-slate-400 border-b border-slate-100 dark:border-slate-700"
        >
          <th class="p-3">{{ $t('TRACKING_CAMPAIGNS_VIEW.COL.NAME') }}</th>
          <th class="p-3">{{ $t('TRACKING_CAMPAIGNS_VIEW.COL.AGENT') }}</th>
          <th class="p-3">{{ $t('TRACKING_CAMPAIGNS_VIEW.COL.CHANNEL') }}</th>
          <th class="p-3">{{ $t('TRACKING_CAMPAIGNS_VIEW.COL.START') }}</th>
          <th class="p-3">{{ $t('TRACKING_CAMPAIGNS_VIEW.COL.STATUS') }}</th>
          <th class="p-3 text-center">
            {{ $t('TRACKING_CAMPAIGNS_VIEW.COL.CONTACTS') }}
          </th>
          <th class="p-3 text-center">
            {{ $t('TRACKING_CAMPAIGNS_VIEW.COL.PENDING') }}
          </th>
          <th class="p-3 text-center">
            {{ $t('TRACKING_CAMPAIGNS_VIEW.COL.ACTIVE') }}
          </th>
          <th class="p-3 text-center">
            {{ $t('TRACKING_CAMPAIGNS_VIEW.COL.COMPLETED') }}
          </th>
          <th class="p-3 text-center">
            {{ $t('TRACKING_CAMPAIGNS_VIEW.COL.FAILED') }}
          </th>
          <th class="p-3 text-right">
            {{ $t('TRACKING_CAMPAIGNS_VIEW.COL.PROGRESS') }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="c in campaigns"
          :key="c.id"
          class="border-b border-slate-50 dark:border-slate-800 hover:bg-slate-25 dark:hover:bg-slate-800/40 cursor-pointer"
          @click="openCampaign(c)"
        >
          <td class="p-3 font-medium text-woot-600 dark:text-woot-400">
            {{ c.name }}
          </td>
          <td class="p-3 text-slate-500 dark:text-slate-400">
            {{ c.template_name || '—' }}
          </td>
          <td class="p-3 text-slate-500 dark:text-slate-400">
            {{ c.inbox_name || '—' }}
          </td>
          <td class="p-3 text-slate-500 dark:text-slate-400 whitespace-nowrap">
            {{ formatDate(c.scheduled_for) }}
          </td>
          <td class="p-3">
            <span
              class="px-2 py-0.5 rounded-full text-xs font-medium"
              :class="statusClass(c.status)"
            >
              {{ statusLabel(c.status) }}
            </span>
          </td>
          <td
            class="p-3 text-center font-semibold text-slate-700 dark:text-slate-200"
          >
            {{ c.stats.total }}
          </td>
          <td class="p-3 text-center text-slate-500">{{ c.stats.pending }}</td>
          <td class="p-3 text-center text-green-600">{{ c.stats.active }}</td>
          <td class="p-3 text-center text-green-700">
            {{ c.stats.completed }}
          </td>
          <td class="p-3 text-center text-red-500">{{ c.stats.failed }}</td>
          <td class="p-3 text-right whitespace-nowrap">
            <div class="flex items-center justify-end gap-2">
              <div
                class="w-20 h-1.5 rounded-full bg-slate-100 dark:bg-slate-700 overflow-hidden"
              >
                <div
                  class="h-full bg-green-500"
                  :style="{ width: `${progressPct(c.stats)}%` }"
                />
              </div>
              <span class="text-xs text-slate-400 w-9 text-right">
                {{ progressPct(c.stats) }}%
              </span>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
