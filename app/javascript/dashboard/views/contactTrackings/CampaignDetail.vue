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
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';

const PAGE_SIZE = 25;

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

// Eje de ENTREGA (WhatsApp), separado del de ejecución ([[Entrega-vs-ejecucion]]).
// Mapea Message.status del último mensaje saliente a uno de 3 buckets.
const DELIVERY_META = {
  delivered: { icon: '✅', key: 'DELIVERED', color: 'text-green-600' },
  sent: { icon: '⏳', key: 'SENT', color: 'text-slate-400' },
  failed: { icon: '⚠️', key: 'FAILED', color: 'text-red-600' },
};

function deliveryBucket(messageStatus) {
  if (!messageStatus) return null;
  if (messageStatus === 'delivered' || messageStatus === 'read') {
    return 'delivered';
  }
  if (messageStatus === 'failed') return 'failed';
  return 'sent';
}

export default {
  components: { TableFooter },
  data() {
    return {
      campaign: null,
      prospects: [],
      isLoading: false,
      currentPage: 1,
      pageSize: PAGE_SIZE,
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
    delivery() {
      return this.campaign?.delivery || {};
    },
    // Eje de entrega: se muestra solo si hay algún mensaje ya enviado.
    hasDelivery() {
      const d = this.delivery;
      return (d.delivered || 0) + (d.sent || 0) + (d.failed || 0) > 0;
    },
    deliveryKpis() {
      return [
        {
          key: 'DELIVERED',
          value: this.delivery.delivered || 0,
          color: 'text-green-600 dark:text-green-500',
        },
        {
          key: 'SENT',
          value: this.delivery.sent || 0,
          color: 'text-slate-800 dark:text-slate-100',
        },
        {
          key: 'FAILED',
          value: this.delivery.failed || 0,
          color: 'text-red-500 dark:text-red-400',
        },
      ];
    },
    funnel() {
      return this.campaign?.funnel || {};
    },
    // Embudo de intención: se muestra solo si al menos un contacto respondió.
    hasFunnel() {
      return (this.funnel.replied || 0) > 0;
    },
    funnelKpis() {
      return [
        {
          key: 'REPLIED',
          value: this.funnel.replied || 0,
          color: 'text-slate-800 dark:text-slate-100',
        },
        {
          key: 'INTERESTED',
          value: this.funnel.interested || 0,
          color: 'text-green-600 dark:text-green-500',
        },
        {
          key: 'APPOINTMENT',
          value: this.funnel.appointment || 0,
          color: 'text-woot-600 dark:text-woot-500',
        },
      ];
    },
    backRoute() {
      return { name: 'contact_trackings_campaigns' };
    },
    kpis() {
      return [
        {
          key: 'CONTACTS',
          value: this.stats.total || 0,
          color: 'text-slate-800 dark:text-slate-100',
        },
        {
          key: 'PENDING',
          value: this.stats.pending || 0,
          color: 'text-slate-800 dark:text-slate-100',
        },
        {
          key: 'ACTIVE',
          value: this.stats.active || 0,
          color: 'text-green-600 dark:text-green-500',
        },
        {
          key: 'COMPLETED',
          value: this.stats.completed || 0,
          color: 'text-green-700 dark:text-green-500',
        },
        {
          key: 'FAILED',
          value: this.stats.failed || 0,
          color: 'text-red-500 dark:text-red-400',
        },
        {
          key: 'PROGRESS',
          value: `${this.progressPct}%`,
          color: 'text-woot-600 dark:text-woot-500',
        },
      ];
    },
    progressPct() {
      if (!this.stats.total) return 0;
      return Math.round((this.stats.completed / this.stats.total) * 100);
    },
    totalProspects() {
      return this.prospects.length;
    },
    paginatedProspects() {
      const start = (this.currentPage - 1) * this.pageSize;
      return this.prospects.slice(start, start + this.pageSize);
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
        this.currentPage = 1;
      } catch (error) {
        this.campaign = null;
        this.prospects = [];
      } finally {
        this.isLoading = false;
      }
    },
    onPageChange(page) {
      this.currentPage = page;
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
    deliveryMeta(prospect) {
      const bucket = deliveryBucket(prospect.last_message_status);
      return bucket ? DELIVERY_META[bucket] : null;
    },
    deliveryLabel(prospect) {
      const meta = this.deliveryMeta(prospect);
      if (!meta) return '—';
      return this.$t(`TRACKING_CAMPAIGN_DETAIL.DELIVERY.${meta.key}`);
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
  <div class="flex flex-col flex-1 w-full h-full overflow-hidden p-4">
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
      <div class="flex items-center gap-3 mb-1 shrink-0">
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
        class="flex flex-wrap gap-x-6 gap-y-1 text-sm text-slate-500 dark:text-slate-400 mb-5 shrink-0"
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

      <!-- KPIs de ejecución (estilo métricas de Chatwoot) -->
      <div
        class="flex flex-wrap items-stretch mb-3 shrink-0 rounded-md border border-slate-75 dark:border-slate-700 bg-white dark:bg-slate-800 divide-x divide-slate-75 dark:divide-slate-700 shadow-sm"
      >
        <div v-for="kpi in kpis" :key="kpi.key" class="flex-1 min-w-[7rem] p-4">
          <h3
            class="m-0 text-sm font-medium text-slate-800 dark:text-slate-100"
          >
            {{ $t(`TRACKING_CAMPAIGN_DETAIL.KPI.${kpi.key}`) }}
          </h3>
          <h4 class="mt-1 mb-0 text-3xl font-thin" :class="kpi.color">
            {{ kpi.value }}
          </h4>
        </div>
      </div>

      <!-- Entrega (WhatsApp) — eje separado del de ejecución -->
      <div v-if="hasDelivery" class="mb-5 shrink-0">
        <p
          class="mb-1.5 text-xs font-semibold uppercase tracking-wide text-slate-400"
        >
          {{ $t('TRACKING_CAMPAIGN_DETAIL.DELIVERY.TITLE') }}
        </p>
        <div
          class="flex flex-wrap items-stretch rounded-md border border-slate-75 dark:border-slate-700 bg-white dark:bg-slate-800 divide-x divide-slate-75 dark:divide-slate-700 shadow-sm"
        >
          <div
            v-for="kpi in deliveryKpis"
            :key="kpi.key"
            class="flex-1 min-w-[7rem] p-4"
          >
            <h3
              class="m-0 text-sm font-medium text-slate-800 dark:text-slate-100"
            >
              {{ $t(`TRACKING_CAMPAIGN_DETAIL.DELIVERY.${kpi.key}`) }}
            </h3>
            <h4 class="mt-1 mb-0 text-3xl font-thin" :class="kpi.color">
              {{ kpi.value }}
            </h4>
          </div>
        </div>
      </div>

      <!-- Embudo de intención — qué contestó el cliente -->
      <div v-if="hasFunnel" class="mb-5 shrink-0">
        <p
          class="mb-1.5 text-xs font-semibold uppercase tracking-wide text-slate-400"
        >
          {{ $t('TRACKING_CAMPAIGN_DETAIL.FUNNEL.TITLE') }}
        </p>
        <div
          class="flex flex-wrap items-stretch rounded-md border border-slate-75 dark:border-slate-700 bg-white dark:bg-slate-800 divide-x divide-slate-75 dark:divide-slate-700 shadow-sm"
        >
          <div
            v-for="kpi in funnelKpis"
            :key="kpi.key"
            class="flex-1 min-w-[7rem] p-4"
          >
            <h3
              class="m-0 text-sm font-medium text-slate-800 dark:text-slate-100"
            >
              {{ $t(`TRACKING_CAMPAIGN_DETAIL.FUNNEL.${kpi.key}`) }}
            </h3>
            <h4 class="mt-1 mb-0 text-3xl font-thin" :class="kpi.color">
              {{ kpi.value }}
            </h4>
          </div>
        </div>
      </div>

      <!-- Prospectos -->
      <h2
        class="mb-2 text-base font-semibold text-slate-700 dark:text-slate-200 shrink-0"
      >
        {{ $t('TRACKING_CAMPAIGN_DETAIL.PROSPECTS') }} ({{ totalProspects }})
      </h2>

      <div
        v-if="totalProspects === 0"
        class="py-10 text-center text-slate-400 shrink-0"
      >
        {{ $t('TRACKING_CAMPAIGN_DETAIL.PROSPECTS_EMPTY') }}
      </div>

      <!-- Área de tabla: ocupa el alto restante y hace scroll interno -->
      <div v-else class="flex flex-col flex-1 min-h-0">
        <div
          class="flex-1 min-h-0 overflow-y-auto border border-slate-75 dark:border-slate-700 rounded-md"
        >
          <table class="w-full text-sm border-collapse">
            <thead
              class="sticky top-0 z-10 bg-white dark:bg-slate-800 shadow-sm"
            >
              <tr class="text-left text-slate-500 dark:text-slate-400">
                <th class="p-3">
                  {{ $t('TRACKING_CAMPAIGN_DETAIL.COL.CONTACT') }}
                </th>
                <th class="p-3">
                  {{ $t('TRACKING_CAMPAIGN_DETAIL.COL.STATUS') }}
                </th>
                <th class="p-3">
                  {{ $t('TRACKING_CAMPAIGN_DETAIL.COL.DELIVERY') }}
                </th>
                <th class="p-3">
                  {{ $t('TRACKING_CAMPAIGN_DETAIL.COL.INTENT') }}
                </th>
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
                v-for="p in paginatedProspects"
                :key="p.id"
                class="border-t border-slate-75 dark:border-slate-800 hover:bg-slate-25 dark:hover:bg-slate-800/40"
              >
                <td class="p-3 text-slate-700 dark:text-slate-200">
                  {{ p.contact_name || '—' }}
                </td>
                <td
                  class="p-3 font-medium"
                  :class="trackingStatusColor(p.status)"
                >
                  {{ trackingStatusLabel(p.status) }}
                </td>
                <td class="p-3">
                  <span
                    v-if="deliveryMeta(p)"
                    class="inline-flex items-center gap-1 font-medium"
                    :class="deliveryMeta(p).color"
                    :title="p.last_message_error || deliveryLabel(p)"
                  >
                    {{ deliveryMeta(p).icon }} {{ deliveryLabel(p) }}
                  </span>
                  <span v-else class="text-slate-300">—</span>
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
        </div>

        <TableFooter
          class="shrink-0"
          :current-page="currentPage"
          :page-size="pageSize"
          :total-count="totalProspects"
          @page-change="onPageChange"
        />
      </div>
    </template>
  </div>
</template>
