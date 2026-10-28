<!--
  CrmZeus O2 — alta y edición de una organización (cliente o prospecto), en página
  aparte con las pestañas de CRMZeus: General · Dirección (el domicilio) ·
  Administración · Notas · Consignatarios (las demás direcciones, ya guardada).
  Obligatorios: razón social y nombre comercial. Los valores «predeterminados» de los
  catálogos se proponen al dar de alta.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import CrmOrganizations from 'dashboard/api/crmOrganizations';
import CrmCatalogs from 'dashboard/api/crmCatalogs';
import Spinner from 'shared/components/Spinner.vue';
import AddressFields from './AddressFields.vue';
import ConsigneesPanel from './ConsigneesPanel.vue';
import {
  ADDRESS_FIELDS,
  LOOKUP_KINDS,
  blankAddress,
  crmAccess,
  defaultId,
  errorMessage,
} from './crmHelpers';

const TABS = ['general', 'address', 'admin', 'notes', 'consignees'];
const FIELDS = [
  'organization_type',
  'key',
  'legal_name',
  'trade_name',
  'phone',
  'email',
  'tax_id',
  'customer_type_id',
  'rating_id',
  'industry_id',
  'origin_id',
  'zone_id',
  'collector_id',
  'seller_id',
  'respect_seller',
  'payment_term_id',
  'currency_id',
  'credit_limit',
  'status',
  'suspended_on',
  'suspension_reason',
  'charge_taxes',
  'withholds_taxes',
  'cfdi_use',
  'sat_payment_form',
  'invoice_email',
  'notes',
];

const blankOrganization = () => ({
  ...Object.fromEntries(FIELDS.map(field => [field, ''])),
  organization_type: 'prospect',
  status: 'active',
  respect_seller: false,
  charge_taxes: true,
  withholds_taxes: false,
  credit_limit: 0,
  home_address: blankAddress(),
});

