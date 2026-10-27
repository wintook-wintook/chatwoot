<!--
  Plan-Contratos R1 — Clientes › Contratos: todos los contratos de la empresa con
  pestañas por estado (al corriente, por renovar, pago vencido…), búsqueda, tipo,
  alta e importación desde CSV.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ContractsAPI from 'dashboard/api/contracts';
import ContractTypesAPI from 'dashboard/api/contractTypes';
import Spinner from 'shared/components/Spinner.vue';
import ContractForm from './ContractForm.vue';
import ContractActions from './ContractActions.vue';
import {
  STATES,
  contractAccess,
  contractAmount,
  everyLabel,
  formatDate,
  stateChipClass,
} from './contractHelpers';

export default {
  name: 'ContractsList',
  components: { Spinner, ContractForm, ContractActions },
  data() {
    return {
      contracts: [],
      types: [],
      counts: {},
      count: 0,
      page: 1,
      perPage: 50,
      loading: true,
      filters: { q: '', state: '', contract_type_id: '' },
      form: null,
      timer: null,
    };
  },
  computed: {
    ...mapGetters({ currentUser: 'getCurrentUser' }),
    access() {
      return contractAccess(this.currentUser, this.$route.params.accountId);
    },
    tabs() {
      const total = STATES.reduce(
        (sum, state) => sum + (this.counts[state] || 0),
        0
      );
      return [
        { key: '', count: total },
        ...STATES.map(key => ({ key, count: this.counts[key] || 0 })),
      ];
    },
    pages() {
      return Math.max(1, Math.ceil(this.count / this.perPage));
    },
  },
  watch: {
    'filters.state': 'reload',
    'filters.contract_type_id': 'reload',
  },
  mounted() {
    this.fetchTypes();
    this.fetch();
  },
  methods: {
    everyLabel(contract) {
      return everyLabel(this.$t.bind(this), contract.every, contract.unit);
    },
    formatDate,
    contractAmount,
    stateChipClass,
    reload() {
      this.page = 1;
      this.fetch();
    },
    onSearch() {
      clearTimeout(this.timer);
      this.timer = setTimeout(this.reload, 300);
    },
    async fetchTypes() {
      try {
        const { data } = await ContractTypesAPI.list();
        this.types = data.contract_types || [];
      } catch {
        this.types = [];
      }
    },
    async fetch() {
      this.loading = true;
      try {
        const { data } = await ContractsAPI.list({
          ...this.filters,
          page: this.page,
        });
        this.contracts = data.contracts || [];
        this.count = data.meta.count;
        this.perPage = data.meta.per_page;
        this.counts = data.meta.counts || {};
      } catch {
        this.contracts = [];
      } finally {
        this.loading = false;
      }
    },
    goTo(page) {
      this.page = page;
      this.fetch();
    },
    openContact(contract) {
      this.$router.push({
        name: 'contact_profile_dashboard',
        params: {
          accountId: this.$route.params.accountId,
          contactId: contract.contact_id,
        },
        query: { tab: 'contracts' },
      });
    },
    onSaved() {
      this.form = null;
      this.fetch();
    },
    async downloadTemplate() {
      const { data } = await ContractsAPI.template();
      const url = URL.createObjectURL(data);
      const link = document.createElement('a');
      link.href = url;
      link.download = 'contratos.csv';
      link.click();
      URL.revokeObjectURL(url);
    },
    async importCsv(event) {
      const [file] = event.target.files || [];
      event.target.value = '';
      if (!file) return;
      try {
        const { data } = await ContractsAPI.importCsv(file);
        useAlert(
          this.$t('CONTRACTS.IMPORT_DONE', {
            created: data.created,
            updated: data.updated,
          })
        );
        if (data.errors && data.errors.length) {
          const [first] = data.errors;
          useAlert(
            this.$t('CONTRACTS.IMPORT_ERRORS', {
              count: data.errors.length,
              line: first.line,
              error: first.error,
            })
          );
        }
        this.reload();
      } catch (error) {
        useAlert(error?.response?.data?.error || this.$t('CONTRACTS.ERROR'));
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-white dark:bg-slate-900"
  >
    <header
      class="flex flex-wrap items-start justify-between gap-3 px-6 pt-5 pb-3"
    >
      <div>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CONTRACTS.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
          {{ $t('CONTRACTS.DESCRIPTION') }}
        </p>
      </div>
      <div v-if="access.canEdit" class="flex items-center gap-2">
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          size="small"
          icon="arrow-download"
          @click="downloadTemplate"
        >
          {{ $t('CONTRACTS.TEMPLATE') }}
        </woot-button>
        <label
          v-tooltip="$t('CONTRACTS.IMPORT_HELP')"
          class="mb-0 cursor-pointer button smooth secondary small"
        >
          {{ $t('CONTRACTS.IMPORT') }}
          <input
            type="file"
            accept=".csv,text/csv"
            class="hidden"
            @change="importCsv"
          />
        </label>
        <woot-button size="small" icon="add" @click="form = { contract: null }">
          {{ $t('CONTRACTS.NEW') }}
        </woot-button>
      </div>
    </header>

    <!-- Pestañas por estado, con cuántos hay en cada uno -->
    <nav
      class="flex flex-wrap gap-1 px-6 pb-2 border-b border-slate-50 dark:border-slate-800"
    >
      <button
        v-for="tab in tabs"
        :key="tab.key || 'all'"
        type="button"
        class="flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-md"
        :class="
          filters.state === tab.key
            ? 'bg-woot-50 text-woot-700 font-semibold dark:bg-woot-800 dark:text-woot-100'
            : 'text-slate-600 hover:bg-slate-50 dark:text-slate-300 dark:hover:bg-slate-800'
        "
        @click="filters.state = tab.key"
      >
        {{ $t(`CONTRACTS.STATES.${tab.key || 'all'}`) }}
        <span class="text-xs opacity-70">{{ tab.count }}</span>
      </button>
    </nav>

    <div class="flex flex-wrap items-center gap-2 px-6 py-3">
      <input
        v-model="filters.q"
        type="search"
        class="!mb-0 max-w-xs"
        :placeholder="$t('CONTRACTS.SEARCH')"
        @input="onSearch"
      />
      <select v-model="filters.contract_type_id" class="!mb-0 w-52">
        <option value="">{{ $t('CONTRACTS.ALL_TYPES') }}</option>
        <option v-for="type in types" :key="type.id" :value="type.id">
          {{ type.name }}
        </option>
      </select>
      <span class="ml-auto text-xs text-slate-500">
        {{ $t('CONTRACTS.TOTAL', { count }) }}
      </span>
    </div>

    <div class="flex-1 px-6 pb-4 overflow-auto">
      <Spinner v-if="loading" />
      <p
        v-else-if="!contracts.length"
        class="py-12 text-sm text-center text-slate-500 dark:text-slate-400"
      >
        {{ $t('CONTRACTS.EMPTY') }}
      </p>
      <table v-else class="w-full text-sm">
        <thead>
          <tr
            class="text-left border-b text-slate-500 dark:text-slate-400 border-slate-50 dark:border-slate-800"
          >
            <th class="px-3 py-2 font-medium">
              {{ $t('CONTRACTS.COLUMNS.CLIENT') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CONTRACTS.COLUMNS.CONCEPT') }}
            </th>
            <th v-if="access.showAmounts" class="px-3 py-2 font-medium text-right">
              {{ $t('CONTRACTS.COLUMNS.AMOUNT') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CONTRACTS.COLUMNS.NEXT_CHARGE') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CONTRACTS.COLUMNS.ENDS') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CONTRACTS.COLUMNS.STATE') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('CONTRACTS.COLUMNS.ASSIGNEE') }}
            </th>
            <th class="w-8" />
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-50 dark:divide-slate-800">
          <tr
            v-for="contract in contracts"
            :key="contract.id"
            class="hover:bg-slate-25 dark:hover:bg-slate-800/50"
          >
            <td class="px-3 py-2">
              <button
                type="button"
                class="p-0 font-medium text-left text-woot-600 dark:text-woot-300 hover:underline"
                @click="openContact(contract)"
              >
                {{ contract.links.contact && contract.links.contact.name }}
              </button>
            </td>
            <td class="px-3 py-2">
              <span class="flex items-center gap-2">
                <span
                  class="flex-shrink-0 w-2 h-2 rounded-full"
                  :style="{
                    backgroundColor:
                      contract.links.contract_type &&
                      contract.links.contract_type.color,
                  }"
                />
                <span class="text-slate-800 dark:text-slate-100">
                  {{ contract.title }}
                </span>
              </span>
              <span class="ml-4 text-xs text-slate-500">
                {{
                  contract.links.contract_type &&
                  contract.links.contract_type.name
                }}
                · {{ everyLabel(contract) }}
              </span>
            </td>
            <td
              v-if="access.showAmounts"
              class="px-3 py-2 text-right whitespace-nowrap"
            >
              {{ contractAmount(contract) }}
            </td>
            <td class="px-3 py-2 whitespace-nowrap">
              {{ formatDate(contract.next_charge_on) || '—' }}
            </td>
            <td class="px-3 py-2 whitespace-nowrap">
              {{ formatDate(contract.ends_on) || $t('CONTRACTS.CARD.NO_TERM') }}
            </td>
            <td class="px-3 py-2">
              <span
                class="px-2 py-0.5 text-xs font-medium rounded-full whitespace-nowrap"
                :class="stateChipClass(contract.state)"
              >
                {{ $t(`CONTRACTS.STATES.${contract.state}`) }}
              </span>
            </td>
            <td class="px-3 py-2 text-slate-600 dark:text-slate-300">
              {{ (contract.links.assignee && contract.links.assignee.name) || '—' }}
            </td>
            <td class="px-1 py-2">
              <ContractActions
                :contract="contract"
                :can-edit="access.canEdit"
                @changed="fetch"
                @edit="item => (form = { contract: item })"
              />
            </td>
          </tr>
        </tbody>
      </table>
      <div
        v-if="pages > 1"
        class="flex items-center justify-end gap-2 pt-3 text-sm"
      >
        <woot-button
          size="tiny"
          variant="clear"
          :disabled="page <= 1"
          icon="chevron-left"
          @click="goTo(page - 1)"
        />
        <span>{{ page }} / {{ pages }}</span>
        <woot-button
          size="tiny"
          variant="clear"
          :disabled="page >= pages"
          icon="chevron-right"
          @click="goTo(page + 1)"
        />
      </div>
    </div>

    <ContractForm
      :show="!!form"
      :contract="form && form.contract"
      :types="types"
      :show-amounts="access.showAmounts"
      @close="form = null"
      @saved="onSaved"
    />
  </div>
</template>
