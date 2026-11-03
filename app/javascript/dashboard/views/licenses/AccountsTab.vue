<script>
// feat/licencias (F2b) — PESTAÑA «CUENTAS»
// ============================================================================
// Todas las cuentas de la instalación con su estado de licencia (vista cruzada):
//   sin licencia · demo · vigente · por vencer (en N días) · vencida
// «Por vencer» se marca en la fila cuando quedan 7 días o menos. «Asignar licencia» solo
// con «Gestionar licencias»; «Historial» lo ve cualquiera con acceso. El nombre abre la ficha de
// la cuenta (F6) e «Historial», su pestaña Licencias.
// Se ve como la lista de plantillas de WhatsApp: filtros en recuadro, tabla con encabezado
// fijo y solo ella con scroll, acciones junto al nombre y paginado con «por página».
// Clic en la columna para ordenar; por omisión, la cuenta creada más reciente primero. El
// orden lo hace el servidor (la tabla se pagina allá).
// ============================================================================
import LicensesAPI from 'dashboard/api/licenses';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';

const STATES = ['', 'sin_licencia', 'demo', 'vigente', 'por_vencer', 'vencida'];
const PER_PAGE = 25;
const PER_PAGE_OPTIONS = [10, 25, 50, 100]; // el servidor llega hasta 100
const SOON_DAYS = 7;
const SEARCH_DELAY_MS = 350;
// Columna de la tabla → `sort` del servidor. Las demás no se ordenan (se calculan).
const SORTS = {
  ACCOUNT: 'name',
  EXPIRES: 'expires_at',
  CREATED: 'created_at',
  UPDATED: 'updated_at',
};
const DATE_SORTS = ['expires_at', 'created_at', 'updated_at'];
// Una cuenta que nunca se modificó después de crearse no tiene «última modificación».
const SAME_MOMENT_MS = 60 * 1000;

