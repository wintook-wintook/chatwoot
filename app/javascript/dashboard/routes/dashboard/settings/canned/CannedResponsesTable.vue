<script>
// proyecto@respuestas_predefinidas R2 — LA TABLA, COMO LA DE CONTACTOS
// ============================================================================
// Plan: docs/respuestas_predefinidas_plan.md §5. Paginación, orden y filtros los hace el
// servidor (CannedResponseFinder: GET canned_responses?page=…); el «/» del editor de
// mensajes sigue usando la lista completa del store, que esta tabla no toca.
//
//   [Buscar…]  Fuente de datos [▾]  Prompt propio [▾]
//   ☐ Nombre ▲ · Contenido · Fuente de datos · Creada ▾ · Cambió ▾ · Acciones
//   Seleccionadas (2): [Vectorizar] [Eliminar]                 ‹ 1 2 3 ›
//
// Editar y eliminar una abren los modales de siempre (los emite a Index.vue).
// ============================================================================
import CannedResponseAPI from 'dashboard/api/cannedResponse';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import { dynamicTime, messageStamp } from 'shared/helpers/timeHelper';
import { useAlert } from 'dashboard/composables';
import EmbeddingState from './EmbeddingState.vue';

const PER_PAGE = 25;
const SEARCH_DELAY = 300;
// D4: se vectorizan hasta 20 a la vez.
const MAX_VECTORIZE = 20;
const POLL_MS = 4000;
const MAX_POLLS = 15;
const STATE_FILTERS = ['', 'not_ready', 'ready', 'pending', 'stale'];
const PROMPT_FILTERS = ['', 'with', 'without'];
const SORTS = ['short_code', 'created_at', 'updated_at'];

