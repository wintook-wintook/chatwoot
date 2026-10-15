<script>
// ================================================================================
// @campanas_vendedor — Campañas de seguimiento (Dashboard de Seguimientos)
// Entra a la tabla de campañas; "+ Agregar campaña" abre el formulario (con el preview
// de audiencia debajo) y "Volver a campañas" regresa. Una campaña Guardada no corre
// hasta "Poner en curso" (proyecto@automatizacion_campanas, TrackingCampaigns::Launch);
// mientras siga Guardada se puede modificar (clic en su fila, o ?edit=<id> desde el detalle).
// La tabla es la de Contactos (VeTable): clic en una columna la ordena (en cliente).
// ================================================================================
import { VeTable } from 'vue-easytable';
import { useAlert } from 'dashboard/composables';
import TrackingCampaignsAPI from 'dashboard/api/trackingCampaigns';
import CampaignForm from 'dashboard/components/contacts/BulkTrackingAssign/CampaignForm.vue';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import { progressPct, sortCampaigns, sortFromParams } from './campaignsTable';

const STATUS_COLOR = {
  saved: 'text-woot-700 bg-woot-50 dark:text-woot-300 dark:bg-woot-900/30',
  draft: 'text-slate-500 bg-slate-100 dark:bg-slate-700',
  running: 'text-green-700 bg-green-100 dark:bg-green-900/30',
  paused: 'text-amber-800 bg-amber-100 dark:bg-amber-900/30',
  finished: 'text-slate-600 bg-slate-100 dark:bg-slate-700',
};