export default {
  components: { TableFooter },
  props: {
    canManage: { type: Boolean, default: false },
    // F4: una tarjeta del resumen abre esta pestaña ya filtrada.
    initialEstado: { type: String, default: '' },
    initialDias: { type: Number, default: SOON_DAYS },
  },
  data() {
    return {
      states: STATES,
      estado: this.initialEstado,
      dias: this.initialDias,
      q: '',
      sortKey: 'created_at',
      sortDir: 'desc',
      page: 1,
      perPage: PER_PAGE,
      perPageOptions: PER_PAGE_OPTIONS,
      rows: [],
      total: 0,
      loading: false,
      loadError: false,
      searchTimer: null,
    };
  },
  computed: {
    hasActiveFilters() {
      return Boolean(this.q || this.estado);
    },
    columns() {
      return [
        'ACCOUNT',
        'ACTIONS',
        'STATE',
        'PLAN',
        'AGENTS',
        'EXPIRES',
        'CREATED',
        'UPDATED',
      ].map(key => ({ key, sort: SORTS[key] || null }));
    },
  },
  watch: {
    estado() {
      this.reload();
    },
    dias() {
      if (this.estado === 'por_vencer') this.reload();
    },
    perPage() {
      this.reload();
    },
    q() {
      clearTimeout(this.searchTimer);
      this.searchTimer = setTimeout(this.reload, SEARCH_DELAY_MS);
    },
  },
  mounted() {
    this.fetch();
  },
  beforeDestroy() {
    clearTimeout(this.searchTimer);
  },
  methods: {
    t(key, args) {
      return this.$t(`LICENSES.${key}`, args);
    },
    reload() {
      this.page = 1;
      this.fetch();
    },
    async fetch() {
      this.loading = true;
      this.loadError = false;
      try {
        const { data } = await LicensesAPI.getAccounts({
          estado: this.estado || undefined,
          dias: this.dias,
          q: this.q || undefined,
          sort: this.sortKey,
          dir: this.sortDir,
          page: this.page,
          per_page: this.perPage,
        });
        this.rows = data.accounts || [];
        this.total = (data.meta && data.meta.total) || 0;
      } catch (error) {
        this.loadError = true;
      } finally {
        this.loading = false;
      }
    },
    sortBy(key) {
      if (this.sortKey === key) {
        this.sortDir = this.sortDir === 'asc' ? 'desc' : 'asc';
      } else {
        this.sortKey = key;
        this.sortDir = DATE_SORTS.includes(key) ? 'desc' : 'asc';
      }
      this.reload();
    },
    sortIcon(key) {
      if (this.sortKey !== key) return 'arrow-sort';
      return this.sortDir === 'asc' ? 'chevron-up' : 'chevron-down';
    },
    formatDate(fecha) {
      if (!fecha) return '—';
      return new Date(fecha).toLocaleString(this.$i18n.locale || 'es', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    updatedDate(row) {
      if (!row.updated_at || !row.created_at) return '—';
      const cambio = new Date(row.updated_at) - new Date(row.created_at);
      return cambio < SAME_MOMENT_MS ? '—' : this.formatDate(row.updated_at);
    },
    clearFilters() {
      this.q = '';
      this.estado = '';
    },
    onPageChange(page) {
      this.page = page;
      this.fetch();
    },
    stateLabel(state) {
      return state
        ? this.t(`STATE.${state.toUpperCase()}`)
        : this.t('ACCOUNTS.STATE_ALL');
    },
    // Lo que dice la fila: demo y de pago pasan a «Por vencer» con 7 días o menos.
    rowState(row) {
      const lic = row.license;
      if (lic && lic.days_left !== null && lic.days_left <= SOON_DAYS)
        return 'por_vencer';
      return row.license_state;
    },
    stateScheme(row) {
      return {
        sin_licencia: 'secondary',
        demo: 'primary',
        paid: 'success',
        por_vencer: 'warning',
        vencida: 'alert',
      }[this.rowState(row)];
    },
    agentsText(row) {
      return row.license
        ? `${row.agents_count} / ${row.license.max_agents}`
        : `${row.agents_count}`;
    },
    expiresDate(row) {
      if (!row.license || !row.license.expires_at) return '—';
      return new Date(row.license.expires_at).toLocaleDateString(
        this.$i18n.locale
      );
    },
    expiresHint(row) {
      if (!row.license || row.license.days_left === null) return '';
      const dias = row.license.days_left;
      return dias >= 0
        ? this.t('ACCOUNTS.DAYS_LEFT', { count: dias })
        : this.t('ACCOUNTS.EXPIRED_AGO', { count: -dias });
    },
    detailRoute(row, tab) {
      return {
        name: 'licenses_accounts_show',
        params: { licensedAccountId: row.id },
        query: tab ? { tab } : {},
      };
    },
  },
};
</script>

<template>
  <div class="flex flex-col w-full h-[calc(100vh-13rem)] min-h-[20rem]">
    <div
      class="flex flex-wrap items-center gap-2 p-3 mb-4 border border-solid rounded-lg shrink-0 bg-white dark:bg-slate-800 border-slate-100 dark:border-slate-700"
    >
      <div class="relative w-64">
        <input
          v-model.trim="q"
          type="text"
          :placeholder="t('ACCOUNTS.SEARCH')"
          class="reset-base box-border w-full h-9 m-0 text-sm rounded-md border border-solid border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 pl-8 pr-2 outline-none focus:border-woot-500 dark:focus:border-woot-600"
        />
        <fluent-icon
          icon="search"
          size="16"
          class="absolute -translate-y-1/2 left-2 top-1/2 text-slate-400"
        />
      </div>
      <select v-model="estado" class="list-filter">
        <option v-for="state in states" :key="state || 'all'" :value="state">
          {{ stateLabel(state) }}
        </option>
      </select>
      <label
        v-if="estado === 'por_vencer'"
        class="flex items-center gap-2 mb-0 text-sm text-slate-600 dark:text-slate-300"
      >
        <input
          v-model.number="dias"
          type="number"
          min="1"
          max="365"
          class="!w-20 h-9 !mb-0 text-sm"
        />
        {{ t('ACCOUNTS.DAYS') }}
      </label>
      <woot-button
        v-if="hasActiveFilters"
        variant="clear"
        size="small"
        @click="clearFilters"
      >
        {{ t('LIST.CLEAR') }}
      </woot-button>
    </div>

    <p v-if="loadError" class="text-sm text-red-600 dark:text-red-400">
      {{ t('LOAD_ERROR') }}
    </p>
    <template v-else>
      <div class="flex-1 min-h-0 overflow-y-auto">
        <div
          v-if="!loading && !rows.length"
          class="py-16 text-center border border-dashed rounded-lg text-slate-400 border-slate-200 dark:border-slate-700"
        >
          {{ t('ACCOUNTS.EMPTY') }}
        </div>
        <table v-else class="w-full text-sm">
          <thead
            class="sticky top-0 z-10 text-left bg-white border-b text-slate-400 border-slate-100 dark:border-slate-700 dark:bg-slate-900"
          >
            <tr>
              <th
                v-for="col in columns"
                :key="col.key"
                class="py-2 pr-3 font-medium whitespace-nowrap"
              >
                <button
                  v-if="col.sort"
                  type="button"
                  class="sort-header"
                  :class="{ 'sort-header--active': sortKey === col.sort }"
                  @click="sortBy(col.sort)"
                >
                  {{ t(`ACCOUNTS.TABLE.${col.key}`) }}
                  <fluent-icon :icon="sortIcon(col.sort)" size="12" />
                </button>
                <span v-else>{{ t(`ACCOUNTS.TABLE.${col.key}`) }}</span>
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in rows"
              :key="row.id"
              class="border-b border-slate-50 dark:border-slate-800"
            >
              <td class="py-2 pr-3">
                <router-link
                  :to="detailRoute(row)"
                  class="font-medium text-slate-700 dark:text-slate-200 hover:text-woot-600 hover:underline"
                >
                  {{ row.name }}
                </router-link>
                <span class="text-xs text-slate-400">#{{ row.id }}</span>
                <woot-label
                  v-if="row.wintook_internal"
                  small
                  color-scheme="primary"
                  class="!mb-0 ltr:ml-2 rtl:mr-2"
                  :title="t('ACCOUNTS.WINTOOK')"
                />
                <woot-label
                  v-if="row.status === 'suspended'"
                  small
                  color-scheme="alert"
                  class="!mb-0 ltr:ml-2 rtl:mr-2"
                  :title="t('ACCOUNTS.SUSPENDED')"
                />
              </td>
              <td class="py-2 pr-3">
                <div class="flex items-center gap-1.5 whitespace-nowrap">
                  <woot-button
                    v-if="canManage"
                    variant="smooth"
                    color-scheme="secondary"
                    size="small"
                    icon="add-circle"
                    :title="t('ACCOUNTS.ASSIGN')"
                    @click="
                      $router.push({
                        name: 'licenses_accounts_issue',
                        params: { licensedAccountId: row.id },
                      })
                    "
                  />
                  <woot-button
                    variant="smooth"
                    color-scheme="secondary"
                    size="small"
                    icon="document-list-clock"
                    :title="t('ACCOUNTS.HISTORY')"
                    @click="$router.push(detailRoute(row, 'licenses'))"
                  />
                </div>
              </td>
              <td class="py-2 pr-3 whitespace-nowrap">
                <woot-label
                  small
                  class="!mb-0"
                  :color-scheme="stateScheme(row)"
                  :title="t(`STATE.${rowState(row).toUpperCase()}`)"
                />
                <span
                  v-if="row.scheduled_count"
                  class="block mt-1 text-xs text-slate-400"
                >
                  {{ t('ACCOUNTS.QUEUED', { count: row.scheduled_count }) }}
                </span>
              </td>
              <td class="py-2 pr-3 text-slate-500">
                {{ row.license ? row.license.name : '—' }}
              </td>
              <td class="py-2 pr-3 text-slate-500 whitespace-nowrap">
                {{ agentsText(row) }}
              </td>
              <td class="py-2 pr-3 text-xs text-slate-500 whitespace-nowrap">
                <div>{{ expiresDate(row) }}</div>
                <div v-if="expiresHint(row)" class="text-slate-400">
                  {{ expiresHint(row) }}
                </div>
              </td>
              <td class="py-2 pr-3 text-xs text-slate-500 whitespace-nowrap">
                {{ formatDate(row.created_at) }}
              </td>
              <td class="py-2 pr-3 text-xs text-slate-500 whitespace-nowrap">
                {{ updatedDate(row) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div
        v-if="total"
        class="flex items-center gap-3 border-t shrink-0 border-slate-100 dark:border-slate-700"
      >
        <label
          class="flex items-center gap-2 mb-0 text-xs whitespace-nowrap text-slate-500"
        >
          {{ t('LIST.PER_PAGE') }}
          <select v-model.number="perPage" class="!w-auto h-8 !mb-0 text-xs">
            <option v-for="n in perPageOptions" :key="n" :value="n">
              {{ n }}
            </option>
          </select>
        </label>
        <TableFooter
          class="flex-1"
          :current-page="page"
          :total-count="total"
          :page-size="perPage"
          @pageChange="onPageChange"
        />
      </div>
    </template>
  </div>
</template>

<style scoped lang="scss">
.list-filter {
  @apply w-auto h-9 mb-0 text-sm;
}

.sort-header {
  @apply inline-flex items-center gap-1 p-0 font-medium bg-transparent border-0 cursor-pointer text-slate-400 hover:text-slate-700 dark:hover:text-slate-200;
}

.sort-header--active {
  @apply text-slate-700 dark:text-slate-200;
}
</style>