export default {
  name: 'CrmZeusOrganizationForm',
  components: { Spinner, AddressFields, ConsigneesPanel },
  props: {
    organizationId: { type: String, default: '' },
  },
  data() {
    return {
      tabs: TABS,
      tab: 'general',
      org: blankOrganization(),
      catalogs: {
        lookups: {},
        sellers: [],
        payment_terms: [],
        currencies: [],
        countries: [],
        statuses: [],
      },
      loading: true,
      saving: false,
    };
  },
  computed: {
    ...mapGetters({ currentUser: 'getCurrentUser' }),
    isNew() {
      return !this.organizationId;
    },
    canEdit() {
      return crmAccess(this.currentUser, this.$route.params.accountId).canEdit;
    },
    lookupKinds() {
      return LOOKUP_KINDS.filter(kind => kind !== 'collector');
    },
    isSuspended() {
      return this.org.status && this.org.status !== 'active';
    },
    // «Baja» pide fecha y motivo de baja; las suspensiones, de suspensión.
    suspensionLabels() {
      const kind = this.org.status === 'inactive' ? 'INACTIVE' : 'SUSPENDED';
      return {
        date: this.$t(`CRM_ZEUS.SUSPENSION.${kind}_ON`),
        reason: this.$t(`CRM_ZEUS.SUSPENSION.${kind}_REASON`),
      };
    },
    title() {
      return this.isNew
        ? this.$t('CRM_ZEUS.FORM.NEW_TITLE')
        : this.org.trade_name || this.$t('CRM_ZEUS.FORM.EDIT_TITLE');
    },
  },
  watch: {
    organizationId() {
      this.load();
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    async load() {
      this.loading = true;
      try {
        const { data } = await CrmCatalogs.fetch();
        this.catalogs = data;
        if (this.isNew) {
          this.org = this.withDefaults(blankOrganization());
        } else {
          const response = await CrmOrganizations.show(this.organizationId);
          this.org = this.fromApi(response.data.organization);
        }
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      } finally {
        this.loading = false;
      }
    },
    // Al dar de alta se proponen los predeterminados de cada catálogo (como CRMZeus).
    withDefaults(org) {
      const result = { ...org };
      LOOKUP_KINDS.forEach(kind => {
        result[`${kind}_id`] = defaultId(this.catalogs.lookups[kind] || []);
      });
      result.seller_id = defaultId(this.catalogs.sellers);
      result.payment_term_id = defaultId(this.catalogs.payment_terms);
      result.currency_id = defaultId(this.catalogs.currencies);
      return result;
    },
    fromApi(organization) {
      const result = { ...blankOrganization() };
      FIELDS.forEach(field => {
        const value = organization[field];
        result[field] = value === null || value === undefined ? '' : value;
      });
      result.id = organization.id;
      result.home_address = {
        ...blankAddress(),
        ...(organization.home_address || {}),
      };
      return result;
    },
    payload() {
      const organization = {};
      FIELDS.forEach(field => {
        const value = this.org[field];
        organization[field] = value === '' ? null : value;
      });
      if (!this.isSuspended) {
        organization.suspended_on = null;
        organization.suspension_reason = null;
      }
      const home = this.org.home_address;
      organization.home_address_attributes = Object.fromEntries(
        [...ADDRESS_FIELDS, 'id', 'city_id', 'for_billing']
          .filter(field => home[field] !== undefined)
          .map(field => [field, home[field] === '' ? null : home[field]])
      );
      return { organization };
    },
    async save() {
      if (!this.org.legal_name.trim() || !this.org.trade_name.trim()) {
        this.tab = 'general';
        useAlert(this.$t('CRM_ZEUS.FORM.REQUIRED'));
        return;
      }
      this.saving = true;
      try {
        if (this.isNew) {
          const { data } = await CrmOrganizations.create(this.payload());
          useAlert(this.$t('CRM_ZEUS.FORM.CREATED'));
          this.$router.replace({
            name: 'crmzeus_organization_edit',
            params: { organizationId: data.organization.id },
          });
        } else {
          const { data } = await CrmOrganizations.update(
            this.organizationId,
            this.payload()
          );
          this.org = this.fromApi(data.organization);
          useAlert(this.$t('CRM_ZEUS.FORM.SAVED'));
        }
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      } finally {
        this.saving = false;
      }
    },
    async convert() {
      if (!(await this.$refs.convertDialog.showConfirmation())) return;
      try {
        const { data } = await CrmOrganizations.convert(this.organizationId);
        this.org = this.fromApi(data.organization);
        useAlert(this.$t('CRM_ZEUS.FORM.CONVERTED'));
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      }
    },
    async remove() {
      if (!(await this.$refs.deleteDialog.showConfirmation())) return;
      try {
        await CrmOrganizations.delete(this.organizationId);
        useAlert(this.$t('CRM_ZEUS.FORM.DELETED'));
        this.back();
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      }
    },
    // Un consignatario «para facturar» le quita la marca al domicilio: solo se
    // refresca eso, sin perder lo que se esté editando en las otras pestañas.
    async refreshBilling() {
      const { data } = await CrmOrganizations.show(this.organizationId);
      const home = data.organization.home_address;
      if (home)
        this.org.home_address = {
          ...this.org.home_address,
          for_billing: home.for_billing,
        };
    },
    back() {
      this.$router.push({ name: 'crmzeus_organizations' });
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-white dark:bg-slate-900"
  >
    <header
      class="flex flex-wrap items-start justify-between gap-3 px-6 pt-5 pb-3 border-b border-slate-50 dark:border-slate-800/50"
    >
      <div>
        <button
          type="button"
          class="p-0 mb-1 text-sm text-woot-600 hover:underline"
          @click="back"
        >
          {{ $t('CRM_ZEUS.FORM.BACK') }}
        </button>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ title }}
          <span
            v-if="!isNew && !loading"
            class="ml-2 px-2 py-0.5 text-xs font-medium rounded-full align-middle"
            :class="
              org.organization_type === 'customer'
                ? 'bg-green-50 text-green-800'
                : 'bg-amber-50 text-amber-800'
            "
          >
            {{ $t(`CRM_ZEUS.TYPE.${org.organization_type.toUpperCase()}`) }}
          </span>
        </h1>
        <p v-if="!isNew" class="m-0 text-sm text-slate-500">
          {{ org.legal_name }}
        </p>
      </div>
      <div v-if="canEdit && !loading" class="flex flex-wrap gap-2">
        <woot-button
          v-if="!isNew && org.organization_type === 'prospect'"
          size="small"
          variant="smooth"
          color-scheme="success"
          icon="person-add"
          @click="convert"
        >
          {{ $t('CRM_ZEUS.FORM.CONVERT') }}
        </woot-button>
        <woot-button
          v-if="!isNew"
          size="small"
          variant="smooth"
          color-scheme="alert"
          icon="delete"
          @click="remove"
        >
          {{ $t('CRM_ZEUS.DELETE') }}
        </woot-button>
        <woot-button
          size="small"
          icon="save"
          :is-loading="saving"
          @click="save"
        >
          {{ $t('CRM_ZEUS.SAVE') }}
        </woot-button>
      </div>
    </header>

    <Spinner v-if="loading" class="mt-8" />
    <template v-else>
      <nav class="flex flex-wrap gap-1 px-6 pt-3">
        <button
          v-for="t in tabs"
          :key="t"
          type="button"
          class="px-3 py-1.5 text-sm rounded-t-md border-b-2"
          :class="
            tab === t
              ? 'border-woot-500 text-woot-600 font-medium'
              : 'border-transparent text-slate-600 dark:text-slate-300'
          "
          @click="tab = t"
        >
          {{ $t(`CRM_ZEUS.FORM.TABS.${t.toUpperCase()}`) }}
        </button>
      </nav>

      <form class="flex-1 px-6 py-4 overflow-auto" @submit.prevent="save">
        <fieldset :disabled="!canEdit" class="max-w-4xl">
          <!-- General -->
          <div v-show="tab === 'general'" class="flex flex-col gap-1">
            <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-[1fr_2fr]">
              <label>
                {{ $t('CRM_ZEUS.FIELDS.KEY') }}
                <input v-model="org.key" type="text" maxlength="20" />
              </label>
              <label v-if="isNew">
                {{ $t('CRM_ZEUS.FIELDS.ORGANIZATION_TYPE') }}
                <select v-model="org.organization_type">
                  <option value="prospect">
                    {{ $t('CRM_ZEUS.TYPE.PROSPECT') }}
                  </option>
                  <option value="customer">
                    {{ $t('CRM_ZEUS.TYPE.CUSTOMER') }}
                  </option>
                </select>
              </label>
            </div>
            <label>
              {{ $t('CRM_ZEUS.FIELDS.LEGAL_NAME') }} *
              <input
                v-model="org.legal_name"
                type="text"
                maxlength="100"
                required
              />
            </label>
            <label>
              {{ $t('CRM_ZEUS.FIELDS.TRADE_NAME') }} *
              <input
                v-model="org.trade_name"
                type="text"
                maxlength="100"
                required
              />
            </label>
            <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
              <label v-for="kind in lookupKinds" :key="kind">
                {{ $t(`CRM_ZEUS.LOOKUPS.${kind.toUpperCase()}`) }}
                <select v-model="org[`${kind}_id`]">
                  <option value="">—</option>
                  <option
                    v-for="item in catalogs.lookups[kind] || []"
                    :key="item.id"
                    :value="item.id"
                  >
                    {{ item.name }}
                  </option>
                </select>
              </label>
              <label>
                {{ $t('CRM_ZEUS.FIELDS.SELLER') }}
                <select v-model="org.seller_id">
                  <option value="">—</option>
                  <option
                    v-for="seller in catalogs.sellers"
                    :key="seller.id"
                    :value="seller.id"
                  >
                    {{ seller.name }}
                  </option>
                </select>
              </label>
            </div>
            <label class="flex items-center gap-2">
              <input
                v-model="org.respect_seller"
                type="checkbox"
                class="!m-0"
              />
              {{ $t('CRM_ZEUS.FIELDS.RESPECT_SELLER') }}
            </label>
            <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
              <label>
                {{ $t('CRM_ZEUS.FIELDS.PHONE') }}
                <input v-model="org.phone" type="text" maxlength="35" />
              </label>
              <label>
                {{ $t('CRM_ZEUS.FIELDS.EMAIL') }}
                <input v-model="org.email" type="email" />
              </label>
            </div>
          </div>

          <!-- Dirección (domicilio) -->
          <div v-show="tab === 'address'">
            <p class="mt-0 mb-3 text-sm text-slate-600 dark:text-slate-300">
              {{ $t('CRM_ZEUS.FORM.ADDRESS_HINT') }}
            </p>
            <AddressFields
              v-model="org.home_address"
              :countries="catalogs.countries"
              :disabled="!canEdit"
            />
          </div>

          <!-- Administración -->
          <div v-show="tab === 'admin'" class="flex flex-col gap-1">
            <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
              <label>
                {{ $t('CRM_ZEUS.FIELDS.TAX_ID') }}
                <input v-model="org.tax_id" type="text" maxlength="18" />
              </label>
              <label>
                {{ $t('CRM_ZEUS.FIELDS.PAYMENT_TERM') }}
                <select v-model="org.payment_term_id">
                  <option value="">—</option>
                  <option
                    v-for="term in catalogs.payment_terms"
                    :key="term.id"
                    :value="term.id"
                  >
                    {{ term.name }}
                  </option>
                </select>
              </label>
              <label>
                {{ $t('CRM_ZEUS.LOOKUPS.COLLECTOR') }}
                <select v-model="org.collector_id">
                  <option value="">—</option>
                  <option
                    v-for="item in catalogs.lookups.collector || []"
                    :key="item.id"
                    :value="item.id"
                  >
                    {{ item.name }}
                  </option>
                </select>
              </label>
              <label>
                {{ $t('CRM_ZEUS.FIELDS.CREDIT_LIMIT') }}
                <input
                  v-model.number="org.credit_limit"
                  type="number"
                  min="0"
                  step="0.01"
                  class="text-right"
                />
              </label>
              <label>
                {{ $t('CRM_ZEUS.FIELDS.CURRENCY') }}
                <select v-model="org.currency_id">
                  <option value="">—</option>
                  <option
                    v-for="currency in catalogs.currencies"
                    :key="currency.id"
                    :value="currency.id"
                  >
                    {{ currency.name }}
                  </option>
                </select>
              </label>
              <label>
                {{ $t('CRM_ZEUS.FIELDS.STATUS') }}
                <select v-model="org.status">
                  <option
                    v-for="status in catalogs.statuses"
                    :key="status"
                    :value="status"
                  >
                    {{ $t(`CRM_ZEUS.STATUS.${status.toUpperCase()}`) }}
                  </option>
                </select>
              </label>
            </div>
            <div
              v-if="isSuspended"
              class="grid grid-cols-1 gap-x-4 sm:grid-cols-[1fr_3fr]"
            >
              <label>
                {{ suspensionLabels.date }}
                <input v-model="org.suspended_on" type="date" />
              </label>
              <label>
                {{ suspensionLabels.reason }}
                <input
                  v-model="org.suspension_reason"
                  type="text"
                  maxlength="250"
                />
              </label>
            </div>
            <div class="flex flex-wrap gap-6">
              <label class="flex items-center gap-2">
                <input
                  v-model="org.charge_taxes"
                  type="checkbox"
                  class="!m-0"
                />
                {{ $t('CRM_ZEUS.FIELDS.CHARGE_TAXES') }}
              </label>
              <label class="flex items-center gap-2">
                <input
                  v-model="org.withholds_taxes"
                  type="checkbox"
                  class="!m-0"
                />
                {{ $t('CRM_ZEUS.FIELDS.WITHHOLDS_TAXES') }}
              </label>
            </div>
            <div class="grid grid-cols-1 gap-x-4 mt-2 sm:grid-cols-3">
              <label>
                {{ $t('CRM_ZEUS.FIELDS.CFDI_USE') }}
                <input
                  v-model="org.cfdi_use"
                  type="text"
                  maxlength="4"
                  :placeholder="$t('CRM_ZEUS.FIELDS.CFDI_USE_PLACEHOLDER')"
                />
              </label>
              <label>
                {{ $t('CRM_ZEUS.FIELDS.SAT_PAYMENT_FORM') }}
                <input
                  v-model="org.sat_payment_form"
                  type="text"
                  maxlength="3"
                  :placeholder="
                    $t('CRM_ZEUS.FIELDS.SAT_PAYMENT_FORM_PLACEHOLDER')
                  "
                />
              </label>
              <label>
                {{ $t('CRM_ZEUS.FIELDS.INVOICE_EMAIL') }}
                <input v-model="org.invoice_email" type="email" />
              </label>
            </div>
          </div>

          <!-- Notas -->
          <div v-show="tab === 'notes'">
            <textarea
              v-model="org.notes"
              rows="12"
              :placeholder="$t('CRM_ZEUS.FIELDS.NOTES')"
            />
          </div>
        </fieldset>

        <!-- Consignatarios (fuera del fieldset: tienen su propio guardado) -->
        <div v-if="tab === 'consignees'" class="max-w-4xl">
          <p v-if="isNew" class="text-sm text-slate-500">
            {{ $t('CRM_ZEUS.CONSIGNEES.SAVE_FIRST') }}
          </p>
          <ConsigneesPanel
            v-else
            :organization-id="organizationId"
            :legal-name="org.legal_name"
            :countries="catalogs.countries"
            :can-edit="canEdit"
            @changed="refreshBilling"
          />
        </div>
      </form>
    </template>

    <woot-confirm-modal
      ref="convertDialog"
      :title="$t('CRM_ZEUS.FORM.CONVERT_TITLE')"
      :description="
        $t('CRM_ZEUS.FORM.CONFIRM_CONVERT', { name: org.trade_name })
      "
      :confirm-label="$t('CRM_ZEUS.FORM.CONVERT')"
      :cancel-label="$t('CRM_ZEUS.CANCEL')"
    />
    <woot-confirm-modal
      ref="deleteDialog"
      :title="$t('CRM_ZEUS.FORM.DELETE_TITLE')"
      :description="
        $t('CRM_ZEUS.FORM.CONFIRM_DELETE', { name: org.trade_name })
      "
      :confirm-label="$t('CRM_ZEUS.DELETE')"
      :cancel-label="$t('CRM_ZEUS.CANCEL')"
    />
  </div>
</template>
