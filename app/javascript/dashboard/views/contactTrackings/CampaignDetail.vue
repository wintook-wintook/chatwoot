<script>
// ================================================================================
// @campanas_vendedor — Detalle de Campaña (Dashboard de Seguimientos)
// Cabecera + KPIs de la TrackingCampaign y la cola de prospectos (sus
// ContactTracking, reusando el endpoint de listado filtrado por campaign_id).
// ================================================================================
import { mapGetters } from 'vuex';
import { frontendURL } from 'dashboard/helper/URLHelper';
import TrackingCampaignsAPI from 'dashboard/api/trackingCampaigns';
import ContactTrackingsAPI from 'dashboard/api/contactTrackings';

// Colores del estado de la campaña (draft/running/paused/finished)
const CAMPAIGN_STATUS_COLOR = {
  draft: 'text-slate-500 bg-slate-100 dark:bg-slate-700',
  running: 'text-green-700 bg-green-100 dark:bg-green-900/30',
  paused: 'text-amber-600 bg-amber-100 dark:bg-amber-900/30',
  finished: 'text-slate-600 bg-slate-100 dark:bg-slate-700',
};

// Estado de cada prospecto (ContactTracking) — etiquetas en el módulo
const TRACKING_STATUS_META = {
  pending: { label: 'Pendiente', color: 'text-slate-500' },
  scheduled: { label: 'Programado', color: 'text-blue-500' },
  active: { label: 'Activo', color: 'text-green-600' },
  paused: { label: 'Pausado', color: 'text-amber-500' },
  completed: { label: 'Completado', color: 'text-green-700' },
  cancelled: { label: 'Cancelado', color: 'text-red-500' },
  failed: { label: 'Fallido', color: 'text-red-700' },
};

