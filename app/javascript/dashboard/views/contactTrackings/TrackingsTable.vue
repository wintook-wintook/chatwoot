<script>
// ================================================================================
// proyecto@contact_tracking — Dashboard de Seguimientos (Fase 4: Listado)
// Tabla filtrable/paginada con acciones por fila (ir a conversación, ver contacto,
// pausar/reanudar/cancelar).
// ================================================================================
import { mapGetters } from 'vuex';
import { frontendURL } from 'dashboard/helper/URLHelper';
import ContactTrackingsAPI from 'dashboard/api/contactTrackings';

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
    prevPage() {
      if (this.meta.page > 1) this.fetch(this.meta.page - 1);
    },
    nextPage() {
      if (this.meta.page < this.meta.total_pages) this.fetch(this.meta.page + 1);
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
  <div class="flex flex-col gap-4">
    <!-- Filtros -->
    <div class="flex flex-wrap items-end gap-2 p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700">
      <label class="text-sm font-medium text-slate-600 dark:text-slate-300 flex flex-col gap-1 flex-1 min-w-[160px]">
        Buscar
        <input v-model="filters.q" type="text" placeholder="Contacto u objetivo…" class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 px-2 py-1" @keyup.enter="fetch(1)" />
      </label>
      <label class="text-sm font-medium text-slate-600 dark:text-slate-300 flex flex-col gap-1">
        Estado
        <select v-model="filters.status" class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 px-2 py-1">
          <option value="">Todos</option>
          <option v-for="s in statusOptions" :key="s" :value="s">{{ statusMeta[s].label }}</option>
        </select>
      </label>
      <label class="text-sm font-medium text-slate-600 dark:text-slate-300 flex flex-col gap-1">
        Canal
        <select v-model="filters.inbox_id" class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 px-2 py-1">
          <option value="">Todos</option>
          <option v-for="ib in inboxes" :key="ib.id" :value="ib.id">{{ ib.name }}</option>
        </select>
      </label>
      <label class="text-sm font-medium text-slate-600 dark:text-slate-300 flex flex-col gap-1">
        Agente IA
        <select v-model="filters.template_id" class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 px-2 py-1">
          <option value="">Todos</option>
          <option v-for="tpl in templates" :key="tpl.id" :value="tpl.id">{{ tpl.name }}</option>
        </select>
      </label>
      <label class="text-sm font-medium text-slate-600 dark:text-slate-300 flex flex-col gap-1">
        Desde
        <input v-model="filters.date_from" type="date" class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 px-2 py-1" />
      </label>
      <label class="text-sm font-medium text-slate-600 dark:text-slate-300 flex flex-col gap-1">
        Hasta
        <input v-model="filters.date_to" type="date" class="text-sm rounded border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 px-2 py-1" />
      </label>
      <label class="text-sm font-medium text-slate-600 dark:text-slate-300 flex items-center gap-1 pb-1">
        <input v-model="filters.overdue" type="checkbox" /> Solo vencidos
      </label>
      <woot-button variant="smooth" size="small" @click="fetch(1)">Aplicar</woot-button>
      <woot-button variant="clear" size="small" @click="resetFilters">Limpiar</woot-button>
    </div>

    <!-- Tabla -->
    <div class="rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700 overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-slate-500 dark:text-slate-400 border-b border-slate-100 dark:border-slate-700">
            <th class="p-3">Contacto</th>
            <th class="p-3">Estado</th>
            <th class="p-3">Intención / Resultado</th>
            <th class="p-3">Objetivo</th>
            <th class="p-3">Programado</th>
            <th class="p-3">Canal</th>
            <th class="p-3">Agente IA</th>
            <th class="p-3 text-right">Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in rows"
            :key="row.id"
            class="border-b border-slate-50 dark:border-slate-700/50 hover:bg-slate-50 dark:hover:bg-slate-700/30"
          >
            <td class="p-3 text-slate-700 dark:text-slate-200">{{ row.contact_name || '—' }}</td>
            <td class="p-3 font-medium" :class="statusColor(row.status)">{{ statusLabel(row.status) }}</td>
            <td class="p-3 text-slate-500 dark:text-slate-400">
              {{ row.last_intent || '—' }}<span v-if="row.outcome"> · {{ row.outcome }}</span>
            </td>
            <td class="p-3 text-slate-600 dark:text-slate-300 truncate max-w-[16rem]">{{ row.objective }}</td>
            <td class="p-3 text-slate-500 dark:text-slate-400 whitespace-nowrap">{{ formatDate(row.scheduled_for) }}</td>
            <td class="p-3 text-slate-500 dark:text-slate-400">{{ row.inbox_name || '—' }}</td>
            <td class="p-3 text-slate-500 dark:text-slate-400">{{ row.template_name || '—' }}</td>
            <td class="p-3">
              <div class="flex items-center justify-end gap-1">
                <woot-button
                  v-if="row.conversation_display_id"
                  variant="clear"
                  size="tiny"
                  icon="chat"
                  title="Ir a la conversación"
                  @click="goToConversation(row)"
                />
                <woot-button variant="clear" size="tiny" icon="person" title="Ver contacto" @click="goToContact(row)" />
                <woot-button
                  v-if="canPause(row.status)"
                  variant="clear"
                  size="tiny"
                  :is-loading="busyId === row.id"
                  @click="lifecycle(row, 'pause')"
                >
                  Pausar
                </woot-button>
                <woot-button
                  v-if="canResume(row.status)"
                  variant="clear"
                  size="tiny"
                  :is-loading="busyId === row.id"
                  @click="lifecycle(row, 'resume')"
                >
                  Reanudar
                </woot-button>
                <woot-button
                  v-if="canCancel(row.status)"
                  variant="clear"
                  size="tiny"
                  color-scheme="alert"
                  :is-loading="busyId === row.id"
                  @click="lifecycle(row, 'cancel')"
                >
                  Cancelar
                </woot-button>
              </div>
            </td>
          </tr>
          <tr v-if="!rows.length && !flags.isFetching">
            <td colspan="8" class="p-6 text-center text-slate-400">Sin seguimientos con esos filtros.</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Paginación -->
    <div class="flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
      <span>{{ meta.total }} seguimientos</span>
      <div class="flex items-center gap-2">
        <woot-button variant="clear" size="small" :disabled="meta.page <= 1" @click="prevPage">Anterior</woot-button>
        <span>Página {{ meta.page }} de {{ meta.total_pages || 1 }}</span>
        <woot-button variant="clear" size="small" :disabled="meta.page >= meta.total_pages" @click="nextPage">Siguiente</woot-button>
      </div>
    </div>
  </div>
</template>
