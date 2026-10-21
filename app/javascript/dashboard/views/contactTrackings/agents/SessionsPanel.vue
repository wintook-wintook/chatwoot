<script>
// feat/agentes_ia_unificado — «EN CONSTRUCCIÓN», ahora en la lista de Agentes IA
// ============================================================================
// Las conversaciones del Asistente de todos los administradores de la cuenta: las
// que siguen a medias y, con el filtro, las que ya se guardaron. Antes era una
// pestaña del Asistente; ahora vive junto a los agentes, y abrir una lleva a su
// espacio (el del agente si ya tiene uno, o el de «agente nuevo»).
// La tabla es la misma de antes (ordenable, paginada en memoria), con el estilo de
// las tablas nativas (fase A del ajuste visual).
// ============================================================================
import { useAlert } from 'dashboard/composables';
import AssistantAPI from 'dashboard/api/assistant';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import {
  sortRows,
  nextOrder,
  NUMBER,
  DATE,
  TEXT,
} from '../assistant/tableSort';

// El backend devuelve hasta 50 (TrackingAssistantSession::LIST_LIMIT): el paginado
// es sobre lo que ya está en memoria.
const SESSIONS_PER_PAGE = 10;
const SESSION_COLUMNS = {
  id: NUMBER,
  status: TEXT,
  title: TEXT,
  creator: TEXT,
  template_name: TEXT,
  routes: NUMBER,
  created_at: DATE,
  updated_at: DATE,
};