export default {
  data() {
    return {
      campaign: null,
      prospects: [],
      isLoading: false,
    };
  },
  computed: {
    ...mapGetters({ accountId: 'getCurrentAccountId' }),
    campaignId() {
      return this.$route.params.campaignId;
    },
    stats() {
      return this.campaign?.stats || {};
    },
    backRoute() {
      return { name: 'contact_trackings_campaigns' };
    },
    kpis() {
      return [
        {
          key: 'CONTACTS',
          value: this.stats.total,
          color: 'text-slate-700 dark:text-slate-200',
        },
        { key: 'PENDING', value: this.stats.pending, color: 'text-slate-500' },
        { key: 'ACTIVE', value: this.stats.active, color: 'text-green-600' },
        {
          key: 'COMPLETED',
          value: this.stats.completed,
          color: 'text-green-700',
        },
        { key: 'FAILED', value: this.stats.failed, color: 'text-red-500' },
      ];
    },
    progressPct() {
      if (!this.stats.total) return 0;
      return Math.round((this.stats.completed / this.stats.total) * 100);
    },
  },
  mounted() {
    this.fetchAll();
  },
  methods: {
    async fetchAll() {
      this.isLoading = true;
      try {
        const [{ data: campaign }, { data: list }] = await Promise.all([
          TrackingCampaignsAPI.show(this.campaignId),
          ContactTrackingsAPI.getList(this.accountId, {
            campaign_id: this.campaignId,
            per_page: 100,
          }),
        ]);
        this.campaign = campaign;
        this.prospects = list.trackings || [];
      } catch (error) {
        this.campaign = null;
        this.prospects = [];
      } finally {
        this.isLoading = false;
      }
    },
    campaignStatusLabel(status) {
      return this.$t(`TRACKING_CAMPAIGNS_VIEW.STATUS.${status}`);
    },
    campaignStatusClass(status) {
      return CAMPAIGN_STATUS_COLOR[status] || 'text-slate-500 bg-slate-100';
    },
    trackingStatusLabel(status) {
      return TRACKING_STATUS_META[status]?.label || status;
    },
    trackingStatusColor(status) {
      return TRACKING_STATUS_META[status]?.color || 'text-slate-500';
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
    conversationUrl(prospect) {
      if (!prospect.conversation_display_id) return null;
      return frontendURL(
        `accounts/${this.accountId}/conversations/${prospect.conversation_display_id}`
      );
    },
  },
};
</script>

<template>
  <div class="p-4 overflow-auto">
    <!-- Volver -->
    <router-link
      :to="backRoute"
      class="inline-flex items-center gap-1 text-sm text-slate-500 hover:text-woot-600 mb-3"
    >
      <fluent-icon icon="chevron-left" size="14" />
      {{ $t('TRACKING_CAMPAIGN_DETAIL.BACK') }}
    </router-link>

    <!-- Cargando -->
    <div v-if="isLoading" class="py-16 text-center text-slate-400">
      {{ $t('TRACKING_CAMPAIGN_DETAIL.LOADING') }}
    </div>

    <template v-else-if="campaign">
      <!-- Cabecera -->
      <div class="flex items-center gap-3 mb-1">
        <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ campaign.name }}
        </h1>
        <span
          class="px-2 py-0.5 rounded-full text-xs font-medium"
          :class="campaignStatusClass(campaign.status)"
        >
          {{ campaignStatusLabel(campaign.status) }}
        </span>
      </div>
      <div
        class="flex flex-wrap gap-x-6 gap-y-1 text-sm text-slate-500 dark:text-slate-400 mb-5"
      >
        <span>
          {{ $t('TRACKING_CAMPAIGN_DETAIL.AGENT') }}:
          <strong>{{ campaign.template_name || '—' }}</strong>
        </span>
        <span>
          {{ $t('TRACKING_CAMPAIGN_DETAIL.CHANNEL') }}:
          <strong>{{ campaign.inbox_name || '—' }}</strong>
        </span>
        <span>
          {{ $t('TRACKING_CAMPAIGN_DETAIL.START') }}:
          <strong>{{ formatDate(campaign.scheduled_for) }}</strong>
        </span>
        <span v-if="campaign.objective">
          {{ $t('TRACKING_CAMPAIGN_DETAIL.OBJECTIVE') }}:
          <strong>{{ campaign.objective }}</strong>
        </span>
      </div>

      <!-- KPIs -->
      <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 mb-6">
        <div
          v-for="kpi in kpis"
          :key="kpi.key"
          class="p-3 rounded-lg border border-slate-100 dark:border-slate-700 bg-white dark:bg-slate-800"
        >
          <p class="text-xs text-slate-400">
            {{ $t(`TRACKING_CAMPAIGN_DETAIL.KPI.${kpi.key}`) }}
          </p>
          <p class="text-2xl font-bold" :class="kpi.color">{{ kpi.value }}</p>
        </div>
        <div
          class="p-3 rounded-lg border border-slate-100 dark:border-slate-700 bg-white dark:bg-slate-800"
        >
          <p class="text-xs text-slate-400">
            {{ $t('TRACKING_CAMPAIGN_DETAIL.KPI.PROGRESS') }}
          </p>
          <p class="text-2xl font-bold text-green-600">{{ progressPct }}%</p>
        </div>
      </div>

      <!-- Prospectos -->
      <h2
        class="text-base font-semibold text-slate-700 dark:text-slate-200 mb-2"
      >
        {{ $t('TRACKING_CAMPAIGN_DETAIL.PROSPECTS') }} ({{ prospects.length }})
      </h2>

      <div
        v-if="prospects.length === 0"
        class="py-10 text-center text-slate-400"
      >
        {{ $t('TRACKING_CAMPAIGN_DETAIL.PROSPECTS_EMPTY') }}
      </div>

      <table v-else class="w-full text-sm border-collapse">
        <thead>
          <tr
            class="text-left text-slate-500 dark:text-slate-400 border-b border-slate-100 dark:border-slate-700"
          >
            <th class="p-3">
              {{ $t('TRACKING_CAMPAIGN_DETAIL.COL.CONTACT') }}
            </th>
            <th class="p-3">{{ $t('TRACKING_CAMPAIGN_DETAIL.COL.STATUS') }}</th>
            <th class="p-3">{{ $t('TRACKING_CAMPAIGN_DETAIL.COL.INTENT') }}</th>
            <th class="p-3">
              {{ $t('TRACKING_CAMPAIGN_DETAIL.COL.OUTCOME') }}
            </th>
            <th class="p-3">
              {{ $t('TRACKING_CAMPAIGN_DETAIL.COL.SCHEDULED') }}
            </th>
            <th class="p-3 text-center">
              {{ $t('TRACKING_CAMPAIGN_DETAIL.COL.ATTEMPTS') }}
            </th>
            <th class="p-3 text-right">
              {{ $t('TRACKING_CAMPAIGN_DETAIL.COL.ACTION') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="p in prospects"
            :key="p.id"
            class="border-b border-slate-50 dark:border-slate-800 hover:bg-slate-25 dark:hover:bg-slate-800/40"
          >
            <td class="p-3 text-slate-700 dark:text-slate-200">
              {{ p.contact_name || '—' }}
            </td>
            <td class="p-3 font-medium" :class="trackingStatusColor(p.status)">
              {{ trackingStatusLabel(p.status) }}
            </td>
            <td class="p-3 text-slate-500 dark:text-slate-400">
              {{ p.last_intent || '—' }}
            </td>
            <td class="p-3 text-slate-500 dark:text-slate-400">
              {{ p.outcome || '—' }}
            </td>
            <td
              class="p-3 text-slate-500 dark:text-slate-400 whitespace-nowrap"
            >
              {{ formatDate(p.scheduled_for) }}
            </td>
            <td class="p-3 text-center text-slate-500">
              {{ p.attempt_count }}/{{ p.max_attempts }}
            </td>
            <td class="p-3 text-right">
              <router-link
                v-if="conversationUrl(p)"
                :to="conversationUrl(p)"
                class="text-woot-600 hover:text-woot-700 text-xs font-medium"
              >
                {{ $t('TRACKING_CAMPAIGN_DETAIL.OPEN_CONVERSATION') }}
              </router-link>
              <span v-else class="text-slate-300">—</span>
            </td>
          </tr>
        </tbody>
      </table>
    </template>
  </div>
</template>
