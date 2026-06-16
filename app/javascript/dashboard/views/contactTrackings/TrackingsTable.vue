<script>
// ================================================================================
// proyecto@contact_tracking — Dashboard de Seguimientos (Fase 4: Listado)
// Tabla filtrable/paginada con acciones por fila (ir a conversación, ver contacto,
// pausar/reanudar/cancelar).
// ================================================================================
import { mapGetters } from 'vuex';
import { frontendURL } from 'dashboard/helper/URLHelper';
import ContactTrackingsAPI from 'dashboard/api/contactTrackings';
import WootDropdownMenu from 'shared/components/ui/dropdown/DropdownMenu.vue';
import WootDropdownItem from 'shared/components/ui/dropdown/DropdownItem.vue';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';

const STATUS_META = {
  pending: { label: 'Pendiente', color: 'text-slate-500' },
  scheduled: { label: 'Programado', color: 'text-blue-500' },
  active: { label: 'Activo', color: 'text-green-600' },
  paused: { label: 'Pausado', color: 'text-amber-500' },
  completed: { label: 'Completado', color: 'text-green-700' },
  cancelled: { label: 'Cancelado', color: 'text-red-500' },
  failed: { label: 'Fallido', color: 'text-red-700' },
};

export default {
  components: {
    WootDropdownMenu,
    WootDropdownItem,
    TableFooter,
  },
  data() {
    return {
      filters: {
        q: '',
        status: '',
        inbox_id: '',
        template_id: '',
        last_intent: '',
        outcome: '',
        date_from: '',
        date_to: '',
        overdue: false,
      },
      statusOptions: Object.keys(STATUS_META),
      statusMeta: STATUS_META,
      busyId: null,
      openMenuId: null,
      showFiltersModal: false,
      draftFilters: {},
    };
  },
  computed: {
    ...mapGetters({
      rows: 'contactTrackings/getList',
      meta: 'contactTrackings/getListMeta',
      flags: 'contactTrackings/getListFlags',
      inboxes: 'inboxes/getInboxes',
      templates: 'trackingTemplates/getTemplates',
      accountId: 'getCurrentAccountId',
    }),
    // Filtros aplicados (sin la búsqueda libre) representados como chips quitables
    activeFilterChips() {
      const chips = [];
      if (this.filters.status) {
        chips.push({ key: 'status', label: `Estado: ${this.statusLabel(this.filters.status)}` });
      }
      if (this.filters.inbox_id) {
        const ib = this.inboxes.find(i => i.id === this.filters.inbox_id);
        chips.push({ key: 'inbox_id', label: `Canal: ${ib ? ib.name : this.filters.inbox_id}` });
      }
      if (this.filters.template_id) {
        const tpl = this.templates.find(t => t.id === this.filters.template_id);
        chips.push({ key: 'template_id', label: `Agente IA: ${tpl ? tpl.name : this.filters.template_id}` });
      }
      if (this.filters.date_from) {
        chips.push({ key: 'date_from', label: `Desde: ${this.filters.date_from}` });
      }
      if (this.filters.date_to) {
        chips.push({ key: 'date_to', label: `Hasta: ${this.filters.date_to}` });
      }
      if (this.filters.overdue) {
        chips.push({ key: 'overdue', label: 'Solo vencidos' });
      }
      return chips;
    },
    activeFilterCount() {
      return this.activeFilterChips.length;
    },
  },
  mounted() {
    this.fetch(1);
    this.$store.dispatch('trackingTemplates/get');
  },
  methods: {
    fetch(page = 1) {
      const params = { page, per_page: this.meta.per_page };
      Object.entries(this.filters).forEach(([k, v]) => {
        if (v === true) params[k] = true;
        else if (v) params[k] = v;
      });
      this.$store.dispatch('contactTrackings/fetchList', params);
    },
    resetFilters() {
      this.filters = {
        q: '', status: '', inbox_id: '', template_id: '',
        last_intent: '', outcome: '', date_from: '', date_to: '', overdue: false,
      };
      this.fetch(1);
    },
    openFiltersModal() {
      // Copia de trabajo: los cambios solo se aplican al pulsar "Aplicar filtros"
      this.draftFilters = {
        status: this.filters.status,
        inbox_id: this.filters.inbox_id,
        template_id: this.filters.template_id,
        date_from: this.filters.date_from,
        date_to: this.filters.date_to,
        overdue: this.filters.overdue,
      };
      this.showFiltersModal = true;
    },
    closeFiltersModal() {
      this.showFiltersModal = false;
    },
    clearDraftFilters() {
      this.draftFilters = {
        status: '', inbox_id: '', template_id: '',
        date_from: '', date_to: '', overdue: false,
      };
    },
    applyFiltersFromModal() {
      this.filters = { ...this.filters, ...this.draftFilters };
      this.showFiltersModal = false;
      this.fetch(1);
    },
    removeFilter(key) {
      this.filters[key] = key === 'overdue' ? false : '';
      this.fetch(1);
    },
    onPageChange(page) {
      this.fetch(page);
    },
    toggleMenu(id) {
      this.openMenuId = this.openMenuId === id ? null : id;
    },
    closeMenu() {
      this.openMenuId = null;
    },
    // En las últimas filas el menú abre hacia arriba para no generar scroll
    menuOpensUp(index) {
      return this.rows.length > 4 && index >= this.rows.length - 3;
    },
    statusLabel(s) {
      return this.statusMeta[s]?.label || s;
    },
    statusColor(s) {
      return this.statusMeta[s]?.color || 'text-slate-500';
    },
    formatDate(value) {
      return value ? new Date(value).toLocaleString() : '—';
    },
    goToConversation(row) {
      if (!row.conversation_display_id) return;
      this.$router.push(
        frontendURL(`accounts/${this.accountId}/conversations/${row.conversation_display_id}`)
      );
    },
    goToContact(row) {
      this.$router.push(frontendURL(`accounts/${this.accountId}/contacts/${row.contact_id}`));
    },
    canPause(s) {
      return ['pending', 'scheduled', 'active'].includes(s);
    },
    canResume(s) {
      return s === 'paused';
    },
    canCancel(s) {
      return !['completed', 'cancelled', 'failed'].includes(s);
    },
    async lifecycle(row, action) {
      this.closeMenu();
      this.busyId = row.id;
      try {
        await ContactTrackingsAPI[action](this.accountId, row.contact_id, row.id);
        this.$emitter.emit('newToastMessage', { message: 'Seguimiento actualizado' });
        this.fetch(this.meta.page);
      } catch (e) {
        this.$emitter.emit('newToastMessage', { message: 'No se pudo actualizar el seguimiento' });
      } finally {
        this.busyId = null;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-4">
    <!-- Barra de filtros: búsqueda + botón modal + chips activos -->
    <div class="flex flex-col gap-3 p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
      <div class="flex items-center gap-3">
        <div class="relative flex-1 min-w-[120px]">
          <input
            v-model="filters.q"
            type="text"
            placeholder="Contacto u objetivo…"
            class="reset-base box-border w-full h-9 m-0 text-sm rounded-md border border-solid border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 pl-8 pr-2 outline-none focus:border-woot-500 dark:focus:border-woot-600"
            @keyup.enter="fetch(1)"
          />
          <fluent-icon icon="search" size="16" class="absolute -translate-y-1/2 left-2 top-1/2 text-slate-400" />
        </div>
        <div class="flex items-center gap-2 shrink-0">
          <woot-button variant="smooth" size="small" class="!h-9" icon="filter" @click="openFiltersModal">
            Filtros<span v-if="activeFilterCount"> ({{ activeFilterCount }})</span>
          </woot-button>
          <woot-button variant="smooth" size="small" class="!h-9" icon="search" @click="fetch(1)">
            Aplicar
          </woot-button>
          <woot-button v-if="activeFilterCount || filters.q" variant="clear" size="small" class="!h-9" @click="resetFilters">
            Limpiar
          </woot-button>
        </div>
      </div>

      <!-- Chips de filtros activos -->
      <div v-if="activeFilterChips.length" class="flex flex-wrap items-center gap-2">
        <span
          v-for="chip in activeFilterChips"
          :key="chip.key"
          class="inline-flex items-center gap-1 px-2 py-1 text-xs font-medium rounded-full bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-200"
        >
          {{ chip.label }}
          <button
            class="flex items-center text-slate-400 hover:text-red-500"
            title="Quitar filtro"
            @click="removeFilter(chip.key)"
          >
            <fluent-icon icon="dismiss" size="12" />
          </button>
        </span>
      </div>
    </div>

    <!-- Modal de filtros -->
    <woot-modal :show.sync="showFiltersModal" :on-close="closeFiltersModal">
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header header-title="Filtrar seguimientos" />
        <div class="flex flex-col gap-4 p-8">
          <label class="flex flex-col gap-1 text-sm font-medium text-slate-600 dark:text-slate-300">
            Estado
            <select v-model="draftFilters.status" class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 h-9 px-2">
              <option value="">Todos</option>
              <option v-for="s in statusOptions" :key="s" :value="s">{{ statusMeta[s].label }}</option>
            </select>
          </label>
          <label class="flex flex-col gap-1 text-sm font-medium text-slate-600 dark:text-slate-300">
            Canal
            <select v-model="draftFilters.inbox_id" class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 h-9 px-2">
              <option value="">Todos</option>
              <option v-for="ib in inboxes" :key="ib.id" :value="ib.id">{{ ib.name }}</option>
            </select>
          </label>
          <label class="flex flex-col gap-1 text-sm font-medium text-slate-600 dark:text-slate-300">
            Agente IA
            <select v-model="draftFilters.template_id" class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 h-9 px-2">
              <option value="">Todos</option>
              <option v-for="tpl in templates" :key="tpl.id" :value="tpl.id">{{ tpl.name }}</option>
            </select>
          </label>
          <div class="flex gap-4">
            <label class="flex flex-col flex-1 gap-1 text-sm font-medium text-slate-600 dark:text-slate-300">
              Desde
              <input v-model="draftFilters.date_from" type="date" class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 h-9 px-2" />
            </label>
            <label class="flex flex-col flex-1 gap-1 text-sm font-medium text-slate-600 dark:text-slate-300">
              Hasta
              <input v-model="draftFilters.date_to" type="date" class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 h-9 px-2" />
            </label>
          </div>
          <label class="flex items-center gap-2 text-sm font-medium text-slate-600 dark:text-slate-300">
            <input v-model="draftFilters.overdue" type="checkbox" /> Solo vencidos
          </label>
          <div class="flex items-center justify-end gap-2 mt-2">
            <woot-button variant="clear" @click="clearDraftFilters">Limpiar</woot-button>
            <woot-button @click="applyFiltersFromModal">Aplicar filtros</woot-button>
          </div>
        </div>
      </div>
    </woot-modal>

    <!-- Tabla: ocupa el alto disponible y scrollea; el footer queda al fondo del panel -->
    <div class="flex-1 min-h-0 overflow-auto rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-slate-500 dark:text-slate-400 border-b border-slate-100 dark:border-slate-700">
            <th class="p-3">Contacto</th>
            <th class="p-3">Estado</th>
            <th class="p-3">Objetivo</th>
            <th class="p-3">Programado</th>
            <th class="p-3">Canal</th>
            <th class="p-3">Agente IA</th>
            <th class="p-3 text-right">Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="(row, index) in rows"
            :key="row.id"
            class="border-b border-slate-50 dark:border-slate-700/50 hover:bg-slate-50 dark:hover:bg-slate-700/30"
          >
            <td class="p-3 text-slate-700 dark:text-slate-200">{{ row.contact_name || '—' }}</td>
            <td class="p-3 font-medium" :class="statusColor(row.status)">{{ statusLabel(row.status) }}</td>
            <td class="p-3 text-slate-600 dark:text-slate-300 truncate max-w-[16rem]">{{ row.objective }}</td>
            <td class="p-3 text-slate-500 dark:text-slate-400 whitespace-nowrap">{{ formatDate(row.scheduled_for) }}</td>
            <td class="p-3 text-slate-500 dark:text-slate-400">{{ row.inbox_name || '—' }}</td>
            <td class="p-3 text-slate-500 dark:text-slate-400">{{ row.template_name || '—' }}</td>
            <td class="p-3 align-middle">
              <div class="relative flex items-center justify-end">
                <woot-button
                  variant="smooth"
                  size="small"
                  color-scheme="success"
                  icon="more-horizontal"
                  :is-loading="busyId === row.id"
                  title="Acciones"
                  @click="toggleMenu(row.id)"
                />
                <div
                  v-if="openMenuId === row.id"
                  v-on-clickaway="closeMenu"
                  class="absolute right-0 z-30 w-52 p-1 bg-white border rounded-md shadow-xl dark:bg-slate-800 border-slate-50 dark:border-slate-700"
                  :class="menuOpensUp(index) ? 'bottom-full mb-1' : 'top-full mt-1'"
                >
                  <WootDropdownMenu>
                    <WootDropdownItem v-if="row.conversation_display_id">
                      <woot-button
                        variant="clear"
                        color-scheme="secondary"
                        size="small"
                        icon="chat"
                        @click="goToConversation(row)"
                      >
                        Ir a la conversación
                      </woot-button>
                    </WootDropdownItem>
                    <WootDropdownItem>
                      <woot-button
                        variant="clear"
                        color-scheme="secondary"
                        size="small"
                        icon="person"
                        @click="goToContact(row)"
                      >
                        Ver contacto
                      </woot-button>
                    </WootDropdownItem>
                    <WootDropdownItem v-if="canPause(row.status)">
                      <woot-button
                        variant="clear"
                        color-scheme="secondary"
                        size="small"
                        icon="snooze"
                        @click="lifecycle(row, 'pause')"
                      >
                        Pausar
                      </woot-button>
                    </WootDropdownItem>
                    <WootDropdownItem v-if="canResume(row.status)">
                      <woot-button
                        variant="clear"
                        color-scheme="secondary"
                        size="small"
                        icon="play-circle"
                        @click="lifecycle(row, 'resume')"
                      >
                        Reanudar
                      </woot-button>
                    </WootDropdownItem>
                    <WootDropdownItem v-if="canCancel(row.status)">
                      <woot-button
                        variant="clear"
                        color-scheme="alert"
                        size="small"
                        icon="dismiss"
                        @click="lifecycle(row, 'cancel')"
                      >
                        Cancelar
                      </woot-button>
                    </WootDropdownItem>
                  </WootDropdownMenu>
                </div>
              </div>
            </td>
          </tr>
          <tr v-if="!rows.length && !flags.isFetching">
            <td colspan="7" class="p-6 text-center text-slate-400">Sin seguimientos con esos filtros.</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Paginación (componente estándar de Chatwoot) -->
    <TableFooter
      :current-page="Number(meta.page)"
      :total-count="Number(meta.total)"
      :page-size="Number(meta.per_page)"
      class="border-t border-slate-100 dark:border-slate-700"
      @pageChange="onPageChange"
    />
  </div>
</template>