export default {
  components: { CampaignForm, TableFooter, VeTable },
  data() {
    return {
      campaigns: [],
      isLoading: false,
      // Actualizar recarga solo la tabla: no la quita ni muestra "Cargando".
      isRefreshing: false,
      // Orden de la tabla: { campo: 'asc' | 'desc' }; vacío = las más nuevas primero.
      sortConfig: {},
      sortOption: {
        sortAlways: true,
        sortChange: params => this.onSortChange(params),
      },
      // Fila: una Guardada abre el formulario para modificarla; las demás, su tablero
      // de indicadores. Los botones de la fila cortan la propagación.
      eventCustomOption: {
        bodyRowEvents: ({ row }) => ({
          click: () =>
            row.status === 'saved'
              ? this.openEdit(row)
              : this.openCampaign(row),
        }),
      },
      rowStyleOption: {
        stripe: false,
        clickHighlight: false,
        hoverHighlight: true,
      },
      deletingId: null,
      showDeleteModal: false,
      campaignToDelete: null,
      // Poner en curso: la campaña a confirmar y la que se está lanzando
      campaignToLaunch: null,
      launchingId: null,
      activeTab: 'list', // 'list' · 'new' · 'edit'
      // La campaña Guardada que se está modificando (tab 'edit')
      campaignToEdit: null,
      // proyecto@automatizacion_campanas: la campaña continua recién creada, para
      // ofrecer el siguiente paso (crear la automatización que la llena).
      createdContinuous: null,
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
      return Math.max(
        1,
        Math.ceil(this.filteredCampaigns.length / this.perPage)
      );
    },
    sortedCampaigns() {
      return sortCampaigns(this.filteredCampaigns, this.sortConfig);
    },
    pagedCampaigns() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.sortedCampaigns.slice(start, start + this.perPage);
    },
    columns() {
      const col = (field, key, extra = {}) => ({
        field,
        key: field,
        title: this.$t(`TRACKING_CAMPAIGNS_VIEW.COL.${key}`),
        align: 'left',
        sortBy: this.sortConfig[field] || '',
        ...extra,
      });
      return [
        col('name', 'NAME', {
          renderBodyCell: ({ row }) => (
            <span class="font-medium text-woot-600 dark:text-woot-400">
              {row.name}
            </span>
          ),
        }),
        col('template_name', 'AGENT', {
          renderBodyCell: ({ row }) => row.template_name || '—',
        }),
        col('inbox_name', 'CHANNEL', {
          renderBodyCell: ({ row }) => row.inbox_name || '—',
        }),
        // Fecha arriba y hora abajo (como Ventana), para que no se pegue a Tipo
        col('created_at', 'CREATED', {
          width: 130,
          renderBodyCell: ({ row }) => (
            <div class="flex flex-col leading-5 whitespace-nowrap">
              <span>{this.formatDay(row.created_at)}</span>
              <span class="text-slate-500 dark:text-slate-400">
                {this.formatTime(row.created_at)}
              </span>
            </div>
          ),
        }),
        col('mode', 'TYPE', {
          width: 110,
          // Tooltip con qué significa cada tipo
          renderBodyCell: ({ row }) => {
            const mode = row.mode || 'batch';
            const tooltip = {
              content: this.$t(`TRACKING_CAMPAIGNS_VIEW.MODE_HINT.${mode}`),
              classes: 'max-w-xs',
            };
            // Un solo spread (sin más atributos): el plugin de JSX no mezcla props.
            const attrs = {
              class: 'border-b border-dotted border-slate-400 cursor-help',
              directives: [{ name: 'tooltip', value: tooltip }],
            };
            return (
              <span {...attrs}>
                {this.$t(`TRACKING_CAMPAIGNS_VIEW.MODE.${mode}`)}
              </span>
            );
          },
        }),
        col('scheduled_for', 'WINDOW', {
          width: 170,
          renderBodyCell: ({ row }) => (
            <div class="flex flex-col leading-5">
              <span class="whitespace-nowrap">
                {this.formatDate(row.scheduled_for)}
              </span>
              <span class="whitespace-nowrap text-slate-500 dark:text-slate-400">
                → {this.windowEnd(row)}
              </span>
            </div>
          ),
        }),
        // Guardada: en lugar del estado, el botón para ponerla en curso.
        col('status', 'STATUS', {
          width: 170,
          renderBodyCell: ({ row }) =>
            row.status === 'saved' ? (
              <div onClick={e => e.stopPropagation()}>
                <woot-button
                  size="small"
                  icon="send"
                  isLoading={this.launchingId === row.id}
                  onClick={() => this.openLaunch(row)}
                >
                  {this.$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH')}
                </woot-button>
              </div>
            ) : (
              <span
                class={`px-2 py-0.5 rounded-full text-xs font-medium ${this.statusClass(
                  row.status
                )}`}
              >
                {this.statusLabel(row.status)}
              </span>
            ),
        }),
        col('progress', 'PROGRESS', {
          width: 150,
          align: 'right',
          renderBodyCell: ({ row }) => (
            <div class="flex items-center justify-end gap-2">
              <div class="w-20 h-1.5 rounded-full bg-slate-100 dark:bg-slate-700 overflow-hidden">
                <div
                  class="h-full bg-green-500"
                  style={{ width: `${progressPct(row.stats)}%` }}
                />
              </div>
              <span class="text-xs text-slate-400 w-9 text-right">
                {progressPct(row.stats)}%
              </span>
            </div>
          ),
        }),
        {
          field: 'actions',
          key: 'actions',
          title: '',
          align: 'right',
          width: 60,
          renderBodyCell: ({ row }) => (
            <div
              class="flex items-center justify-end gap-1 whitespace-nowrap"
              onClick={e => e.stopPropagation()}
            >
              <woot-button
                variant="clear"
                color-scheme="alert"
                size="small"
                icon="delete"
                isLoading={this.deletingId === row.id}
                title={this.$t('TRACKING_CAMPAIGNS_VIEW.DELETE')}
                onClick={() => this.openDelete(row)}
              />
            </div>
          ),
        },
      ];
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
    if (this.$route.query.edit) this.openEdit({ id: this.$route.query.edit });
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
    // Botón Actualizar: recarga los datos de la tabla sin quitarla de la pantalla.
    async refreshTable() {
      this.isRefreshing = true;
      try {
        const { data } = await TrackingCampaignsAPI.get();
        this.campaigns = data;
      } catch (error) {
        // El detalle (respuesta del servidor o mensaje) para saber qué falló
        const detail = error.response?.data?.error || error.message;
        useAlert(
          detail
            ? `${this.$t('TRACKING_CAMPAIGNS_VIEW.REFRESH_ERROR')} (${detail})`
            : this.$t('TRACKING_CAMPAIGNS_VIEW.REFRESH_ERROR')
        );
      } finally {
        this.isRefreshing = false;
      }
    },
    onSortChange(params) {
      this.sortConfig = sortFromParams(params);
      this.currentPage = 1;
    },
    goToList() {
      this.activeTab = 'list';
      this.campaignToEdit = null;
      if (this.$route.query.edit) this.$router.replace({ query: {} });
    },
    // Trae la campaña completa (audiencia incluida) y abre el formulario con sus datos.
    async openEdit(campaign) {
      try {
        const { data } = await TrackingCampaignsAPI.show(campaign.id);
        if (data.status !== 'saved') {
          useAlert(this.$t('TRACKING_CAMPAIGNS_VIEW.EDIT_ONLY_SAVED'));
          return;
        }
        this.campaignToEdit = data;
        this.activeTab = 'edit';
      } catch (error) {
        useAlert(this.$t('TRACKING_CAMPAIGNS_VIEW.EDIT_ERROR'));
      }
    },
    onCampaignUpdated(result) {
      if (result?.launch) {
        useAlert(
          result.queued
            ? this.$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH_QUEUED', {
                count: result.queued,
              })
            : this.$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH_SUCCESS')
        );
      } else {
        useAlert(this.$t('TRACKING_CAMPAIGNS_VIEW.EDIT_SUCCESS'));
      }
      this.goToList();
      this.fetchCampaigns();
    },
    onPageChange(page) {
      this.currentPage = page;
    },
    goToNew() {
      this.presetFilter = null;
      this.activeTab = 'new';
    },
    openLaunch(campaign) {
      this.campaignToLaunch = campaign;
    },
    closeLaunch() {
      this.campaignToLaunch = null;
    },
    // Pone en curso una campaña Guardada: por lote inscribe a los contactos del momento.
    async confirmLaunch() {
      const campaign = this.campaignToLaunch;
      if (!campaign) return;
      this.campaignToLaunch = null;
      this.launchingId = campaign.id;
      try {
        const { data } = await TrackingCampaignsAPI.launch(campaign.id);
        useAlert(
          data.queued
            ? this.$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH_QUEUED', {
                count: data.queued,
              })
            : this.$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH_SUCCESS')
        );
        this.refreshTable();
      } catch (error) {
        useAlert(
          error.response?.data?.error ||
            this.$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH_ERROR')
        );
      } finally {
        this.launchingId = null;
      }
    },
    statusLabel(status) {
      return this.$t(`TRACKING_CAMPAIGNS_VIEW.STATUS.${status}`);
    },
    statusClass(status) {
      return STATUS_COLOR[status] || 'text-slate-500 bg-slate-100';
    },
    // proyecto@automatizacion_campanas: "01/10/2026 10:00 → sin fin"
    // proyecto@automatizacion_campanas: la ventana va en dos renglones, inicio y "→ fin"
    windowEnd(campaign) {
      return campaign.ends_at
        ? this.formatDate(campaign.ends_at)
        : this.$t('TRACKING_CAMPAIGNS_VIEW.NO_END');
    },
    formatDay(value) {
      if (!value) return '—';
      return new Date(value).toLocaleDateString('es-MX', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
      });
    },
    formatTime(value) {
      if (!value) return '';
      return new Date(value).toLocaleTimeString('es-MX', {
        hour: '2-digit',
        minute: '2-digit',
      });
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
    // Lleva a Automatizaciones con el modal de nueva regla abierto y la acción
    // "Agregar a campaña" ya puesta en esta campaña.
    createAutomationFor(campaign) {
      this.$router.push({
        name: 'automation_list',
        params: { accountId: this.$route.params.accountId },
        query: { add_to_campaign: campaign.id, campaign_name: campaign.name },
      });
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
      if (result?.launch === false) {
        useAlert(this.$t('TRACKING_CAMPAIGNS_VIEW.SAVED_HINT'));
      }
      if (result?.mode === 'continuous') {
        this.createdContinuous = {
          id: result.campaign_id,
          name: result.campaign_name,
        };
      } else if (result?.launch !== false) {
        useAlert(
          this.$t('BULK_TRACKING_ASSIGN.MODAL.RESULT_QUEUED_BODY', {
            count: result?.queued || 0,
          })
        );
      }
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
      <div class="flex items-start gap-2">
        <woot-sidemenu-icon />
        <div>
          <h1 class="text-xl font-bold text-slate-800 dark:text-slate-100">
            {{ $t('TRACKING_CAMPAIGNS_VIEW.TITLE') }}
          </h1>
          <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
            {{ $t('TRACKING_CAMPAIGNS_VIEW.DESCRIPTION') }}
          </p>
        </div>
      </div>
      <!-- Arriba a la derecha: Agregar campaña en la tabla, Volver a campañas en el formulario -->
      <woot-button v-if="activeTab === 'list'" icon="add" @click="goToNew">
        {{ $t('TRACKING_CAMPAIGNS_VIEW.ADD_CAMPAIGN') }}
      </woot-button>
      <woot-button
        v-else
        variant="smooth"
        color-scheme="secondary"
        icon="chevron-left"
        @click="goToList"
      >
        {{ $t('TRACKING_CAMPAIGNS_VIEW.BACK_TO_LIST') }}
      </woot-button>
    </div>

    <div v-if="activeTab !== 'list'" class="mb-4 shrink-0">
      <h2 class="text-base font-semibold text-slate-700 dark:text-slate-200">
        {{
          activeTab === 'edit'
            ? $t('TRACKING_CAMPAIGNS_VIEW.EDIT_CAMPAIGN', {
                name: campaignToEdit.name,
              })
            : $t('TRACKING_CAMPAIGNS_VIEW.NEW_CAMPAIGN')
        }}
      </h2>
    </div>

    <!-- Modificar una Guardada -->
    <div v-if="activeTab === 'edit'" class="flex-1 min-h-0 overflow-y-auto">
      <CampaignForm
        :key="campaignToEdit.id"
        :campaign="campaignToEdit"
        @updated="onCampaignUpdated"
      />
    </div>

    <!-- Tab: Nueva campaña -->
    <div v-else-if="activeTab === 'new'" class="flex-1 min-h-0 overflow-y-auto">
      <CampaignForm
        :preset-filter-payload="presetFilter"
        @created="onCampaignCreated"
      />
    </div>

    <!-- Tab: Campañas -->
    <template v-else>
      <!-- proyecto@automatizacion_campanas: el siguiente paso de una campaña continua -->
      <div
        v-if="createdContinuous"
        class="flex flex-wrap items-center justify-between gap-3 mb-4 p-3 rounded-md border border-woot-100 dark:border-woot-800 bg-woot-25 dark:bg-woot-900/20 text-sm text-slate-700 dark:text-slate-200"
      >
        <span>
          {{
            $t('TRACKING_CAMPAIGNS_VIEW.CONTINUOUS_CREATED', {
              name: createdContinuous.name,
            })
          }}
        </span>
        <span class="flex items-center gap-2">
          <woot-button
            size="small"
            @click="createAutomationFor(createdContinuous)"
          >
            {{ $t('TRACKING_CAMPAIGNS_VIEW.CREATE_AUTOMATION') }}
          </woot-button>
          <woot-button
            size="small"
            variant="clear"
            color-scheme="secondary"
            icon="dismiss"
            :aria-label="$t('TRACKING_CAMPAIGNS_VIEW.DISMISS')"
            @click="createdContinuous = null"
          />
        </span>
      </div>
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
          {{ $t('TRACKING_CAMPAIGNS_VIEW.ADD_CAMPAIGN') }}
        </woot-button>
      </div>

      <template v-else>
        <!-- Barra de filtros (estilo unificado con el listado de Seguimientos) -->
        <div
          class="flex items-center gap-3 mb-3 shrink-0 p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
        >
          <woot-button
            variant="smooth"
            color-scheme="secondary"
            icon="arrow-clockwise"
            class="shrink-0"
            :is-loading="isRefreshing"
            @click="refreshTable"
          >
            {{ $t('TRACKING_CAMPAIGNS_VIEW.REFRESH') }}
          </woot-button>
          <div class="relative flex-1 min-w-[120px]">
            <fluent-icon
              icon="search"
              size="16"
              class="absolute -translate-y-1/2 left-2 top-1/2 text-slate-400"
            />
            <input
              v-model="searchQuery"
              type="text"
              :placeholder="$t('TRACKING_CAMPAIGNS_VIEW.SEARCH_PLACEHOLDER')"
              class="box-border w-full h-9 m-0 text-sm rounded-md border border-solid border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 pl-8 pr-2 outline-none focus:border-woot-500 dark:focus:border-woot-600"
            />
          </div>
          <select
            v-model="statusFilter"
            class="box-border shrink-0 w-44 h-9 text-sm rounded-md border border-solid border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 px-2 outline-none focus:border-woot-500 dark:focus:border-woot-600"
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

        <div
          v-else
          class="campaigns-table-wrap flex-1 min-h-0 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
        >
          <VeTable
            fixed-header
            max-height="100%"
            row-key-field-name="id"
            :columns="columns"
            :table-data="pagedCampaigns"
            :border-around="false"
            :sort-option="sortOption"
            :event-custom-option="eventCustomOption"
            :row-style-option="rowStyleOption"
          />
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
    <woot-delete-modal
      :show="!!campaignToLaunch"
      :on-close="closeLaunch"
      :on-confirm="confirmLaunch"
      :title="$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH')"
      :message="$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH_CONFIRM')"
      :message-value="campaignToLaunch ? ` «${campaignToLaunch.name}»?` : ''"
      :confirm-text="$t('TRACKING_CAMPAIGNS_VIEW.LAUNCH_YES')"
      :reject-text="$t('TRACKING_CAMPAIGNS_VIEW.DELETE_NO')"
    />
  </div>
</template>

<style lang="scss" scoped>
// Misma densidad que la tabla de Contactos; solo scrollean las filas.
.campaigns-table-wrap {
  overflow: hidden;
}

.campaigns-table-wrap::v-deep {
  .ve-table {
    height: 100%;
  }

  .ve-table-header-th {
    padding: var(--space-small) var(--space-two) !important;
    font-size: var(--font-size-mini) !important;
  }

  .ve-table-body-td {
    padding: var(--space-small) var(--space-two) !important;
    vertical-align: middle;
    cursor: pointer;
  }

  .ve-table-sort {
    @apply -top-1;
  }
}
</style>