export default {
  components: { TableFooter, EmbeddingState },
  emits: ['edit', 'delete'],
  data() {
    return {
      records: [],
      count: 0,
      page: 1,
      summary: {},
      query: '',
      state: '',
      prompt: '',
      sort: 'short_code',
      order: 'asc',
      selected: [],
      busy: {},
      isLoading: false,
      isBulkBusy: false,
      confirmBulkDelete: false,
      stateFilters: STATE_FILTERS,
      promptFilters: PROMPT_FILTERS,
      sorts: SORTS,
      perPage: PER_PAGE,
      maxVectorize: MAX_VECTORIZE,
    };
  },
  computed: {
    allSelected() {
      return (
        this.records.length > 0 &&
        this.records.every(r => this.selected.includes(r.id))
      );
    },
    tooManyToVectorize() {
      return this.selected.length > MAX_VECTORIZE;
    },
    hasPending() {
      return this.records.some(r => r.embedding_state === 'pending');
    },
    filtersActive() {
      return Boolean(this.query.trim() || this.state || this.prompt);
    },
  },
  watch: {
    query() {
      clearTimeout(this.searchTimer);
      this.searchTimer = setTimeout(() => this.goTo(1), SEARCH_DELAY);
    },
    state() {
      this.goTo(1);
    },
    prompt() {
      this.goTo(1);
    },
    hasPending(pendiente) {
      if (pendiente) this.startPolling();
    },
  },
  mounted() {
    this.reload();
  },
  beforeDestroy() {
    clearTimeout(this.searchTimer);
    clearTimeout(this.pollTimer);
  },
  methods: {
    params() {
      return {
        page: this.page,
        per_page: PER_PAGE,
        q: this.query.trim() || undefined,
        state: this.state || undefined,
        prompt: this.prompt || undefined,
        sort: this.sort,
        order: this.order,
      };
    },
    // silent: sin «cargando» (al sondear las que se vectorizan).
    async reload({ silent = false } = {}) {
      if (!silent) this.isLoading = true;
      try {
        const { data } = await CannedResponseAPI.list(this.params());
        this.records = data.payload || [];
        this.count = (data.meta && data.meta.count) || 0;
        this.summary = (data.meta && data.meta.summary) || {};
        const visibles = this.records.map(r => r.id);
        this.selected = this.selected.filter(id => visibles.includes(id));
      } catch (error) {
        if (!silent) useAlert(this.$t('CANNED_MGMT.TABLE.LOAD_ERROR'));
      } finally {
        this.isLoading = false;
      }
    },
    goTo(page) {
      this.page = page;
      this.reload();
    },
    sortBy(columna) {
      if (this.sort === columna) {
        this.order = this.order === 'asc' ? 'desc' : 'asc';
      } else {
        this.sort = columna;
        this.order = columna === 'short_code' ? 'asc' : 'desc';
      }
      this.goTo(1);
    },
    sortIcon(columna) {
      if (this.sort !== columna) return '';
      return this.order === 'asc' ? 'chevron-down' : 'chevron-up';
    },
    toggleAll() {
      this.selected = this.allSelected ? [] : this.records.map(r => r.id);
    },
    toggle(id) {
      this.selected = this.selected.includes(id)
        ? this.selected.filter(s => s !== id)
        : [...this.selected, id];
    },
    replace(actualizadas) {
      const porId = Object.fromEntries(actualizadas.map(r => [r.id, r]));
      this.records = this.records.map(r => porId[r.id] || r);
    },
    async vectorize(item) {
      this.busy = { ...this.busy, [item.id]: true };
      try {
        const { data } = await CannedResponseAPI.vectorize(item.id);
        this.replace([data]);
      } catch (error) {
        useAlert(this.$t('CANNED_MGMT.EMBEDDING.VECTORIZE_ERROR'));
      } finally {
        this.busy = { ...this.busy, [item.id]: false };
      }
    },
    async vectorizeSelected() {
      if (!this.selected.length || this.tooManyToVectorize) return;
      this.isBulkBusy = true;
      try {
        const { data } = await CannedResponseAPI.vectorizeMany(this.selected);
        this.replace(data);
        this.selected = [];
      } catch (error) {
        useAlert(this.$t('CANNED_MGMT.EMBEDDING.VECTORIZE_ERROR'));
      } finally {
        this.isBulkBusy = false;
      }
    },
    async deleteSelected() {
      this.confirmBulkDelete = false;
      this.isBulkBusy = true;
      try {
        await CannedResponseAPI.destroyMany(this.selected);
        useAlert(
          this.$t('CANNED_MGMT.TABLE.BULK_DELETED', {
            count: this.selected.length,
          })
        );
        this.selected = [];
        await this.reload();
      } catch (error) {
        useAlert(this.$t('CANNED_MGMT.DELETE.API.ERROR_MESSAGE'));
      } finally {
        this.isBulkBusy = false;
      }
    },
    startPolling() {
      if (this.pollTimer) return;
      let vueltas = 0;
      const tick = async () => {
        vueltas += 1;
        await this.reload({ silent: true });
        this.pollTimer =
          this.hasPending && vueltas < MAX_POLLS
            ? setTimeout(tick, POLL_MS)
            : null;
      };
      this.pollTimer = setTimeout(tick, POLL_MS);
    },
    closeBulkDelete() {
      this.confirmBulkDelete = false;
    },
    clearFilters() {
      this.query = '';
      this.state = '';
      this.prompt = '';
    },
    relative(fecha) {
      return fecha ? dynamicTime(new Date(fecha).getTime() / 1000) : '—';
    },
    exact(fecha) {
      return fecha
        ? messageStamp(new Date(fecha).getTime() / 1000, 'LLL d yyyy, h:mm a')
        : '';
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- R1: lo que el agente no encontraría, de toda la cuenta. -->
    <div
      v-if="summary.no_key || summary.missing || summary.failed"
      class="flex flex-col gap-1 px-4 py-3 text-sm border rounded-md border-amber-200 bg-amber-50 dark:border-amber-700 dark:bg-amber-900/30 text-amber-800 dark:text-amber-200"
    >
      <span v-if="summary.no_key">
        {{
          $t('CANNED_MGMT.EMBEDDING.BANNER_NO_KEY', { count: summary.no_key })
        }}
      </span>
      <span v-if="summary.missing">
        {{
          $t('CANNED_MGMT.EMBEDDING.BANNER_MISSING', {
            count: summary.missing,
          })
        }}
      </span>
      <span v-if="summary.failed">
        {{
          $t('CANNED_MGMT.EMBEDDING.BANNER_FAILED', { count: summary.failed })
        }}
      </span>
    </div>

    <div class="flex flex-wrap items-end gap-3">
      <div class="flex-1 min-w-[14rem]">
        <input
          v-model="query"
          type="search"
          class="w-full !mb-0"
          :placeholder="$t('CANNED_MGMT.TABLE.SEARCH')"
        />
      </div>
      <label class="flex flex-col !mb-0 text-xs text-slate-500">
        {{ $t('CANNED_MGMT.TABLE.FILTER_STATE') }}
        <select v-model="state" class="!mb-0 w-56">
          <option v-for="opcion in stateFilters" :key="opcion" :value="opcion">
            {{
              $t(`CANNED_MGMT.TABLE.STATE_${(opcion || 'all').toUpperCase()}`)
            }}
          </option>
        </select>
      </label>
      <label class="flex flex-col !mb-0 text-xs text-slate-500">
        {{ $t('CANNED_MGMT.TABLE.FILTER_PROMPT') }}
        <select v-model="prompt" class="!mb-0 w-40">
          <option v-for="opcion in promptFilters" :key="opcion" :value="opcion">
            {{
              $t(`CANNED_MGMT.TABLE.PROMPT_${(opcion || 'all').toUpperCase()}`)
            }}
          </option>
        </select>
      </label>
      <woot-button
        v-if="filtersActive"
        variant="clear"
        color-scheme="secondary"
        size="small"
        @click="clearFilters"
      >
        {{ $t('CANNED_MGMT.TABLE.CLEAR_FILTERS') }}
      </woot-button>
    </div>

    <div
      v-if="selected.length"
      class="flex flex-wrap items-center gap-2 px-3 py-2 rounded-md bg-slate-50 dark:bg-slate-800"
    >
      <span class="text-sm text-slate-700 dark:text-slate-200">
        {{ $t('CANNED_MGMT.TABLE.SELECTED', { count: selected.length }) }}
      </span>
      <woot-button
        size="small"
        variant="smooth"
        icon="arrow-clockwise"
        :is-loading="isBulkBusy"
        :is-disabled="tooManyToVectorize"
        @click="vectorizeSelected"
      >
        {{ $t('CANNED_MGMT.EMBEDDING.VECTORIZE') }}
      </woot-button>
      <woot-button
        size="small"
        variant="smooth"
        color-scheme="alert"
        icon="delete"
        :is-disabled="isBulkBusy"
        @click="confirmBulkDelete = true"
      >
        {{ $t('CANNED_MGMT.TABLE.DELETE_SELECTED') }}
      </woot-button>
      <span v-if="tooManyToVectorize" class="text-xs text-amber-800">
        {{ $t('CANNED_MGMT.TABLE.TOO_MANY', { max: maxVectorize }) }}
      </span>
    </div>

    <woot-loading-state
      v-if="isLoading && !records.length"
      :message="$t('CANNED_MGMT.LOADING')"
    />
    <p
      v-else-if="!records.length"
      class="py-8 text-base text-center text-slate-600 dark:text-slate-300"
    >
      {{
        filtersActive
          ? $t('CANNED_MGMT.TABLE.NO_MATCH')
          : $t('CANNED_MGMT.LIST.404')
      }}
    </p>
    <div v-else class="overflow-x-auto">
      <table
        class="min-w-full divide-y divide-slate-75 dark:divide-slate-700 text-sm"
      >
        <thead>
          <tr>
            <th class="w-8 py-3 pr-2">
              <input
                type="checkbox"
                class="!m-0"
                :checked="allSelected"
                :aria-label="$t('CANNED_MGMT.TABLE.SELECT_ALL')"
                @change="toggleAll"
              />
            </th>
            <th
              v-for="columna in ['short_code']"
              :key="columna"
              class="py-3 pr-4 text-left font-semibold text-slate-700 dark:text-slate-300"
            >
              <button
                type="button"
                class="flex items-center gap-1"
                @click="sortBy(columna)"
              >
                {{ $t('CANNED_MGMT.TABLE.COL_SHORT_CODE') }}
                <fluent-icon
                  v-if="sortIcon(columna)"
                  :icon="sortIcon(columna)"
                  size="14"
                />
              </button>
            </th>
            <th
              class="py-3 pr-4 text-left font-semibold text-slate-700 dark:text-slate-300"
            >
              {{ $t('CANNED_MGMT.TABLE.COL_CONTENT') }}
            </th>
            <th
              class="py-3 pr-4 text-left font-semibold text-slate-700 dark:text-slate-300"
            >
              {{ $t('CANNED_MGMT.TABLE.COL_DATA_SOURCE') }}
            </th>
            <th
              v-for="columna in ['created_at', 'updated_at']"
              :key="columna"
              class="py-3 pr-4 text-left font-semibold whitespace-nowrap text-slate-700 dark:text-slate-300"
            >
              <button
                type="button"
                class="flex items-center gap-1"
                @click="sortBy(columna)"
              >
                {{ $t(`CANNED_MGMT.TABLE.COL_${columna.toUpperCase()}`) }}
                <fluent-icon
                  v-if="sortIcon(columna)"
                  :icon="sortIcon(columna)"
                  size="14"
                />
              </button>
            </th>
            <th
              class="py-3 text-right font-semibold text-slate-700 dark:text-slate-300"
            >
              {{ $t('CANNED_MGMT.TABLE.COL_ACTIONS') }}
            </th>
          </tr>
        </thead>
        <tbody
          class="divide-y divide-slate-50 dark:divide-slate-800 text-slate-700 dark:text-slate-300"
        >
          <tr v-for="item in records" :key="item.id">
            <td class="py-3 pr-2 align-top">
              <input
                type="checkbox"
                class="!m-0"
                :checked="selected.includes(item.id)"
                :aria-label="item.short_code"
                @change="toggle(item.id)"
              />
            </td>
            <td
              class="max-w-xs py-3 pr-4 font-medium align-top truncate"
              :title="item.short_code"
            >
              {{ item.short_code }}
              <span
                v-if="item.content_prompts"
                class="ml-1 px-1.5 py-0.5 text-xs font-normal rounded bg-woot-50 text-woot-600 dark:bg-woot-800 dark:text-woot-100"
              >
                {{ $t('CANNED_MGMT.FORM_PROMPT.LIST_BADGE') }}
              </span>
              <span
                v-if="item.content_is_prompt"
                class="ml-1 px-1.5 py-0.5 text-xs font-normal rounded bg-woot-50 text-woot-600 dark:bg-woot-800 dark:text-woot-100"
              >
                {{ $t('CANNED_MGMT.FORM_PROMPT.LIST_BADGE_IS_PROMPT') }}
              </span>
            </td>
            <td class="py-3 pr-4 align-top whitespace-normal md:break-all">
              <div class="line-clamp-2" :title="item.content">
                {{ item.content }}
              </div>
            </td>
            <td class="py-3 pr-4 align-top">
              <EmbeddingState
                :item="item"
                :busy="!!busy[item.id]"
                @vectorize="vectorize"
              />
            </td>
            <td
              class="py-3 pr-4 align-top whitespace-nowrap"
              :title="exact(item.created_at)"
            >
              {{ relative(item.created_at) }}
            </td>
            <td
              class="py-3 pr-4 align-top whitespace-nowrap"
              :title="exact(item.updated_at)"
            >
              {{ relative(item.updated_at) }}
            </td>
            <td class="py-3 align-top">
              <div class="flex justify-end gap-1">
                <woot-button
                  v-tooltip.top="$t('CANNED_MGMT.EDIT.BUTTON_TEXT')"
                  variant="smooth"
                  size="tiny"
                  color-scheme="secondary"
                  icon="edit"
                  @click="$emit('edit', item)"
                />
                <woot-button
                  v-tooltip.top="$t('CANNED_MGMT.DELETE.BUTTON_TEXT')"
                  variant="smooth"
                  color-scheme="alert"
                  size="tiny"
                  icon="dismiss-circle"
                  @click="$emit('delete', item)"
                />
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <TableFooter
      :current-page="page"
      :page-size="perPage"
      :total-count="count"
      @pageChange="goTo"
    />

    <woot-delete-modal
      :show.sync="confirmBulkDelete"
      :on-close="closeBulkDelete"
      :on-confirm="deleteSelected"
      :title="$t('CANNED_MGMT.TABLE.BULK_DELETE_TITLE')"
      :message="
        $t('CANNED_MGMT.TABLE.BULK_DELETE_MESSAGE', { count: selected.length })
      "
      :confirm-text="$t('CANNED_MGMT.TABLE.BULK_DELETE_YES')"
      :reject-text="$t('CANNED_MGMT.DELETE.CONFIRM.NO')"
    />
  </div>
</template>
