<!--
  CrmZeus Q2 — alta y edición de una cotización, en página aparte como CRMZeus:
  General · Otros datos arriba; abajo las partidas (modal «Artículo») y los totales.
  Al elegir la organización se proponen vendedor, condición de pago, moneda y uso CFDI
  del cliente. Los importes los calcula el servidor (`calculate`) mientras se captura y
  otra vez al guardar. Solo se edita en Pendiente, y solo el creador o un Administrador.
  `?organization_id=` abre con la organización elegida; `?from=<id>` es «Duplicar».
-->
<script>
import { useAlert } from 'dashboard/composables';
import CrmQuotes from 'dashboard/api/crmQuotes';
import CrmOrganizations from 'dashboard/api/crmOrganizations';
import CrmCatalogs from 'dashboard/api/crmCatalogs';
import Spinner from 'shared/components/Spinner.vue';
import { formatMoney } from 'dashboard/helper/caseCommercial';
import OrganizationPicker from './OrganizationPicker.vue';
import QuoteItemModal from './QuoteItemModal.vue';
import { QUOTE_STATUS_BADGES, addDays, errorMessage } from './crmHelpers';

const TABS = ['general', 'other'];
const HEADER = [
  'organization_id',
  'contact_id',
  'shipping_address_id',
  'seller_id',
  'currency_id',
  'payment_term_id',
  'quote_date',
  'valid_until',
  'delivery_date',
  'cfdi_use',
  'purchase_order',
  'purchase_order_date',
  'header_notes',
  'footer_notes',
  'extra_discount_type',
  'extra_discount_value',
  'freight',
  'other_charges',
];
const ITEM_FIELDS = [
  'id',
  'role',
  'article_id',
  'description',
  'unit',
  'price_list_id',
  'quantity',
  'unit_price',
  'discount_percent',
  'tax_ids',
  'notes',
  'extra_notes',
];
const AMOUNTS = [
  'subtotal',
  'discount_total',
  'extra_discount_amount',
  'extra_discount_percent',
  'net_amount',
  'tax_total',
  'withholding_total',
  'total',
  'exchange_rate',
  'sat_payment_method',
];
const STATUS_ACTIONS = {
  won: { icon: 'checkmark', scheme: 'success' },
  lost: { icon: 'dismiss-circle', scheme: 'alert' },
  cancelled: { icon: 'dismiss', scheme: 'secondary' },
  pending: { icon: 'arrow-reply', scheme: 'primary' },
};

const blankQuote = () => ({
  ...Object.fromEntries(HEADER.map(field => [field, ''])),
  extra_discount_type: 'percent',
  extra_discount_value: 0,
  freight: 0,
  other_charges: 0,
  items: [],
});

let uidCounter = 0;
const withUid = item => {
  uidCounter += 1;
  return { ...item, uid: uidCounter, tax_ids: [...(item.tax_ids || [])] };
};
const blank = value => (value === null || value === undefined ? '' : value);

