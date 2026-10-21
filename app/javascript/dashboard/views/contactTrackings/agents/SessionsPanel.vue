<script>
// feat/agentes_ia_unificado — «EN CONSTRUCCIÓN», ahora en la lista de Agentes IA
// ============================================================================
// Las conversaciones del Asistente de todos los administradores de la cuenta: las
// que siguen a medias y, con el filtro, las que ya se guardaron. Antes era una
// pestaña del Asistente; ahora vive junto a los agentes, y abrir una lleva a su
// espacio (el del agente si ya tiene uno, o el de «agente nuevo»).
// La tabla es la misma de antes (ordenable, paginada en memoria).
// ============================================================================
import { useAlert } from 'dashboard/composables';
import AssistantAPI from 'dashboard/api/assistant';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import SortableTh from '../assistant/SortableTh.vue';
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
  components: { TableFooter, SortableTh },
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
  <div class="flex flex-col flex-1 min-h-0">
    <p class="mb-3 text-xs shrink-0 text-slate-500 dark:text-slate-400">
      {{ $t('TRACKING_ASSISTANT_VIEW.SESSIONS_HINT') }}
    </p>

    <div class="flex flex-wrap items-center gap-1 mb-3 shrink-0">
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

    <div
      v-if="!visibleSessions.length"
      class="py-4 text-xs text-slate-500 dark:text-slate-400"
    >
      {{ $t('TRACKING_ASSISTANT_VIEW.SESSIONS_EMPTY') }}
    </div>

    <template v-else>
      <div
        class="flex-1 min-h-0 overflow-auto bg-white border rounded-lg dark:bg-slate-800 border-slate-100 dark:border-slate-700"
      >
        <table class="w-full text-sm">
          <thead class="sticky top-0 z-10 bg-white dark:bg-slate-800">
            <tr
              class="text-left border-b text-slate-500 dark:text-slate-400 border-slate-100 dark:border-slate-700"
            >
              <SortableTh
                v-for="col in sessionHeaders"
                :key="col.key"
                :label="$t(col.label)"
                :sort-key="col.key"
                :sort="sessionsSort"
                @sort="sortSessionsBy"
              />
              <th
                class="w-24 p-3"
                :aria-label="$t('TRACKING_ASSISTANT_VIEW.SESSIONS_COL_ACTIONS')"
              />
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in pagedSessions"
              :key="row.id"
              class="border-b cursor-pointer border-slate-50 dark:border-slate-700/50 hover:bg-slate-50 dark:hover:bg-slate-700/30"
              @click="$emit('open', row)"
            >
              <td
                class="p-3 font-mono text-xs text-slate-400 dark:text-slate-500"
              >
                #{{ row.id }}
              </td>
              <td class="p-3">
                <span
                  class="text-xs font-medium px-2 py-0.5 rounded whitespace-nowrap"
                  :class="
                    row.status === 'saved'
                      ? 'text-green-700 bg-green-100 dark:bg-green-900/30 dark:text-green-300'
                      : 'text-slate-600 bg-slate-100 dark:bg-slate-700 dark:text-slate-300'
                  "
                >
                  {{
                    row.status === 'saved'
                      ? $t('TRACKING_ASSISTANT_VIEW.SESSIONS_SAVED')
                      : $t('TRACKING_ASSISTANT_VIEW.SESSIONS_OPEN')
                  }}
                </span>
              </td>
              <td class="p-3 font-medium text-slate-800 dark:text-slate-100">
                {{
                  row.title || $t('TRACKING_ASSISTANT_VIEW.SESSIONS_UNTITLED')
                }}
              </td>
              <td class="p-3 text-slate-500 dark:text-slate-400">
                {{
                  row.creator ||
                  $t('TRACKING_ASSISTANT_VIEW.SESSIONS_NO_CREATOR')
                }}
              </td>
              <td class="p-3 text-slate-500 dark:text-slate-400">
                {{ row.template_name || '—' }}
              </td>
              <td class="p-3 text-slate-500 dark:text-slate-400">
                {{ row.routes }}
              </td>
              <td
                class="p-3 text-slate-500 dark:text-slate-400 whitespace-nowrap"
              >
                {{ formatDate(row.created_at) }}
              </td>
              <td
                class="p-3 text-slate-500 dark:text-slate-400 whitespace-nowrap"
              >
                {{ formatDate(row.updated_at) }}
              </td>
              <td class="p-3">
                <div class="flex items-center justify-end gap-1">
                  <woot-button
                    size="small"
                    variant="clear"
                    @click.stop="$emit('open', row)"
                  >
                    {{ $t('TRACKING_ASSISTANT_VIEW.SESSIONS_RESUME') }}
                  </woot-button>
                  <woot-button
                    size="small"
                    variant="clear"
                    color-scheme="alert"
                    icon="delete"
                    @click.stop="discardSession(row)"
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <TableFooter
        class="border-t shrink-0 border-slate-75 dark:border-slate-700/50"
        :current-page="sessionsPage"
        :total-count="visibleSessions.length"
        :page-size="SESSIONS_PER_PAGE"
        @pageChange="sessionsPage = $event"
      />
    </template>

    <woot-confirm-modal
      ref="discardSessionDialog"
      :title="$t('TRACKING_ASSISTANT_VIEW.SESSION_DISCARD_TITLE')"
      :description="discardDescription"
      :confirm-label="$t('TRACKING_ASSISTANT_VIEW.SESSION_DISCARD_YES')"
      :cancel-label="$t('TRACKING_ASSISTANT_VIEW.SESSION_DISCARD_NO')"
    />
  </div>
</template>
