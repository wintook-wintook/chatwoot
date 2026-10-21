<script>
// feat/agentes_ia_unificado — «EN CONSTRUCCIÓN», ahora en la lista de Agentes IA
// ============================================================================
// Las conversaciones del Asistente de todos los administradores de la cuenta que
// siguen a medias. Las ya publicadas no se listan (pedido del usuario, 21/10/2026):
// su agente está en la pestaña Agentes y su historial en Versiones. Antes era una
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
  title: TEXT,
  last_change: TEXT,
  creator: TEXT,
  template_name: TEXT,
  routes: NUMBER,
  created_at: DATE,
  updated_at: DATE,
};

export default {
  components: { TableFooter },
  emits: ['open'],
  data() {
    return {
      sessions: [],
      isLoading: false,
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
    // Con «Último cambio» ya armado, para mostrarlo y poder ordenar por él.
    visibleSessions() {
      return this.openSessions.map(row => ({
        ...row,
        last_change: this.lastChange(row),
      }));
    },
    sessionHeaders() {
      return [
        { key: 'title', label: 'TRACKING_ASSISTANT_VIEW.SESSIONS_COL_TITLE' },
        {
          key: 'last_change',
          label: 'TRACKING_TEMPLATES.SESSIONS.LAST_CHANGE',
        },
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
    // «Último cambio» (en lugar del id, pedido del usuario 21/10/2026): lo último que
    // pasó en el borrador, de lo más útil a lo más básico — lo que declaró el
    // Asistente, las notas de «Configurar», o las piezas tocadas a mano.
    lastChange(row) {
      const versiones = row.versions || [];
      const ultima = versiones[versiones.length - 1];
      const t = (key, args) =>
        this.$t(`TRACKING_TEMPLATES.SESSIONS.${key}`, args);
      if (!ultima || ultima.source === 'loaded') return t('NO_CHANGES');

      const origen = this.$t(
        `TRACKING_ASSISTANT_VIEW.LOG_SOURCE_${String(
          ultima.source
        ).toUpperCase()}`
      );
      const lista = items => {
        const mas = items.length - 2;
        const base = items.slice(0, 2).join(' · ');
        return mas > 0 ? `${base} ${t('AND_MORE', { count: mas })}` : base;
      };
      let detalle = ultima.summary || '';
      if (!detalle && (ultima.notes || []).length)
        detalle = lista(ultima.notes);
      if (!detalle && (ultima.changes || []).length)
        detalle = lista(ultima.changes);
      return detalle ? `${origen}: ${detalle}` : origen;
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
  <!-- Solo la tabla hace scroll; la ayuda, los filtros y el paginado quedan fijos. -->
  <div class="flex flex-col min-h-0 text-slate-700 dark:text-slate-300">
    <p class="mb-4 text-base shrink-0 text-slate-600 dark:text-slate-300">
      {{ $t('TRACKING_ASSISTANT_VIEW.SESSIONS_HINT') }}
    </p>

    <woot-loading-state
      v-if="isLoading && !sessions.length"
      :message="$t('TRACKING_TEMPLATES.SESSIONS.LOADING')"
    />
    <p
      v-else-if="!visibleSessions.length"
      class="flex flex-col items-center justify-center h-full py-8 text-base text-slate-600 dark:text-slate-300"
    >
      {{ $t('TRACKING_ASSISTANT_VIEW.SESSIONS_EMPTY') }}
    </p>

    <div v-else class="flex flex-col flex-1 min-h-0">
      <div class="flex-1 min-h-0 overflow-auto">
        <table
          class="min-w-full divide-y divide-slate-75 dark:divide-slate-700"
        >
          <thead class="sticky top-0 z-10 bg-white dark:bg-slate-900">
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
              <td class="max-w-xs py-4 pr-4 font-medium truncate">
                {{
                  row.title || $t('TRACKING_ASSISTANT_VIEW.SESSIONS_UNTITLED')
                }}
              </td>
              <td class="max-w-sm py-4 pr-4 text-sm">
                <div class="line-clamp-2" :title="row.last_change">
                  {{ row.last_change }}
                </div>
              </td>
              <td class="py-4 pr-4">
                {{
                  row.creator ||
                  $t('TRACKING_ASSISTANT_VIEW.SESSIONS_NO_CREATOR')
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
                    v-tooltip.top="
                      $t('TRACKING_ASSISTANT_VIEW.SESSIONS_RESUME')
                    "
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
      </div>
      <TableFooter
        :current-page="sessionsPage"
        :total-count="visibleSessions.length"
        :page-size="SESSIONS_PER_PAGE"
        class="border-t shrink-0 border-slate-50 dark:border-slate-800 !px-0 py-4"
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
