<script>
// ================================================================================
// @campanas_vendedor — Campañas de seguimiento (Dashboard de Seguimientos)
// Vista con dos tabs: "Campañas" (listado de TrackingCampaign + stats) y
// "Nueva campaña" (formulario inline con el preview de audiencia debajo).
// ================================================================================
import { useAlert } from 'dashboard/composables';
import TrackingCampaignsAPI from 'dashboard/api/trackingCampaigns';
import CampaignForm from 'dashboard/components/contacts/BulkTrackingAssign/CampaignForm.vue';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';

const STATUS_COLOR = {
  draft: 'text-slate-500 bg-slate-100 dark:bg-slate-700',
  running: 'text-green-700 bg-green-100 dark:bg-green-900/30',
  paused: 'text-amber-600 bg-amber-100 dark:bg-amber-900/30',
  finished: 'text-slate-600 bg-slate-100 dark:bg-slate-700',
};

export default {
  components: { CampaignForm, TableFooter },
  data() {
    return {
      campaigns: [],
      isLoading: false,
      deletingId: null,
      showDeleteModal: false,
      campaignToDelete: null,
      activeTab: 'list',
      // Filtro preestablecido cuando se llega desde Contactos (history.state).
      presetFilter: null,
      // Filtro + paginado (cliente) de la tabla de campañas.
      searchQuery: '',
      statusFilter: 'all',
      currentPage: 1,
      perPage: 10,
    };
  },
  computed: {
    isEmpty() {
      return !this.isLoading && this.campaigns.length === 0;
    },
    // Campañas tras aplicar búsqueda de texto + filtro de estado.
    filteredCampaigns() {
      const query = this.searchQuery.trim().toLowerCase();
      return this.campaigns.filter(c => {
        if (this.statusFilter !== 'all' && c.status !== this.statusFilter) {
          return false;
        }
        if (!query) return true;
        const haystack = [c.name, c.template_name, c.inbox_name]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();
        return haystack.includes(query);
      });
    },
    totalPages() {
      return Math.max(1, Math.ceil(this.filteredCampaigns.length / this.perPage));
    },
    pagedCampaigns() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.filteredCampaigns.slice(start, start + this.perPage);
    },
    // Estados disponibles para el selector (los que aparecen en STATUS_COLOR).
    statusOptions() {
      return Object.keys(STATUS_COLOR);
    },
    // La tabla no muestra filas pero sí hay campañas: el filtro no arrojó nada.
    hasNoResults() {
      return (
        !this.isLoading &&
        this.campaigns.length > 0 &&
        this.filteredCampaigns.length === 0
      );
    },
    // woot-tabs usa índice: 0 = listado, 1 = nueva campaña.
    activeTabIndex() {
      return this.activeTab === 'new' ? 1 : 0;
    },
    deleteMessageValue() {
      return this.campaignToDelete ? ` «${this.campaignToDelete.name}»?` : '';
    },
  },
  watch: {
    // Al cambiar el filtro, volver a la primera página.
    searchQuery() {
      this.currentPage = 1;
    },
    statusFilter() {
      this.currentPage = 1;
    },
    // Si el listado se encoge (borrado/refetch), evitar quedar en página vacía.
    totalPages(pages) {
      if (this.currentPage > pages) this.currentPage = pages;
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
    onPageChange(page) {
      this.currentPage = page;
    },
    goToNew() {
      this.presetFilter = null;
      this.activeTab = 'new';
    },
    onPageTabChange(index) {
      if (index === 1) this.goToNew();
      else this.goToList();
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
    openDelete(campaign) {
      this.campaignToDelete = campaign;
      this.showDeleteModal = true;
    },
    closeDelete() {
      this.showDeleteModal = false;
      this.campaignToDelete = null;
    },
    // Borra la campaña; el backend cancela los seguimientos activos y desvincula
    // los demás (quedan sueltos en "Todos").
    async confirmDelete() {
      const campaign = this.campaignToDelete;
      if (!campaign) return;
      this.showDeleteModal = false;
      this.deletingId = campaign.id;
      try {
        await TrackingCampaignsAPI.delete(campaign.id);
        this.campaigns = this.campaigns.filter(c => c.id !== campaign.id);
        useAlert(this.$t('TRACKING_CAMPAIGNS_VIEW.DELETE_SUCCESS'));
      } catch (error) {
        useAlert(this.$t('TRACKING_CAMPAIGNS_VIEW.DELETE_ERROR'));
      } finally {
        this.deletingId = null;
        this.campaignToDelete = null;
      }
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
  <div class="flex flex-col flex-1 w-full h-full min-h-0 overflow-hidden p-4">
    <div class="flex items-start justify-between mb-3 shrink-0">
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

    <!-- Tabs nativos -->
    <woot-tabs
      :index="activeTabIndex"
      class="mb-4 shrink-0"
      @change="onPageTabChange"
    >
      <woot-tabs-item
        :index="0"
        :name="$t('TRACKING_CAMPAIGNS_VIEW.TAB_LIST')"
        :count="campaigns.length"
      />
      <woot-tabs-item
        :index="1"
        :name="$t('TRACKING_CAMPAIGNS_VIEW.TAB_NEW')"
        :show-badge="false"
      />
    </woot-tabs>

    <!-- Tab: Nueva campaña -->
    <div v-if="activeTab === 'new'" class="flex-1 min-h-0 overflow-y-auto">
      <CampaignForm
        :preset-filter-payload="presetFilter"
        @created="onCampaignCreated"
      />
    </div>

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

      <template v-else>
        <!-- Barra de filtro: búsqueda + estado (siempre en una sola línea) -->
        <div class="flex items-center gap-3 mb-3 shrink-0">
          <div class="relative flex-1 min-w-0">
            <fluent-icon
              icon="search"
              size="16"
              class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400"
            />
            <input
              v-model="searchQuery"
              type="text"
              :placeholder="
                $t('TRACKING_CAMPAIGNS_VIEW.SEARCH_PLACEHOLDER')
              "
              class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md pl-9 pr-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
            />
          </div>
          <select
            v-model="statusFilter"
            class="shrink-0 w-44 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
          >
            <option value="all">
              {{ $t('TRACKING_CAMPAIGNS_VIEW.FILTER_STATUS_ALL') }}
            </option>
            <option v-for="s in statusOptions" :key="s" :value="s">
              {{ statusLabel(s) }}
            </option>
          </select>
        </div>

        <div
          v-if="hasNoResults"
          class="py-16 text-center text-slate-400 dark:text-slate-500"
        >
          {{ $t('TRACKING_CAMPAIGNS_VIEW.NO_RESULTS') }}
        </div>

        <div v-else class="flex-1 min-h-0 overflow-y-auto">
          <table class="w-full text-sm border-collapse">
        <thead class="sticky top-0 z-10 bg-white dark:bg-slate-900">
          <tr
            class="text-left text-slate-500 dark:text-slate-400 border-b border-slate-100 dark:border-slate-700"
          >
            <th class="p-3">{{ $t('TRACKING_CAMPAIGNS_VIEW.COL.NAME') }}</th>
            <th class="p-3">{{ $t('TRACKING_CAMPAIGNS_VIEW.COL.AGENT') }}</th>
            <th class="p-3">{{ $t('TRACKING_CAMPAIGNS_VIEW.COL.CHANNEL') }}</th>
            <th class="p-3">{{ $t('TRACKING_CAMPAIGNS_VIEW.COL.START') }}</th>
            <th class="p-3">{{ $t('TRACKING_CAMPAIGNS_VIEW.COL.STATUS') }}</th>
            <th class="p-3 text-right">
              {{ $t('TRACKING_CAMPAIGNS_VIEW.COL.PROGRESS') }}
            </th>
            <th class="p-3 w-10" aria-label="acciones" />
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="c in pagedCampaigns"
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
            <td class="p-3 text-right">
              <woot-button
                variant="clear"
                color-scheme="alert"
                size="small"
                icon="delete"
                :is-loading="deletingId === c.id"
                :title="$t('TRACKING_CAMPAIGNS_VIEW.DELETE')"
                @click.stop="openDelete(c)"
              />
            </td>
          </tr>
        </tbody>
          </table>
        </div>

        <!-- Pie de paginado nativo (mismo componente que Contactos) -->
        <TableFooter
          v-if="!hasNoResults"
          class="shrink-0 border-t border-slate-75 dark:border-slate-700/50"
          :current-page="currentPage"
          :total-count="filteredCampaigns.length"
          :page-size="perPage"
          @pageChange="onPageChange"
        />
      </template>
    </template>

    <woot-delete-modal
      :show.sync="showDeleteModal"
      :on-close="closeDelete"
      :on-confirm="confirmDelete"
      :title="$t('TRACKING_CAMPAIGNS_VIEW.DELETE')"
      :message="$t('TRACKING_CAMPAIGNS_VIEW.DELETE_CONFIRM')"
      :message-value="deleteMessageValue"
      :confirm-text="$t('TRACKING_CAMPAIGNS_VIEW.DELETE_YES')"
      :reject-text="$t('TRACKING_CAMPAIGNS_VIEW.DELETE_NO')"
    />
  </div>
</template>
