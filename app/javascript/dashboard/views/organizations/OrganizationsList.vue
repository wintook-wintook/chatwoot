<!--
  Plan-Organizaciones O1 — Clientes › Organizaciones: prospectos y clientes con pestañas
  por etapa (con cuántas hay), búsqueda por nombre, RFC o dominio, filtro Empresa /
  Público en general y alta. O4: asistente para los contactos que ya existían e
  importación CSV.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import OrganizationsAPI from 'dashboard/api/organizations';
import Spinner from 'shared/components/Spinner.vue';
import OrganizationForm from './OrganizationForm.vue';
import OrganizationSuggestions from './OrganizationSuggestions.vue';
import {
  KINDS,
  STAGES,
  organizationAccess,
  stageChipClass,
} from './organizationHelpers';

export default {
  name: 'OrganizationsList',
  components: { Spinner, OrganizationForm, OrganizationSuggestions },
  data() {
    return {
      organizations: [],
      counts: {},
      count: 0,
      page: 1,
      perPage: 50,
      loading: true,
      filters: { q: '', stage: 'prospect', kind: '' },
      showForm: false,
      showAssistant: false,
      timer: null,
    };
  },
  computed: {
    ...mapGetters({ currentUser: 'getCurrentUser' }),
    access() {
      return organizationAccess(this.currentUser, this.$route.params.accountId);
    },
    tabs() {
      return [...STAGES, ''].map(key => ({
        key,
        count: this.counts[key || 'all'] || 0,
      }));
    },
    kinds() {
      return KINDS;
    },
    pages() {
      return Math.max(1, Math.ceil(this.count / this.perPage));
    },
  },
  watch: {
    'filters.stage': 'reload',
    'filters.kind': 'reload',
  },
  mounted() {
    this.fetch();
  },
  methods: {
    stageChipClass,
    reload() {
      this.page = 1;
      this.fetch();
    },
    onSearch() {
      clearTimeout(this.timer);
      this.timer = setTimeout(this.reload, 300);
    },
    async fetch() {
      this.loading = true;
      try {
        const { data } = await OrganizationsAPI.list({
          ...this.filters,
          page: this.page,
        });
        this.organizations = data.organizations || [];
        this.count = data.meta.count;
        this.perPage = data.meta.per_page;
        this.counts = data.meta.counts || {};
      } catch {
        this.organizations = [];
      } finally {
        this.loading = false;
      }
    },
    goTo(page) {
      this.page = page;
      this.fetch();
    },
    open(organization) {
      this.$router.push({
        name: 'organization_detail',
        params: {
          accountId: this.$route.params.accountId,
          organizationId: organization.id,
        },
      });
    },
    onApplied() {
      this.showAssistant = false;
      this.reload();
    },
    async downloadTemplate() {
      const { data } = await OrganizationsAPI.template();
      const url = URL.createObjectURL(data);
      const link = document.createElement('a');
      link.href = url;
      link.download = 'organizaciones.csv';
      link.click();
      URL.revokeObjectURL(url);
    },
    async importCsv(event) {
      const [file] = event.target.files || [];
      event.target.value = '';
      if (!file) return;
      try {
        const { data } = await OrganizationsAPI.importCsv(file);
        useAlert(
          this.$t('ORGANIZATIONS.IMPORT_DONE', {
            created: data.created,
            updated: data.updated,
          })
        );
        if (data.errors && data.errors.length) {
          const [first] = data.errors;
          useAlert(
            this.$t('ORGANIZATIONS.IMPORT_ERRORS', {
              count: data.errors.length,
              line: first.line,
              error: first.error,
            })
          );
        }
        this.reload();
      } catch (error) {
        useAlert(
          error?.response?.data?.error || this.$t('ORGANIZATIONS.ERROR')
        );
      }
    },
    onSaved(organization) {
      this.showForm = false;
      this.open(organization);
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
          {{ $t('ORGANIZATIONS.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
          {{ $t('ORGANIZATIONS.DESCRIPTION') }}
        </p>
      </div>
      <div v-if="access.canEdit" class="flex flex-wrap items-center gap-2">
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          size="small"
          icon="people-team"
          @click="showAssistant = true"
        >
          {{ $t('ORGANIZATIONS.ASSISTANT.OPEN') }}
        </woot-button>
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          size="small"
          icon="arrow-download"
          @click="downloadTemplate"
        >
          {{ $t('ORGANIZATIONS.TEMPLATE') }}
        </woot-button>
        <label
          v-tooltip="$t('ORGANIZATIONS.IMPORT_HELP')"
          class="mb-0 cursor-pointer button smooth secondary small"
        >
          {{ $t('ORGANIZATIONS.IMPORT') }}
          <input
            type="file"
            accept=".csv,text/csv"
            class="hidden"
            @change="importCsv"
          />
        </label>
        <woot-button size="small" icon="add" @click="showForm = true">
          {{ $t('ORGANIZATIONS.NEW') }}
        </woot-button>
      </div>
    </header>

    <!-- Pestañas por etapa, con cuántas hay en cada una -->
    <nav
      class="flex flex-wrap gap-1 px-6 pb-2 border-b border-slate-50 dark:border-slate-800"
    >
      <button
        v-for="tab in tabs"
        :key="tab.key || 'all'"
        type="button"
        class="flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-md"
        :class="
          filters.stage === tab.key
            ? 'bg-woot-50 text-woot-700 font-semibold dark:bg-woot-800 dark:text-woot-100'
            : 'text-slate-600 hover:bg-slate-50 dark:text-slate-300 dark:hover:bg-slate-800'
        "
        @click="filters.stage = tab.key"
      >
        {{ $t(`ORGANIZATIONS.TABS.${tab.key || 'all'}`) }}
        <span class="text-xs opacity-70">{{ tab.count }}</span>
      </button>
    </nav>

    <div class="flex flex-wrap items-center gap-2 px-6 py-3">
      <input
        v-model="filters.q"
        type="search"
        class="!mb-0 max-w-xs"
        :placeholder="$t('ORGANIZATIONS.SEARCH')"
        @input="onSearch"
      />
      <select v-model="filters.kind" class="!mb-0 w-52">
        <option value="">{{ $t('ORGANIZATIONS.ALL_KINDS') }}</option>
        <option v-for="kind in kinds" :key="kind" :value="kind">
          {{ $t(`ORGANIZATIONS.KINDS.${kind}`) }}
        </option>
      </select>
      <span class="ml-auto text-xs text-slate-500">
        {{ $t('ORGANIZATIONS.TOTAL', { count }) }}
      </span>
    </div>

    <div class="flex-1 px-6 pb-4 overflow-auto">
      <Spinner v-if="loading" />
      <p
        v-else-if="!organizations.length"
        class="py-12 text-sm text-center text-slate-500 dark:text-slate-400"
      >
        {{ $t('ORGANIZATIONS.EMPTY') }}
      </p>
      <table v-else class="w-full text-sm">
        <thead>
          <tr
            class="text-left border-b text-slate-500 dark:text-slate-400 border-slate-50 dark:border-slate-800"
          >
            <th class="px-3 py-2 font-medium">
              {{ $t('ORGANIZATIONS.COLUMNS.NAME') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('ORGANIZATIONS.COLUMNS.STAGE') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('ORGANIZATIONS.COLUMNS.TAX_ID') }}
            </th>
            <th class="px-3 py-2 font-medium text-right">
              {{ $t('ORGANIZATIONS.COLUMNS.CONTACTS') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ $t('ORGANIZATIONS.COLUMNS.OWNER') }}
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-50 dark:divide-slate-800">
          <tr
            v-for="organization in organizations"
            :key="organization.id"
            class="cursor-pointer hover:bg-slate-25 dark:hover:bg-slate-800/50"
            @click="open(organization)"
          >
            <td class="px-3 py-2">
              <span
                class="font-medium text-woot-600 dark:text-woot-300 hover:underline"
              >
                {{ organization.name }}
              </span>
              <span class="block text-xs text-slate-500">
                {{ $t(`ORGANIZATIONS.KINDS.${organization.kind}`) }}
                <template v-if="organization.industry">
                  · {{ organization.industry }}
                </template>
              </span>
            </td>
            <td class="px-3 py-2">
              <span
                class="px-2 py-0.5 text-xs font-medium rounded-full whitespace-nowrap"
                :class="stageChipClass(organization.stage)"
              >
                {{ $t(`ORGANIZATIONS.STAGES.${organization.stage}`) }}
              </span>
            </td>
            <td class="px-3 py-2 text-slate-600 dark:text-slate-300">
              {{ organization.tax_id || '—' }}
            </td>
            <td class="px-3 py-2 text-right">
              {{ organization.contacts_count }}
            </td>
            <td class="px-3 py-2 text-slate-600 dark:text-slate-300">
              {{ (organization.owner && organization.owner.name) || '—' }}
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

    <OrganizationSuggestions
      :show="showAssistant"
      @close="showAssistant = false"
      @applied="onApplied"
    />
    <OrganizationForm
      :show="showForm"
      @close="showForm = false"
      @saved="onSaved"
    />
  </div>
</template>