export default {
  components: { TableFooter },
  emits: ['open', 'count'],
  data() {
    return {
      sessions: [],
      isLoading: false,
      sessionsFilter: 'open',
      sessionsPage: 1,
      SESSIONS_PER_PAGE,
      sessionsSort: { key: 'updated_at', order: 'desc' },
      discardTarget: null,
    };
  },
  computed: {
    openSessions() {
      return this.sessions.filter(sesion => sesion.status === 'open');
    },
    savedSessions() {
      return this.sessions.filter(sesion => sesion.status === 'saved');
    },
    visibleSessions() {
      if (this.sessionsFilter === 'saved') return this.savedSessions;
      if (this.sessionsFilter === 'all') return this.sessions;
      return this.openSessions;
    },
    sessionFilters() {
      return [
        {
          id: 'open',
          label: 'SESSIONS_FILTER_OPEN',
          count: this.openSessions.length,
        },
        {
          id: 'saved',
          label: 'SESSIONS_FILTER_SAVED',
          count: this.savedSessions.length,
        },
        {
          id: 'all',
          label: 'SESSIONS_FILTER_ALL',
          count: this.sessions.length,
        },
      ];
    },
    sessionHeaders() {
      return [
        { key: 'id', label: 'TRACKING_ASSISTANT_VIEW.SESSIONS_COL_ID' },
        { key: 'status', label: 'TRACKING_ASSISTANT_VIEW.SESSIONS_COL_STATUS' },
        { key: 'title', label: 'TRACKING_ASSISTANT_VIEW.SESSIONS_COL_TITLE' },
        {
          key: 'creator',
          label: 'TRACKING_ASSISTANT_VIEW.SESSIONS_COL_CREATOR',
        },
        {
          key: 'template_name',
          label: 'TRACKING_ASSISTANT_VIEW.SESSIONS_COL_TEMPLATE',
        },
        { key: 'routes', label: 'TRACKING_ASSISTANT_VIEW.SESSIONS_COL_ROUTES' },
        {
          key: 'created_at',
          label: 'TRACKING_ASSISTANT_VIEW.SESSIONS_COL_CREATED',
        },
        {
          key: 'updated_at',
          label: 'TRACKING_ASSISTANT_VIEW.SESSIONS_COL_UPDATED',
        },
      ];
    },
    pagedSessions() {
      const start = (this.sessionsPage - 1) * SESSIONS_PER_PAGE;
      return sortRows(
        this.visibleSessions,
        this.sessionsSort,
        SESSION_COLUMNS
      ).slice(start, start + SESSIONS_PER_PAGE);
    },
    discardDescription() {
      const fila = this.discardTarget || {};
      return this.$t('TRACKING_ASSISTANT_VIEW.SESSION_DISCARD_DESCRIPTION', {
        id: fila.id,
        title:
          fila.title || this.$t('TRACKING_ASSISTANT_VIEW.SESSIONS_UNTITLED'),
      });
    },
  },
  watch: {
    sessions(list) {
      const pages = Math.max(1, Math.ceil(list.length / SESSIONS_PER_PAGE));
      if (this.sessionsPage > pages) this.sessionsPage = pages;
      this.$emit('count', this.openSessions.length);
    },
  },
  mounted() {
    this.fetchSessions();
  },
  methods: {
    async fetchSessions() {
      this.isLoading = true;
      try {
        const { data } = await AssistantAPI.getSessions();
        this.sessions = data;
      } catch (error) {
        this.sessions = [];
      } finally {
        this.isLoading = false;
      }
    },
    // Flecha del encabezado ordenado, como en Respuestas predefinidas.
    sortIcon(key) {
      if (this.sessionsSort.key !== key) return '';
      return this.sessionsSort.order === 'desc' ? 'chevron-up' : 'chevron-down';
    },
    sortSessionsBy(key) {
      this.sessionsSort = nextOrder(this.sessionsSort, key);
      this.sessionsPage = 1;
    },
    setFilter(id) {
      this.sessionsFilter = id;
      this.sessionsPage = 1;
    },
    async discardSession(row) {
      this.discardTarget = row;
      const borrar = await this.$refs.discardSessionDialog.showConfirmation();
      if (!borrar) return;
      try {
        await AssistantAPI.discardSession(row.id);
        this.sessions = this.sessions.filter(s => s.id !== row.id);
        useAlert(
          this.$t('TRACKING_ASSISTANT_VIEW.SESSION_DISCARDED', { id: row.id })
        );
      } catch (error) {
        useAlert(this.$t('TRACKING_ASSISTANT_VIEW.SESSION_DISCARD_ERROR'));
      }
    },
    formatDate(value) {
      if (!value) return '—';
      return new Date(value).toLocaleString(undefined, {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
  },
};
</script>

<template>
  <div class="text-slate-700 dark:text-slate-300">
    <p class="mb-4 text-base text-slate-600 dark:text-slate-300">
      {{ $t('TRACKING_ASSISTANT_VIEW.SESSIONS_HINT') }}
    </p>

    <div class="flex flex-wrap items-center gap-2 mb-2">
      <woot-button
        v-for="filtro in sessionFilters"
        :key="filtro.id"
        size="small"
        :variant="sessionsFilter === filtro.id ? 'smooth' : 'clear'"
        :color-scheme="sessionsFilter === filtro.id ? 'primary' : 'secondary'"
        @click="setFilter(filtro.id)"
      >
        {{
          $t(`TRACKING_ASSISTANT_VIEW.${filtro.label}`, {
            count: filtro.count,
          })
        }}
      </woot-button>
    </div>

    <woot-loading-state
      v-if="isLoading"
      :message="$t('TRACKING_TEMPLATES.SESSIONS.LOADING')"
    />
    <p
      v-else-if="!visibleSessions.length"
      class="flex flex-col items-center justify-center h-full py-8 text-base text-slate-600 dark:text-slate-300"
    >
      {{ $t('TRACKING_ASSISTANT_VIEW.SESSIONS_EMPTY') }}
    </p>

    <div v-else class="min-w-full overflow-x-auto">
      <table class="min-w-full divide-y divide-slate-75 dark:divide-slate-700">
        <thead>
          <th
            v-for="col in sessionHeaders"
            :key="col.key"
            class="py-4 pr-4 font-semibold text-left text-slate-700 dark:text-slate-300"
          >
            <button
              class="flex items-center p-0 cursor-pointer"
              @click="sortSessionsBy(col.key)"
            >
              <span class="mb-0 whitespace-nowrap">{{ $t(col.label) }}</span>
              <fluent-icon
                v-if="sortIcon(col.key)"
                class="ml-2"
                :icon="sortIcon(col.key)"
              />
            </button>
          </th>
          <th class="py-4" />
        </thead>
        <tbody
          class="divide-y divide-slate-50 dark:divide-slate-800 text-slate-700 dark:text-slate-300"
        >
          <tr
            v-for="row in pagedSessions"
            :key="row.id"
            class="cursor-pointer hover:bg-slate-25 dark:hover:bg-slate-800"
            @click="$emit('open', row)"
          >
            <!-- El id de la fila: lo único que distingue dos conversaciones del
                 mismo día y el mismo agente al hablar de ellas. -->
            <td class="py-4 pr-4 text-slate-500 dark:text-slate-400">
              #{{ row.id }}
            </td>
            <td class="py-4 pr-4">
              <woot-label
                small
                class="!mb-0"
                :color-scheme="row.status === 'saved' ? 'success' : 'secondary'"
                :title="
                  row.status === 'saved'
                    ? $t('TRACKING_ASSISTANT_VIEW.SESSIONS_SAVED')
                    : $t('TRACKING_ASSISTANT_VIEW.SESSIONS_OPEN')
                "
              />
            </td>
            <td class="max-w-xs py-4 pr-4 font-medium truncate">
              {{ row.title || $t('TRACKING_ASSISTANT_VIEW.SESSIONS_UNTITLED') }}
            </td>
            <td class="py-4 pr-4">
              {{
                row.creator || $t('TRACKING_ASSISTANT_VIEW.SESSIONS_NO_CREATOR')
              }}
            </td>
            <td class="py-4 pr-4">
              {{ row.template_name || '-' }}
            </td>
            <td class="py-4 pr-4">
              {{ row.routes }}
            </td>
            <td class="py-4 pr-4 whitespace-nowrap">
              {{ formatDate(row.created_at) }}
            </td>
            <td class="py-4 pr-4 whitespace-nowrap">
              {{ formatDate(row.updated_at) }}
            </td>
            <td class="py-4">
              <div class="flex justify-end gap-1" @click.stop>
                <woot-button
                  v-tooltip.top="$t('TRACKING_ASSISTANT_VIEW.SESSIONS_RESUME')"
                  variant="smooth"
                  size="tiny"
                  color-scheme="secondary"
                  icon="edit"
                  @click="$emit('open', row)"
                />
                <woot-button
                  v-tooltip.top="$t('TRACKING_TEMPLATES.SESSIONS.DISCARD')"
                  variant="smooth"
                  size="tiny"
                  color-scheme="alert"
                  icon="dismiss-circle"
                  @click="discardSession(row)"
                />
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <TableFooter
        :current-page="sessionsPage"
        :total-count="visibleSessions.length"
        :page-size="SESSIONS_PER_PAGE"
        class="border-t border-slate-50 dark:border-slate-800 !px-0 py-4"
        @pageChange="sessionsPage = $event"
      />
    </div>

    <woot-confirm-modal
      ref="discardSessionDialog"
      :title="$t('TRACKING_ASSISTANT_VIEW.SESSION_DISCARD_TITLE')"
      :description="discardDescription"
      :confirm-label="$t('TRACKING_ASSISTANT_VIEW.SESSION_DISCARD_YES')"
      :cancel-label="$t('TRACKING_ASSISTANT_VIEW.SESSION_DISCARD_NO')"
    />
  </div>
</template>
