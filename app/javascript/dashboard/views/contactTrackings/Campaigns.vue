<script>
// ================================================================================
// @campanas_vendedor — Campañas de seguimiento (Dashboard de Seguimientos)
// Vista con dos tabs: "Campañas" (listado de TrackingCampaign + stats) y
// "Nueva campaña" (formulario inline con el preview de audiencia debajo).
// ================================================================================
import { useAlert } from 'dashboard/composables';
import TrackingCampaignsAPI from 'dashboard/api/trackingCampaigns';
import CampaignForm from 'dashboard/components/contacts/BulkTrackingAssign/CampaignForm.vue';

const STATUS_COLOR = {
  draft: 'text-slate-500 bg-slate-100 dark:bg-slate-700',
  running: 'text-green-700 bg-green-100 dark:bg-green-900/30',
  paused: 'text-amber-600 bg-amber-100 dark:bg-amber-900/30',
  finished: 'text-slate-600 bg-slate-100 dark:bg-slate-700',
};

export default {
  components: { CampaignForm },
  data() {
    return {
      campaigns: [],
      isLoading: false,
      activeTab: 'list',
      // Filtro preestablecido cuando se llega desde Contactos (history.state).
      presetFilter: null,
    };
  },
  computed: {
    isEmpty() {
      return !this.isLoading && this.campaigns.length === 0;
    },
  },
  mounted() {
    // Llegada desde Contactos: el filtro se pasa por sessionStorage (un solo uso).
    if (this.$route.query.tab === 'new') {
      this.activeTab = 'new';
      const stored = sessionStorage.getItem('campaignPresetFilter');
      if (stored) {
        try {
          this.presetFilter = JSON.parse(stored);
        } catch (error) {
          this.presetFilter = null;
        }
        sessionStorage.removeItem('campaignPresetFilter');
      }
    }
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
    goToList() {
      this.activeTab = 'list';
    },
    goToNew() {
      this.presetFilter = null;
      this.activeTab = 'new';
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
    onCampaignCreated(result) {
      useAlert(
        this.$t('BULK_TRACKING_ASSIGN.MODAL.RESULT_QUEUED_BODY', {
          count: result?.queued || 0,
        })
      );
      this.presetFilter = null;
      this.activeTab = 'list';
      this.fetchCampaigns();
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 w-full h-full overflow-auto p-4">
    <div class="flex items-start justify-between mb-3">
      <div>
        <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('TRACKING_CAMPAIGNS_VIEW.TITLE') }}
        </h1>
        <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
          {{ $t('TRACKING_CAMPAIGNS_VIEW.DESCRIPTION') }}
        </p>
      </div>
      <woot-button
        v-if="activeTab === 'list'"
        variant="clear"
        icon="arrow-clockwise"
        :is-loading="isLoading"
        @click="fetchCampaigns"
      >
        {{ $t('TRACKING_CAMPAIGNS_VIEW.REFRESH') }}
      </woot-button>
    </div>

    <!-- Tabs -->
    <div
      class="flex gap-1 border-b border-slate-100 dark:border-slate-700 mb-4"
    >
      <button
        type="button"
        class="px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors"
        :class="
          activeTab === 'list'
            ? 'border-woot-500 text-woot-600 dark:text-woot-400'
            : 'border-transparent text-slate-500 hover:text-slate-700 dark:hover:text-slate-300'
        "
        @click="goToList"
      >
        {{ $t('TRACKING_CAMPAIGNS_VIEW.TAB_LIST') }}
      </button>
      <button
        type="button"
        class="px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors"
        :class="
          activeTab === 'new'
            ? 'border-woot-500 text-woot-600 dark:text-woot-400'
            : 'border-transparent text-slate-500 hover:text-slate-700 dark:hover:text-slate-300'
        "
        @click="goToNew"
      >
        {{ $t('TRACKING_CAMPAIGNS_VIEW.TAB_NEW') }}
      </button>
    </div>

    <!-- Tab: Nueva campaña -->
    <CampaignForm
      v-if="activeTab === 'new'"
      :preset-filter-payload="presetFilter"
      @created="onCampaignCreated"
    />

    <!-- Tab: Campañas -->
    <template v-else>
      <div v-if="isLoading" class="py-16 text-center text-slate-400">
        {{ $t('TRACKING_CAMPAIGNS_VIEW.LOADING') }}
      </div>

      <div
        v-else-if="isEmpty"
        class="py-16 text-center text-slate-400 dark:text-slate-500"
      >
        <fluent-icon
          icon="megaphone"
          size="40"
          class="mx-auto mb-3 opacity-50"
        />
        <p>{{ $t('TRACKING_CAMPAIGNS_VIEW.EMPTY_TITLE') }}</p>
        <p class="text-sm">{{ $t('TRACKING_CAMPAIGNS_VIEW.EMPTY_HINT') }}</p>
        <woot-button class="mt-4" icon="add" @click="goToNew">
          {{ $t('TRACKING_CAMPAIGNS_VIEW.NEW_CAMPAIGN') }}
        </woot-button>
      </div>

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
            <td
              class="p-3 text-slate-500 dark:text-slate-400 whitespace-nowrap"
            >
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
            <td class="p-3 text-center text-slate-500">
              {{ c.stats.pending }}
            </td>
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
    </template>
  </div>
</template>