export default {
  name: 'CrmZeusQuoteForm',
  components: { Spinner, OrganizationPicker, QuoteItemModal },
  props: {
    quoteId: { type: String, default: '' },
  },
  data() {
    return {
      tabs: TABS,
      tab: 'general',
      quote: blankQuote(),
      organization: null,
      totals: {},
      taxSummary: [],
      info: {}, // folio, estatus, transiciones, creador… (solo de una guardada)
      series: null,
      catalogs: { sellers: [], payment_terms: [], currencies: [], taxes: [] },
      priceLists: [],
      contacts: [],
      consignees: [],
      itemForm: null,
      deliveryDays: '',
      pendingStatus: null,
      loading: true,
      saving: false,
      calculating: false,
      calcTimer: null,
    };
  },
  computed: {
    isNew() {
      return !this.quoteId;
    },
    editable() {
      if (this.isNew) return !!this.series;
      return !!this.info.can_edit && this.info.status === 'pending';
    },
    title() {
      if (!this.isNew) return this.info.folio;
      return this.$t('CRM_ZEUS.QUOTE_FORM.NEW_TITLE');
    },
    currencyCode() {
      const currency = this.catalogs.currencies.find(
        item => item.id === this.quote.currency_id
      );
      return currency ? currency.iso_code : '';
    },
    isProspect() {
      return (
        this.organization && this.organization.organization_type === 'prospect'
      );
    },
    statusActions() {
      if (this.isNew || !this.info.can_edit) return [];
      return (this.info.transitions || []).map(status => ({
        status,
        ...STATUS_ACTIONS[status],
      }));
    },
    charges() {
      return this.taxSummary.filter(
        row => !row.tax_type.endsWith('withholding')
      );
    },
    withholdings() {
      return this.taxSummary.filter(row =>
        row.tax_type.endsWith('withholding')
      );
    },
    // Lo que mueve los importes: si cambia, se recalcula en el servidor.
    calcKey() {
      const { quote } = this;
      return JSON.stringify([
        quote.items.map(this.itemPayload),
        quote.extra_discount_type,
        quote.extra_discount_value,
        quote.freight,
        quote.other_charges,
        quote.currency_id,
        quote.payment_term_id,
        quote.organization_id,
      ]);
    },
    taxNames() {
      return Object.fromEntries(
        this.catalogs.taxes.map(tax => [tax.id, tax.name])
      );
    },
  },
  watch: {
    '$route.fullPath'() {
      this.load();
    },
    calcKey() {
      if (this.loading || !this.editable) return;
      clearTimeout(this.calcTimer);
      this.calcTimer = setTimeout(this.recalculate, 400);
    },
  },
  mounted() {
    this.load();
  },
  beforeDestroy() {
    clearTimeout(this.calcTimer);
  },
  methods: {
    formatMoney,
    money(value) {
      return formatMoney(value, this.currencyCode);
    },
    statusBadge(status) {
      return QUOTE_STATUS_BADGES[status];
    },
    async load() {
      this.loading = true;
      this.tab = 'general';
      try {
        const { data } = await CrmCatalogs.fetch();
        this.catalogs = data;
        this.priceLists = data.lookups.price_list || [];
        if (!this.isNew) {
          const response = await CrmQuotes.show(this.quoteId);
          this.fromApi(response.data.quote);
        } else {
          const { from, organization_id: organizationId } = this.$route.query;
          const response = from
            ? await CrmQuotes.duplicate(from)
            : await CrmQuotes.draft(organizationId);
          this.info = {};
          this.series = response.data.series;
          this.fromApi(response.data.quote);
        }
        await this.loadOrganizationLists();
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      } finally {
        this.loading = false;
      }
    },
    fromApi(data) {
      const quote = blankQuote();
      HEADER.forEach(field => {
        quote[field] = blank(data[field]);
      });
      quote.items = (data.items || []).map(item => withUid(item));
      this.quote = quote;
      this.organization = data.organization || null;
      this.applyTotals(data);
      if (data.id) {
        this.info = data;
        this.series = null;
      }
      this.deliveryDays = '';
    },
    applyTotals(data) {
      this.totals = Object.fromEntries(AMOUNTS.map(key => [key, data[key]]));
      this.taxSummary = data.tax_summary || [];
      // Importes por partida, en el mismo orden en que se mandaron.
      (data.items || []).forEach((row, index) => {
        const item = this.quote.items[index];
        if (!item) return;
        ['gross_amount', 'discount_amount', 'net_amount', 'tax_amount'].forEach(
          key => this.$set(item, key, row[key])
        );
      });
    },
    async loadOrganizationLists() {
      const id = this.quote.organization_id;
      this.contacts = [];
      this.consignees = [];
      if (!id) return;
      const [contacts, consignees] = await Promise.all([
        CrmOrganizations.contacts(id),
        this.isProspect ? null : CrmOrganizations.consignees(id),
      ]);
      this.contacts = contacts.data.contacts;
      this.consignees = consignees ? consignees.data.consignees : [];
    },
    // Al elegir la organización se proponen sus datos (como CRMZeus).
    async pickOrganization(org) {
      try {
        const { data } = await CrmQuotes.draft(org.id);
        const defaults = data.quote;
        this.organization = defaults.organization;
        Object.assign(this.quote, {
          organization_id: org.id,
          contact_id: '',
          shipping_address_id: '',
          seller_id: blank(defaults.seller_id),
          payment_term_id: blank(defaults.payment_term_id),
          cfdi_use: blank(defaults.cfdi_use),
        });
        if (!this.quote.items.length)
          this.quote.currency_id = blank(defaults.currency_id);
        await this.loadOrganizationLists();
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      }
    },
    clearOrganization() {
      this.organization = null;
      this.quote.organization_id = '';
      this.contacts = [];
      this.consignees = [];
    },
    applyDeliveryDays() {
      if (this.deliveryDays === '') return;
      this.quote.delivery_date = addDays(
        this.quote.quote_date,
        this.deliveryDays
      );
    },
    itemPayload(item) {
      const row = Object.fromEntries(
        ITEM_FIELDS.map(field => [
          field,
          item[field] === '' ? null : item[field],
        ])
      );
      if (!row.id) delete row.id;
      if (item.role === 'kit')
        row.components = (item.components || []).map(this.itemPayload);
      return row;
    },
    payload() {
      const quote = Object.fromEntries(
        HEADER.map(field => [
          field,
          this.quote[field] === '' ? null : this.quote[field],
        ])
      );
      quote.items = this.quote.items.map(this.itemPayload);
      return quote;
    },
    async recalculate() {
      this.calculating = true;
      try {
        const { data } = await CrmQuotes.calculate(this.payload());
        this.applyTotals(data.quote);
      } catch (error) {
        // El cálculo es una vista previa; el guardado avisa de los errores.
      } finally {
        this.calculating = false;
      }
    },
    newItem() {
      this.itemForm = {
        role: 'normal',
        article_id: null,
        key: '',
        description: '',
        unit: '',
        price_list_id: null,
        quantity: 1,
        unit_price: 0,
        discount_percent: 0,
        tax_ids: [],
        notes: '',
        extra_notes: '',
      };
    },
    editItem(item) {
      this.itemForm = { ...item };
    },
    saveItem(item) {
      const index = this.quote.items.findIndex(row => row.uid === item.uid);
      if (index === -1) this.quote.items.push(withUid(item));
      else this.quote.items.splice(index, 1, { ...item });
      this.itemForm = null;
    },
    removeItem(item) {
      this.quote.items = this.quote.items.filter(row => row.uid !== item.uid);
    },
    moveItem(index, delta) {
      const items = [...this.quote.items];
      const [row] = items.splice(index, 1);
      items.splice(index + delta, 0, row);
      this.quote.items = items;
    },
    async save() {
      if (!this.quote.organization_id) {
        this.tab = 'general';
        useAlert(this.$t('CRM_ZEUS.QUOTE_FORM.ORGANIZATION_REQUIRED'));
        return;
      }
      if (!this.quote.items.length) {
        useAlert(this.$t('CRM_ZEUS.QUOTE_FORM.ITEMS_REQUIRED'));
        return;
      }
      clearTimeout(this.calcTimer);
      this.saving = true;
      try {
        const body = { quote: this.payload() };
        if (this.isNew) {
          const { data } = await CrmQuotes.create(body);
          useAlert(
            this.$t('CRM_ZEUS.QUOTE_FORM.CREATED', { folio: data.quote.folio })
          );
          this.$router.replace({
            name: 'crmzeus_quote_edit',
            params: { quoteId: data.quote.id },
          });
        } else {
          const { data } = await CrmQuotes.update(this.quoteId, body);
          this.fromApi(data.quote);
          useAlert(this.$t('CRM_ZEUS.FORM.SAVED'));
        }
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      } finally {
        this.saving = false;
      }
    },
    async changeStatus(status) {
      this.pendingStatus = status;
      if (!(await this.$refs.statusDialog.showConfirmation())) return;
      try {
        const { data } = await CrmQuotes.changeStatus(this.quoteId, status);
        this.fromApi(data.quote);
        useAlert(this.$t('CRM_ZEUS.QUOTE_FORM.STATUS_CHANGED'));
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      }
    },
    duplicate() {
      this.$router.push({
        name: 'crmzeus_quote_new',
        query: { from: this.quoteId },
      });
    },
    back() {
      this.$router.push({ name: 'crmzeus_quotes' });
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
          {{ $t('CRM_ZEUS.QUOTE_FORM.BACK') }}
        </button>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ title }}
          <span
            v-if="!isNew && !loading"
            class="ml-2 px-2 py-0.5 text-xs font-medium rounded-full align-middle"
            :class="statusBadge(info.status)"
          >
            {{ info.status_label }}
          </span>
        </h1>
        <p v-if="isNew && series" class="m-0 text-sm text-slate-500">
          {{
            $t('CRM_ZEUS.QUOTE_FORM.NEXT_FOLIO', { folio: series.next_folio })
          }}
        </p>
        <p v-else-if="!isNew && !loading" class="m-0 text-sm text-slate-500">
          {{
            $t('CRM_ZEUS.QUOTE_FORM.CREATED_BY', {
              name: info.created_by ? info.created_by.name : '—',
            })
          }}
        </p>
      </div>
      <div v-if="!loading" class="flex flex-wrap gap-2">
        <woot-button
          v-for="action in statusActions"
          :key="action.status"
          size="small"
          variant="smooth"
          :color-scheme="action.scheme"
          :icon="action.icon"
          @click="changeStatus(action.status)"
        >
          {{
            $t(
              `CRM_ZEUS.QUOTE_FORM.STATUS_ACTIONS.${action.status.toUpperCase()}`
            )
          }}
        </woot-button>
        <woot-button
          v-if="!isNew"
          size="small"
          variant="smooth"
          color-scheme="secondary"
          icon="copy"
          @click="duplicate"
        >
          {{ $t('CRM_ZEUS.QUOTE_FORM.DUPLICATE') }}
        </woot-button>
        <woot-button
          v-if="editable"
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
    <div v-else class="flex-1 px-6 py-4 overflow-auto">
      <p
        v-if="isNew && !series"
        class="p-3 mb-3 text-sm rounded-md text-amber-800 bg-amber-50 dark:bg-amber-900/30 dark:text-amber-300"
      >
        {{ $t('CRM_ZEUS.QUOTES.NO_SERIES') }}
      </p>
      <p
        v-else-if="!isNew && !editable"
        class="p-3 mb-3 text-sm rounded-md bg-slate-50 text-slate-700 dark:bg-slate-800 dark:text-slate-300"
      >
        {{
          info.status === 'pending'
            ? $t('CRM_ZEUS.QUOTE_FORM.NOT_OWNER')
            : $t('CRM_ZEUS.QUOTE_FORM.LOCKED', { status: info.status_label })
        }}
      </p>

      <nav class="flex flex-wrap gap-1 mb-3">
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
          {{ $t(`CRM_ZEUS.QUOTE_FORM.TABS.${t.toUpperCase()}`) }}
        </button>
      </nav>

      <form @submit.prevent="save">
        <fieldset :disabled="!editable" class="max-w-5xl">
          <!-- General -->
          <div v-show="tab === 'general'" class="flex flex-col gap-1">
            <div class="mb-3">
              <span class="block mb-1 text-sm">
                {{ $t('CRM_ZEUS.QUOTE_FORM.ORGANIZATION') }} *
              </span>
              <div
                v-if="organization"
                class="flex items-center gap-2 px-3 py-2 text-sm rounded-md bg-slate-50 dark:bg-slate-800"
              >
                <span class="flex-1 font-medium">{{ organization.name }}</span>
                <span class="text-xs text-slate-500">
                  {{
                    $t(
                      `CRM_ZEUS.TYPE.${organization.organization_type.toUpperCase()}`
                    )
                  }}
                </span>
                <button
                  v-if="editable"
                  type="button"
                  class="p-0 text-woot-600 hover:underline"
                  @click="clearOrganization"
                >
                  {{ $t('CRM_ZEUS.QUOTE_FORM.CHANGE_ORGANIZATION') }}
                </button>
              </div>
              <OrganizationPicker v-else @pick="pickOrganization" />
            </div>
            <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
              <label>
                {{ $t('CRM_ZEUS.QUOTE_FORM.CONTACT') }}
                <select v-model="quote.contact_id">
                  <option value="">—</option>
                  <option
                    v-for="contact in contacts"
                    :key="contact.id"
                    :value="contact.id"
                  >
                    {{ contact.name }}
                  </option>
                </select>
              </label>
              <label>
                {{ $t('CRM_ZEUS.QUOTE_FORM.SHIP_TO') }}
                <select
                  v-model="quote.shipping_address_id"
                  :disabled="isProspect"
                >
                  <option value="">—</option>
                  <option
                    v-for="consignee in consignees"
                    :key="consignee.id"
                    :value="consignee.id"
                  >
                    {{ consignee.consignee_name }} —
                    {{ consignee.full_address }}
                  </option>
                </select>
              </label>
              <label>
                {{ $t('CRM_ZEUS.FIELDS.SELLER') }} *
                <select v-model="quote.seller_id">
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
              <label>
                {{ $t('CRM_ZEUS.QUOTE_FORM.PAYMENT_TERM') }} *
                <select v-model="quote.payment_term_id">
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
                {{ $t('CRM_ZEUS.QUOTE_FORM.CURRENCY') }} *
                <select
                  v-model="quote.currency_id"
                  :disabled="quote.items.length > 0"
                  :title="
                    quote.items.length
                      ? $t('CRM_ZEUS.QUOTE_FORM.CURRENCY_LOCKED')
                      : ''
                  "
                >
                  <option value="">—</option>
                  <option
                    v-for="currency in catalogs.currencies"
                    :key="currency.id"
                    :value="currency.id"
                  >
                    {{ currency.name }} ({{ currency.iso_code }})
                  </option>
                </select>
              </label>
              <label>
                {{ $t('CRM_ZEUS.QUOTE_FORM.QUOTE_DATE') }}
                <input v-model="quote.quote_date" type="date" />
              </label>
              <label>
                {{ $t('CRM_ZEUS.QUOTE_FORM.VALID_UNTIL') }} *
                <input v-model="quote.valid_until" type="date" />
              </label>
              <div class="grid grid-cols-[2fr_1fr] gap-x-2">
                <label>
                  {{ $t('CRM_ZEUS.QUOTE_FORM.DELIVERY_DATE') }} *
                  <input v-model="quote.delivery_date" type="date" />
                </label>
                <label>
                  {{ $t('CRM_ZEUS.QUOTE_FORM.DELIVERY_DAYS') }}
                  <input
                    v-model="deliveryDays"
                    type="number"
                    min="0"
                    @change="applyDeliveryDays"
                  />
                </label>
              </div>
            </div>
          </div>

          <!-- Otros datos -->
          <div v-show="tab === 'other'" class="flex flex-col gap-1">
            <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
              <label>
                {{ $t('CRM_ZEUS.QUOTE_FORM.CFDI_USE') }} *
                <input v-model="quote.cfdi_use" type="text" maxlength="4" />
              </label>
              <label>
                {{ $t('CRM_ZEUS.QUOTE_FORM.SAT_PAYMENT_METHOD') }}
                <input
                  :value="totals.sat_payment_method || '—'"
                  type="text"
                  disabled
                />
              </label>
              <label>
                {{ $t('CRM_ZEUS.QUOTE_FORM.PURCHASE_ORDER') }}
                <input
                  v-model="quote.purchase_order"
                  type="text"
                  maxlength="35"
                />
              </label>
              <label>
                {{ $t('CRM_ZEUS.QUOTE_FORM.PURCHASE_ORDER_DATE') }}
                <input
                  v-model="quote.purchase_order_date"
                  type="date"
                  :disabled="!quote.purchase_order"
                />
              </label>
              <label v-if="Number(totals.exchange_rate) !== 1">
                {{ $t('CRM_ZEUS.QUOTE_FORM.EXCHANGE_RATE') }}
                <input :value="totals.exchange_rate" type="text" disabled />
              </label>
            </div>
            <label>
              {{ $t('CRM_ZEUS.QUOTE_FORM.HEADER_NOTES') }}
              <textarea v-model="quote.header_notes" rows="2" />
            </label>
            <label>
              {{ $t('CRM_ZEUS.QUOTE_FORM.FOOTER_NOTES') }}
              <textarea v-model="quote.footer_notes" rows="2" />
            </label>
          </div>
        </fieldset>
      </form>

      <!-- Partidas -->
      <section class="mt-4">
        <div class="flex items-center justify-between mb-2">
          <h2
            class="m-0 text-base font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ $t('CRM_ZEUS.QUOTE_FORM.ITEMS') }}
            <span
              v-if="calculating"
              class="ml-2 text-xs font-normal text-slate-500"
            >
              {{ $t('CRM_ZEUS.QUOTE_FORM.CALCULATING') }}
            </span>
          </h2>
          <woot-button
            v-if="editable"
            size="small"
            variant="smooth"
            icon="add"
            @click="newItem"
          >
            {{ $t('CRM_ZEUS.QUOTE_FORM.ADD_ITEM') }}
          </woot-button>
        </div>
        <div class="overflow-x-auto">
          <table
            v-if="quote.items.length"
            class="w-full text-sm bg-white border rounded-md dark:bg-slate-800 border-slate-50 dark:border-slate-700"
          >
            <thead>
              <tr class="text-left text-slate-500 dark:text-slate-400">
                <th class="px-3 py-2">
                  {{ $t('CRM_ZEUS.QUOTE_FORM.COLUMNS.KEY') }}
                </th>
                <th class="px-3 py-2">
                  {{ $t('CRM_ZEUS.QUOTE_FORM.COLUMNS.DESCRIPTION') }}
                </th>
                <th class="px-3 py-2 text-right">
                  {{ $t('CRM_ZEUS.QUOTE_FORM.COLUMNS.QUANTITY') }}
                </th>
                <th class="px-3 py-2 text-right">
                  {{ $t('CRM_ZEUS.QUOTE_FORM.COLUMNS.PRICE') }}
                </th>
                <th class="px-3 py-2 text-right">
                  {{ $t('CRM_ZEUS.QUOTE_FORM.COLUMNS.DISCOUNT') }}
                </th>
                <th class="px-3 py-2 text-right">
                  {{ $t('CRM_ZEUS.QUOTE_FORM.COLUMNS.AMOUNT') }}
                </th>
                <th class="px-3 py-2">
                  {{ $t('CRM_ZEUS.QUOTE_FORM.COLUMNS.TAXES') }}
                </th>
                <th v-if="editable" class="w-24 px-3 py-2" />
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="(item, index) in quote.items"
                :key="item.uid"
                class="align-top border-t border-slate-50 dark:border-slate-700"
              >
                <td class="px-3 py-2 text-slate-500">{{ item.key || '—' }}</td>
                <td class="px-3 py-2">
                  <span class="text-slate-800 dark:text-slate-100">
                    {{ item.description }}
                  </span>
                  <span
                    v-if="item.role === 'kit'"
                    class="ml-1 px-1.5 py-0.5 text-xs rounded bg-slate-50 dark:bg-slate-700 text-slate-600 dark:text-slate-300"
                  >
                    {{ $t('CRM_ZEUS.ARTICLES.KIT') }}
                  </span>
                  <p v-if="item.notes" class="m-0 text-xs text-slate-500">
                    {{ item.notes }}
                  </p>
                </td>
                <td class="px-3 py-2 text-right whitespace-nowrap">
                  {{ Number(item.quantity) }} {{ item.unit }}
                </td>
                <td class="px-3 py-2 text-right whitespace-nowrap">
                  {{ money(item.unit_price) }}
                </td>
                <td class="px-3 py-2 text-right">
                  {{
                    Number(item.discount_percent)
                      ? `${Number(item.discount_percent)} %`
                      : '—'
                  }}
                </td>
                <td class="px-3 py-2 text-right whitespace-nowrap">
                  {{
                    item.net_amount === undefined ? '…' : money(item.net_amount)
                  }}
                </td>
                <td class="px-3 py-2 text-xs text-slate-500">
                  {{
                    item.tax_ids.map(id => taxNames[id] || id).join(', ') || '—'
                  }}
                </td>
                <td v-if="editable" class="px-2 py-1 whitespace-nowrap">
                  <woot-button
                    variant="clear"
                    size="tiny"
                    color-scheme="secondary"
                    icon="chevron-up"
                    :disabled="index === 0"
                    @click="moveItem(index, -1)"
                  />
                  <woot-button
                    variant="clear"
                    size="tiny"
                    color-scheme="secondary"
                    icon="chevron-down"
                    :disabled="index === quote.items.length - 1"
                    @click="moveItem(index, 1)"
                  />
                  <woot-button
                    variant="clear"
                    size="tiny"
                    color-scheme="secondary"
                    icon="edit"
                    @click="editItem(item)"
                  />
                  <woot-button
                    variant="clear"
                    size="tiny"
                    color-scheme="alert"
                    icon="delete"
                    @click="removeItem(item)"
                  />
                </td>
              </tr>
            </tbody>
          </table>
          <p v-else class="py-6 text-sm text-center text-slate-500">
            {{ $t('CRM_ZEUS.QUOTE_FORM.NO_ITEMS') }}
          </p>
        </div>
      </section>

      <!-- Totales -->
      <section class="flex justify-end mt-4">
        <table class="text-sm w-full max-w-md">
          <tbody>
            <tr>
              <td class="py-1 text-slate-600">
                {{ $t('CRM_ZEUS.QUOTE_FORM.TOTALS.SUBTOTAL') }}
              </td>
              <td class="py-1 text-right">{{ money(totals.subtotal) }}</td>
            </tr>
            <tr>
              <td class="py-1 text-slate-600">
                {{ $t('CRM_ZEUS.QUOTE_FORM.TOTALS.DISCOUNTS') }}
              </td>
              <td class="py-1 text-right">
                − {{ money(totals.discount_total) }}
              </td>
            </tr>
            <tr>
              <td class="py-1 text-slate-600">
                <div class="flex items-center gap-2">
                  {{ $t('CRM_ZEUS.QUOTE_FORM.TOTALS.EXTRA_DISCOUNT') }}
                  <select
                    v-model="quote.extra_discount_type"
                    class="!mb-0 !w-20 !py-0 text-xs"
                    :disabled="!editable"
                  >
                    <option value="percent">
                      {{ $t('CRM_ZEUS.QUOTE_FORM.TOTALS.BY_PERCENT') }}
                    </option>
                    <option value="amount">
                      {{ $t('CRM_ZEUS.QUOTE_FORM.TOTALS.BY_AMOUNT') }}
                    </option>
                  </select>
                  <input
                    v-model="quote.extra_discount_value"
                    type="number"
                    min="0"
                    step="any"
                    class="!mb-0 !w-24 !py-0 text-xs"
                    :disabled="!editable"
                  />
                </div>
              </td>
              <td class="py-1 text-right">
                − {{ money(totals.extra_discount_amount) }}
              </td>
            </tr>
            <tr
              class="font-medium border-t border-slate-100 dark:border-slate-700"
            >
              <td class="py-1">
                {{ $t('CRM_ZEUS.QUOTE_FORM.TOTALS.NET') }}
              </td>
              <td class="py-1 text-right">{{ money(totals.net_amount) }}</td>
            </tr>
            <tr>
              <td class="py-1 text-slate-600">
                <div class="flex items-center gap-2">
                  {{ $t('CRM_ZEUS.QUOTE_FORM.TOTALS.FREIGHT') }}
                  <input
                    v-model="quote.freight"
                    type="number"
                    min="0"
                    step="any"
                    class="!mb-0 !w-24 !py-0 text-xs"
                    :disabled="!editable"
                  />
                </div>
              </td>
              <td class="py-1 text-right">{{ money(quote.freight) }}</td>
            </tr>
            <tr>
              <td class="py-1 text-slate-600">
                <div class="flex items-center gap-2">
                  {{ $t('CRM_ZEUS.QUOTE_FORM.TOTALS.OTHER_CHARGES') }}
                  <input
                    v-model="quote.other_charges"
                    type="number"
                    min="0"
                    step="any"
                    class="!mb-0 !w-24 !py-0 text-xs"
                    :disabled="!editable"
                  />
                </div>
              </td>
              <td class="py-1 text-right">{{ money(quote.other_charges) }}</td>
            </tr>
            <tr v-for="row in charges" :key="`t${row.tax_id}-${row.percent}`">
              <td class="py-1 text-slate-600">{{ row.name }}</td>
              <td class="py-1 text-right">{{ money(row.amount) }}</td>
            </tr>
            <tr
              v-for="row in withholdings"
              :key="`w${row.tax_id}-${row.percent}`"
            >
              <td class="py-1 text-slate-600">{{ row.name }}</td>
              <td class="py-1 text-right">− {{ money(row.amount) }}</td>
            </tr>
            <tr
              class="text-base font-bold border-t border-slate-100 dark:border-slate-700"
            >
              <td class="py-2">{{ $t('CRM_ZEUS.QUOTE_FORM.TOTALS.TOTAL') }}</td>
              <td class="py-2 text-right">{{ money(totals.total) }}</td>
            </tr>
          </tbody>
        </table>
      </section>
    </div>

    <QuoteItemModal
      v-if="itemForm"
      :item="itemForm"
      :taxes="catalogs.taxes"
      :price-lists="priceLists"
      @save="saveItem"
      @close="itemForm = null"
    />
    <woot-confirm-modal
      ref="statusDialog"
      :title="$t('CRM_ZEUS.QUOTE_FORM.STATUS_TITLE')"
      :description="
        pendingStatus
          ? $t(
              `CRM_ZEUS.QUOTE_FORM.STATUS_CONFIRM.${pendingStatus.toUpperCase()}`,
              { folio: info.folio }
            )
          : ''
      "
      :confirm-label="$t('CRM_ZEUS.QUOTE_FORM.STATUS_ACCEPT')"
      :cancel-label="$t('CRM_ZEUS.CANCEL')"
    />
  </div>
</template>
