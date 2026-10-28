<!--
  CrmZeus O2 — Catálogos de organizaciones (los cambia el Administrador; los demás
  solo los consultan): tipo de cliente, calificación, giro, origen, zona, cobrador,
  vendedores (con su agente de Wintook), condiciones de pago (con plazos), monedas,
  países y estados (por país). Lo que ya usa alguna organización no se borra: se
  desactiva; un país o estado cuyas ciudades usa una dirección no se puede borrar.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import CrmCatalogs from 'dashboard/api/crmCatalogs';
import Spinner from 'shared/components/Spinner.vue';
import { LOOKUP_KINDS, crmAccess, errorMessage } from './crmHelpers';

// resource = ruta de la API · key = nombre del parámetro · hasActive / hasDefault =
// si el catálogo tiene «activo» / «predeterminado» (países y estados no los tienen todos).
const CATALOGS = [
  ...LOOKUP_KINDS.map(kind => ({
    id: kind,
    resource: 'lookups',
    key: 'lookup',
    kind,
  })),
  { id: 'sellers', resource: 'sellers', key: 'seller' },
  { id: 'payment_terms', resource: 'payment_terms', key: 'payment_term' },
  { id: 'currencies', resource: 'currencies', key: 'currency' },
  { id: 'countries', resource: 'countries', key: 'country', hasActive: false },
  {
    id: 'states',
    resource: 'states',
    key: 'state',
    hasActive: false,
    hasDefault: false,
  },
];

// Rails borra un plazo existente con `_destroy` (accepts_nested_attributes_for).
const DESTROY = '_destroy';

const BLANKS = {
  lookups: () => ({ name: '', is_default: false, active: true }),
  sellers: () => ({
    name: '',
    user_id: '',
    notes: '',
    is_default: false,
    active: true,
  }),
  payment_terms: () => ({
    name: '',
    early_payment_discount_percent: 0,
    early_payment_days: 0,
    installments: [],
    is_default: false,
    active: true,
  }),
  currencies: () => ({
    name: '',
    iso_code: '',
    symbol: '',
    amount_in_words: '',
    is_local: false,
    fixed_exchange_rate: '',
    is_default: false,
    active: true,
  }),
  countries: () => ({
    name: '',
    abbreviation: '',
    iso_code: '',
    is_default: false,
  }),
  states: () => ({ name: '', abbreviation: '' }),
};

