<script>
// feat/licencias (F2b) — PESTAÑA «CUENTAS»
// ============================================================================
// Todas las cuentas de la instalación con su estado de licencia (vista cruzada):
//   sin licencia · demo · vigente · por vencer (en N días) · vencida
// «Por vencer» se marca en la fila cuando quedan 7 días o menos. «Asignar licencia» solo
// con «Gestionar licencias»; «Historial» lo ve cualquiera con acceso.
// ============================================================================
import LicensesAPI from 'dashboard/api/licenses';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import IssueModal from './IssueModal.vue';
import HistoryModal from './HistoryModal.vue';

const STATES = ['', 'sin_licencia', 'demo', 'vigente', 'por_vencer', 'vencida'];
const PER_PAGE = 25;
const SOON_DAYS = 7;
const SEARCH_DELAY_MS = 350;

export default {
  components: { TableFooter, IssueModal, HistoryModal },
  props: {
    plans: { type: Array, default: () => [] },
    canManage: { type: Boolean, default: false },
  },
  data() {
    return {
      states: STATES,
      estado: '',
      dias: SOON_DAYS,
      q: '',
      page: 1,
      rows: [],
      total: 0,
      loading: false,
      loadError: false,
      issuing: null,
      viewing: null,
      searchTimer: null,
    };
  },
  computed: {
    perPage() {
      return PER_PAGE;
    },
  },
  watch: {
    estado() {
      this.reload();
    },
    dias() {
      if (this.estado === 'por_vencer') this.reload();
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
          page: this.page,
          per_page: PER_PAGE,
        });
        this.rows = data.accounts || [];
        this.total = (data.meta && data.meta.total) || 0;
      } catch (error) {
        this.loadError = true;
      } finally {
        this.loading = false;
      }
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
    onIssued() {
      this.issuing = null;
      this.fetch();
    },
    onHistoryClosed(changed) {
      this.viewing = null;
      if (changed) this.fetch();
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0">
    <div class="flex flex-wrap items-center gap-3 mb-4 shrink-0">
      <input
        v-model.trim="q"
        type="search"
        class="!mb-0 !w-72"
        :placeholder="t('ACCOUNTS.SEARCH')"
      />
      <select v-model="estado" class="!mb-0 !w-48">
        <option v-for="state in states" :key="state || 'all'" :value="state">
          {{ stateLabel(state) }}
        </option>
      </select>
      <label
        v-if="estado === 'por_vencer'"
        class="flex items-center gap-2 !mb-0 text-sm text-slate-600 dark:text-slate-300"
      >
        <input
          v-model.number="dias"
          type="number"
          min="1"
          max="365"
          class="!mb-0 !w-20"
        />
        {{ t('ACCOUNTS.DAYS') }}
      </label>
    </div>

    <p v-if="loadError" class="text-sm text-red-600 dark:text-red-400">
      {{ t('LOAD_ERROR') }}
    </p>
    <div v-else class="flex flex-col flex-1 min-h-0">
      <div class="flex-1 min-h-0 overflow-auto">
        <table class="min-w-full overflow-x-auto text-sm">
          <thead>
            <th
              v-for="col in [
                'ACCOUNT',
                'STATE',
                'PLAN',
                'AGENTS',
                'EXPIRES',
                'ACTIONS',
              ]"
              :key="col"
              class="py-4 pr-4 font-semibold text-left whitespace-nowrap text-slate-700 dark:text-slate-300"
            >
              {{ t(`ACCOUNTS.TABLE.${col}`) }}
            </th>
          </thead>
          <tbody
            class="divide-y divide-slate-50 dark:divide-slate-800 text-slate-700 dark:text-slate-300"
          >
            <tr v-for="row in rows" :key="row.id">
              <td class="py-3 pr-4">
                <span class="font-medium">{{ row.name }}</span>
                <span class="text-xs text-slate-500 dark:text-slate-400">
                  #{{ row.id }}
                </span>
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
              <td class="py-3 pr-4">
                <woot-label
                  small
                  class="!mb-0"
                  :color-scheme="stateScheme(row)"
                  :title="t(`STATE.${rowState(row).toUpperCase()}`)"
                />
                <span
                  v-if="row.scheduled_count"
                  class="block mt-1 text-xs text-slate-500 dark:text-slate-400"
                >
                  {{ t('ACCOUNTS.QUEUED', { count: row.scheduled_count }) }}
                </span>
              </td>
              <td class="py-3 pr-4">
                {{ row.license ? row.license.name : '—' }}
              </td>
              <td class="py-3 pr-4 whitespace-nowrap">{{ agentsText(row) }}</td>
              <td class="py-3 pr-4 whitespace-nowrap">
                {{ expiresDate(row) }}
                <span
                  v-if="expiresHint(row)"
                  class="block text-xs text-slate-500 dark:text-slate-400"
                >
                  {{ expiresHint(row) }}
                </span>
              </td>
              <td class="py-3 pr-4">
                <div class="flex items-center gap-2">
                  <woot-button
                    v-if="canManage"
                    size="small"
                    variant="smooth"
                    color-scheme="primary"
                    icon="add"
                    @click="issuing = row"
                  >
                    {{ t('ACCOUNTS.ASSIGN') }}
                  </woot-button>
                  <woot-button
                    size="small"
                    variant="smooth"
                    color-scheme="secondary"
                    icon="document-list-clock"
                    @click="viewing = row"
                  >
                    {{ t('ACCOUNTS.HISTORY') }}
                  </woot-button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
        <p
          v-if="!loading && !rows.length"
          class="py-6 text-sm text-slate-500 dark:text-slate-400"
        >
          {{ t('ACCOUNTS.EMPTY') }}
        </p>
      </div>
      <TableFooter
        :current-page="page"
        :total-count="total"
        :page-size="perPage"
        class="border-t shrink-0 border-slate-50 dark:border-slate-800 !px-0 py-4"
        @pageChange="onPageChange"
      />
    </div>

    <IssueModal
      v-if="issuing"
      :account="issuing"
      :plans="plans"
      @close="issuing = null"
      @issued="onIssued"
    />
    <HistoryModal
      v-if="viewing"
      :account="viewing"
      :can-manage="canManage"
      @close="onHistoryClosed"
    />
  </div>
</template>