export default {
  name: 'CrmZeusCatalogs',
  components: { Spinner },
  data() {
    return {
      catalogs: CATALOGS,
      current: CATALOGS[0],
      items: [],
      loading: true,
      form: null,
      saving: false,
      countries: [],
      countryId: null,
    };
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
      agents: 'agents/getAgents',
    }),
    isAdmin() {
      return crmAccess(this.currentUser, this.$route.params.accountId).isAdmin;
    },
    resource() {
      return this.current.resource;
    },
    hasActive() {
      return this.current.hasActive !== false;
    },
    hasDefault() {
      return this.current.hasDefault !== false;
    },
    isGeo() {
      return ['countries', 'states'].includes(this.resource);
    },
    deleteDescription() {
      const keys = {
        countries: 'CONFIRM_DELETE_COUNTRY',
        states: 'CONFIRM_DELETE_STATE',
      };
      return this.$t(
        `CRM_ZEUS.CATALOGS.${keys[this.resource] || 'CONFIRM_DELETE'}`,
        {
          name: this.form ? this.form.name : '',
          catalog: this.label(this.current),
        }
      );
    },
    installmentsTotal() {
      if (!this.form || !this.form.installments) return 0;
      return this.form.installments
        .filter(item => !item[DESTROY])
        .reduce((sum, item) => sum + Number(item.percent || 0), 0);
    },
  },
  mounted() {
    this.$store.dispatch('agents/get');
    this.fetch();
  },
  methods: {
    label(catalog) {
      return this.$t(`CRM_ZEUS.CATALOGS.NAMES.${catalog.id.toUpperCase()}`);
    },
    // «zona», «moneda», «condición de pago»… para «Agregar / Editar / Eliminar ___».
    singular(catalog) {
      return this.$t(`CRM_ZEUS.CATALOGS.SINGULAR.${catalog.id.toUpperCase()}`);
    },
    select(catalog) {
      this.current = catalog;
      this.form = null;
      this.fetch();
    },
    async fetchCountries() {
      const { data } = await CrmCatalogs.list('countries');
      this.countries = data.items;
      if (!this.countries.some(country => country.id === this.countryId)) {
        const preferred = this.countries.find(country => country.is_default);
        this.countryId = (preferred || this.countries[0] || {}).id || null;
      }
    },
    async fetch() {
      this.loading = true;
      try {
        const params = this.current.kind ? { kind: this.current.kind } : {};
        if (this.resource === 'states') {
          await this.fetchCountries();
          params.country_id = this.countryId;
        }
        const { data } = await CrmCatalogs.list(this.resource, params);
        this.items = data.items;
      } catch (error) {
        this.items = [];
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      } finally {
        this.loading = false;
      }
    },
    detail(item) {
      if (this.resource === 'sellers') return item.user_name || '';
      if (this.resource === 'currencies') {
        const rate = item.fixed_exchange_rate
          ? `${this.$t('CRM_ZEUS.CATALOGS.RATE')} ${item.fixed_exchange_rate}`
          : '';
        return [
          item.iso_code,
          item.symbol,
          item.is_local && this.$t('CRM_ZEUS.CATALOGS.LOCAL'),
          rate,
        ]
          .filter(Boolean)
          .join(' · ');
      }
      if (this.resource === 'countries') {
        return [
          item.abbreviation,
          item.iso_code,
          this.$t('CRM_ZEUS.CATALOGS.STATES_COUNT', { n: item.states.length }),
        ]
          .filter(Boolean)
          .join(' · ');
      }
      if (this.resource === 'states') return item.abbreviation || '';
      if (this.resource === 'payment_terms') {
        return (
          item.installments
            .map(i => this.$t('CRM_ZEUS.CATALOGS.INSTALLMENT', i))
            .join(' · ') || this.$t('CRM_ZEUS.CATALOGS.CASH')
        );
      }
      return '';
    },
    openNew() {
      this.form = BLANKS[this.resource]();
    },
    openEdit(item) {
      if (!this.isAdmin) return;
      this.form = {
        ...BLANKS[this.resource](),
        ...item,
        installments: (item.installments || []).map(i => ({ ...i })),
      };
      if (this.resource === 'sellers') this.form.user_id = item.user_id || '';
      if (this.resource === 'currencies') {
        this.form.fixed_exchange_rate = item.fixed_exchange_rate || '';
      }
    },
    addInstallment() {
      this.form.installments.push({ days: 0, percent: 100 });
    },
    removeInstallment(index) {
      const item = this.form.installments[index];
      if (item.id) this.$set(item, DESTROY, true);
      else this.form.installments.splice(index, 1);
    },
    payload() {
      const {
        id,
        installments,
        credit_days: _,
        user_name: __,
        states: ___,
        country_name: ____,
        country_id: _____,
        ...rest
      } = this.form;
      const data = { ...rest };
      if (this.resource === 'states' && !id) data.country_id = this.countryId;
      if (this.current.kind && !id) data.kind = this.current.kind;
      if (this.resource === 'sellers') data.user_id = data.user_id || null;
      if (this.resource === 'currencies') {
        data.fixed_exchange_rate = data.fixed_exchange_rate || null;
      }
      if (this.resource === 'payment_terms') {
        data.installments_attributes = installments.map((item, position) => ({
          ...item,
          position,
        }));
      }
      return data;
    },
    async save() {
      if (!this.form.name.trim()) return;
      this.saving = true;
      try {
        const { key } = this.current;
        if (this.form.id) {
          await CrmCatalogs.updateItem(
            this.resource,
            key,
            this.form.id,
            this.payload()
          );
        } else {
          await CrmCatalogs.createItem(this.resource, key, this.payload());
        }
        useAlert(this.$t('CRM_ZEUS.CATALOGS.SAVED'));
        this.form = null;
        this.fetch();
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      } finally {
        this.saving = false;
      }
    },
    async remove() {
      if (!(await this.$refs.deleteDialog.showConfirmation())) return;
      try {
        await CrmCatalogs.deleteItem(this.resource, this.form.id);
        this.form = null;
        this.fetch();
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
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
      <div class="max-w-2xl">
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CRM_ZEUS.CATALOGS.TITLE') }}
        </h1>
        <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
          {{
            isAdmin
              ? $t('CRM_ZEUS.CATALOGS.DESCRIPTION')
              : $t('CRM_ZEUS.CATALOGS.READ_ONLY')
          }}
        </p>
      </div>
      <woot-button v-if="isAdmin" size="small" icon="add" @click="openNew">
        {{ $t('CRM_ZEUS.CATALOGS.ADD', { item: singular(current) }) }}
      </woot-button>
    </header>

    <div class="flex flex-1 min-h-0 gap-4 px-6 pb-4">
      <nav class="flex flex-col flex-shrink-0 w-52 gap-0.5">
        <button
          v-for="catalog in catalogs"
          :key="catalog.id"
          type="button"
          class="px-3 py-2 text-sm text-left rounded-md"
          :class="
            current.id === catalog.id
              ? 'bg-woot-50 text-woot-700 font-medium dark:bg-woot-800/30'
              : 'text-slate-700 hover:bg-slate-50 dark:text-slate-200 dark:hover:bg-slate-800'
          "
          @click="select(catalog)"
        >
          {{ label(catalog) }}
        </button>
      </nav>

      <div class="flex-1 overflow-auto">
        <label
          v-if="resource === 'states'"
          class="flex items-center max-w-sm gap-2 mb-3 text-sm"
        >
          {{ $t('CRM_ZEUS.CATALOGS.COUNTRY') }}
          <select v-model="countryId" class="!mb-0" @change="fetch">
            <option
              v-for="country in countries"
              :key="country.id"
              :value="country.id"
            >
              {{ country.name }}
            </option>
          </select>
        </label>
        <Spinner v-if="loading" />
        <p
          v-else-if="!items.length"
          class="py-12 text-sm text-center text-slate-500"
        >
          {{ $t('CRM_ZEUS.CATALOGS.EMPTY') }}
        </p>
        <table v-else class="w-full text-sm">
          <thead>
            <tr
              class="text-left border-b text-slate-500 border-slate-50 dark:border-slate-800"
            >
              <th class="px-3 py-2 font-medium">
                {{ $t('CRM_ZEUS.CATALOGS.COLUMNS.NAME') }}
              </th>
              <th class="px-3 py-2 font-medium">
                {{ $t('CRM_ZEUS.CATALOGS.COLUMNS.DETAIL') }}
              </th>
              <th v-if="hasDefault" class="px-3 py-2 font-medium">
                {{ $t('CRM_ZEUS.CATALOGS.COLUMNS.DEFAULT') }}
              </th>
              <th v-if="hasActive" class="px-3 py-2 font-medium">
                {{ $t('CRM_ZEUS.CATALOGS.COLUMNS.ACTIVE') }}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-50 dark:divide-slate-800">
            <tr
              v-for="item in items"
              :key="item.id"
              :class="{
                'cursor-pointer hover:bg-slate-25 dark:hover:bg-slate-800':
                  isAdmin,
                'opacity-60': hasActive && !item.active,
              }"
              @click="openEdit(item)"
            >
              <td
                class="px-3 py-2 font-medium text-slate-800 dark:text-slate-100"
              >
                {{ item.name }}
              </td>
              <td class="px-3 py-2 text-slate-600 dark:text-slate-300">
                {{ detail(item) || '—' }}
              </td>
              <td v-if="hasDefault" class="px-3 py-2">
                <fluent-icon
                  v-if="item.is_default"
                  icon="star"
                  size="16"
                  class="text-amber-500"
                />
              </td>
              <td v-if="hasActive" class="px-3 py-2">
                <fluent-icon
                  v-if="item.active"
                  icon="checkmark"
                  size="16"
                  class="text-green-600"
                />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <woot-modal
      :show="!!form"
      :on-close="() => (form = null)"
      modal-type="right-aligned"
      size="wide"
    >
      <div v-if="form" class="flex flex-col h-auto">
        <woot-modal-header
          :header-title="
            $t(form.id ? 'CRM_ZEUS.CATALOGS.EDIT' : 'CRM_ZEUS.CATALOGS.ADD', {
              item: singular(current),
            })
          "
        />
        <form
          class="flex flex-col w-full gap-1 px-8 pt-4"
          @submit.prevent="save"
        >
          <label>
            {{ $t('CRM_ZEUS.CATALOGS.COLUMNS.NAME') }}
            <input
              v-model="form.name"
              type="text"
              :maxlength="isGeo ? 50 : 100"
              required
            />
          </label>

          <div v-if="isGeo" class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
            <label>
              {{ $t('CRM_ZEUS.CATALOGS.ABBREVIATION') }}
              <input
                v-model="form.abbreviation"
                type="text"
                maxlength="10"
                :placeholder="
                  resource === 'states'
                    ? $t('CRM_ZEUS.CATALOGS.STATE_ABBR_PLACEHOLDER')
                    : $t('CRM_ZEUS.CATALOGS.COUNTRY_ABBR_PLACEHOLDER')
                "
              />
            </label>
            <label v-if="resource === 'countries'">
              {{ $t('CRM_ZEUS.CATALOGS.ISO_CODE') }}
              <input
                v-model="form.iso_code"
                type="text"
                maxlength="3"
                :placeholder="$t('CRM_ZEUS.CATALOGS.COUNTRY_ISO_PLACEHOLDER')"
              />
            </label>
          </div>
          <p
            v-if="resource === 'states'"
            class="mt-0 text-xs text-slate-500 dark:text-slate-400"
          >
            {{ $t('CRM_ZEUS.CATALOGS.STATE_HINT') }}
          </p>

          <template v-if="resource === 'sellers'">
            <label>
              {{ $t('CRM_ZEUS.CATALOGS.SELLER_USER') }}
              <select v-model="form.user_id">
                <option value="">{{ $t('CRM_ZEUS.CATALOGS.NO_USER') }}</option>
                <option
                  v-for="agent in agents"
                  :key="agent.id"
                  :value="agent.id"
                >
                  {{ agent.name }}
                </option>
              </select>
            </label>
            <label>
              {{ $t('CRM_ZEUS.CATALOGS.NOTES') }}
              <textarea v-model="form.notes" rows="3" />
            </label>
          </template>

          <template v-if="resource === 'currencies'">
            <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-3">
              <label>
                {{ $t('CRM_ZEUS.CATALOGS.ISO_CODE') }}
                <input
                  v-model="form.iso_code"
                  type="text"
                  maxlength="3"
                  :placeholder="$t('CRM_ZEUS.CATALOGS.ISO_PLACEHOLDER')"
                />
              </label>
              <label>
                {{ $t('CRM_ZEUS.CATALOGS.SYMBOL') }}
                <input v-model="form.symbol" type="text" maxlength="10" />
              </label>
              <label>
                {{ $t('CRM_ZEUS.CATALOGS.FIXED_RATE') }}
                <input
                  v-model="form.fixed_exchange_rate"
                  type="number"
                  min="0"
                  step="0.0001"
                  :disabled="form.is_local"
                />
              </label>
            </div>
            <label>
              {{ $t('CRM_ZEUS.CATALOGS.AMOUNT_IN_WORDS') }}
              <input
                v-model="form.amount_in_words"
                type="text"
                maxlength="50"
              />
            </label>
            <label class="flex items-center gap-2">
              <input v-model="form.is_local" type="checkbox" class="!m-0" />
              {{ $t('CRM_ZEUS.CATALOGS.IS_LOCAL') }}
            </label>
          </template>

          <template v-if="resource === 'payment_terms'">
            <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
              <label>
                {{ $t('CRM_ZEUS.CATALOGS.EARLY_DISCOUNT') }}
                <input
                  v-model.number="form.early_payment_discount_percent"
                  type="number"
                  min="0"
                  max="100"
                  step="0.01"
                />
              </label>
              <label>
                {{ $t('CRM_ZEUS.CATALOGS.EARLY_DAYS') }}
                <input
                  v-model.number="form.early_payment_days"
                  type="number"
                  min="0"
                />
              </label>
            </div>
            <p
              class="mt-2 mb-1 text-sm font-medium text-slate-800 dark:text-slate-100"
            >
              {{ $t('CRM_ZEUS.CATALOGS.INSTALLMENTS') }}
            </p>
            <p class="mt-0 mb-2 text-xs text-slate-500">
              {{ $t('CRM_ZEUS.CATALOGS.INSTALLMENTS_HINT') }}
            </p>
            <template v-for="(item, index) in form.installments">
              <div
                v-if="!item._destroy"
                :key="item.id || `new-${index}`"
                class="flex items-center gap-2 mb-2"
              >
                <input
                  v-model.number="item.days"
                  type="number"
                  min="0"
                  class="!mb-0 !w-24"
                />
                <span class="text-sm text-slate-600">{{
                  $t('CRM_ZEUS.CATALOGS.DAYS')
                }}</span>
                <input
                  v-model.number="item.percent"
                  type="number"
                  min="0"
                  max="100"
                  step="0.01"
                  class="!mb-0 !w-24"
                />
                <span class="text-sm text-slate-600">%</span>
                <woot-button
                  type="button"
                  size="tiny"
                  variant="clear"
                  color-scheme="alert"
                  icon="dismiss"
                  @click="removeInstallment(index)"
                />
              </div>
            </template>
            <div class="flex items-center gap-3">
              <woot-button
                type="button"
                size="small"
                variant="smooth"
                color-scheme="secondary"
                icon="add"
                @click="addInstallment"
              >
                {{ $t('CRM_ZEUS.CATALOGS.ADD_INSTALLMENT') }}
              </woot-button>
              <span
                v-if="form.installments.some(i => !i._destroy)"
                class="text-sm"
                :class="
                  installmentsTotal === 100 ? 'text-green-700' : 'text-red-600'
                "
              >
                {{
                  $t('CRM_ZEUS.CATALOGS.TOTAL', { total: installmentsTotal })
                }}
              </span>
            </div>
          </template>

          <label v-if="hasDefault" class="flex items-center gap-2 mt-3">
            <input v-model="form.is_default" type="checkbox" class="!m-0" />
            {{ $t('CRM_ZEUS.CATALOGS.IS_DEFAULT') }}
          </label>
          <label v-if="hasActive" class="flex items-center gap-2">
            <input v-model="form.active" type="checkbox" class="!m-0" />
            {{ $t('CRM_ZEUS.CATALOGS.ACTIVE') }}
          </label>

          <div
            class="sticky bottom-0 z-10 flex justify-between gap-2 px-8 py-3 mt-4 -mx-8 bg-white border-t dark:bg-slate-800 border-slate-50 dark:border-slate-700"
          >
            <woot-button
              v-if="form.id"
              type="button"
              variant="clear"
              color-scheme="alert"
              icon="delete"
              @click="remove"
            >
              {{ $t('CRM_ZEUS.DELETE') }}
            </woot-button>
            <span v-else />
            <div class="flex gap-2">
              <button type="button" class="button clear" @click="form = null">
                {{ $t('CRM_ZEUS.CANCEL') }}
              </button>
              <woot-submit-button
                :loading="saving"
                :button-text="$t('CRM_ZEUS.SAVE')"
              />
            </div>
          </div>
        </form>
      </div>
    </woot-modal>

    <woot-confirm-modal
      ref="deleteDialog"
      :title="$t('CRM_ZEUS.CATALOGS.DELETE_TITLE', { item: singular(current) })"
      :description="deleteDescription"
      :confirm-label="$t('CRM_ZEUS.DELETE')"
      :cancel-label="$t('CRM_ZEUS.CANCEL')"
    />
  </div>
</template>
