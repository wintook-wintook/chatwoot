<!--
  Plan-Contratos R1 — alta y edición de un contrato (panel lateral, como el del
  catálogo). Al elegir el tipo se llenan sus valores por omisión (cada cuánto se
  cobra, plazo, si se renueva solo) y aparecen sus datos propios. Al ligar un producto
  se marca «Usar el precio del producto»: el precio sigue al del catálogo; sin la
  casilla, el contrato tiene su precio especial.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ContractsAPI from 'dashboard/api/contracts';
import CatalogItemsAPI from 'dashboard/api/catalogItems';
import CustomerAssetsAPI from 'dashboard/api/customerAssets';
import ContactPicker from 'dashboard/views/gestorTickets/ContactPicker.vue';
import { STATUSES, UNITS } from './contractHelpers';

const today = () => new Date().toISOString().slice(0, 10);
const orNull = value => (value === '' || value === undefined ? null : value);

export default {
  name: 'ContractForm',
  components: { ContactPicker },
  props: {
    show: { type: Boolean, default: false },
    contract: { type: Object, default: null },
    // Desde la pestaña del contacto: el cliente ya está elegido.
    contactId: { type: Number, default: null },
    types: { type: Array, default: () => [] },
    showAmounts: { type: Boolean, default: true },
  },
  emits: ['close', 'saved'],
  data() {
    return {
      form: this.blank(),
      contact: null,
      catalog: [],
      assets: [],
      saving: false,
    };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
    isEdit() {
      return !!(this.contract && this.contract.id);
    },
    units() {
      return UNITS;
    },
    statuses() {
      return STATUSES;
    },
    // Los activos, más el del contrato que se edita aunque ya no esté activo.
    typeOptions() {
      return this.types.filter(
        type => type.active || type.id === this.form.contract_type_id
      );
    },
    selectedType() {
      return this.types.find(type => type.id === this.form.contract_type_id);
    },
    selectedItem() {
      return this.catalog.find(item => item.id === this.form.catalog_item_id);
    },
    customFields() {
      return (this.selectedType && this.selectedType.custom_fields) || [];
    },
    chosenContactId() {
      return this.contactId || (this.contact && this.contact.id) || null;
    },
    canSave() {
      return (
        !!this.chosenContactId &&
        !!this.form.contract_type_id &&
        !!(this.form.title || '').trim()
      );
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(open) {
        if (!open) return;
        this.form = this.contract
          ? { ...this.blank(), ...this.contract }
          : this.blank();
        this.contact = this.contract
          ? this.contract.links && this.contract.links.contact
          : null;
        if (!this.contract && this.typeOptions.length === 1)
          this.chooseType(this.typeOptions[0].id);
        this.fetchAssets();
      },
    },
    chosenContactId: 'fetchAssets',
  },
  mounted() {
    this.$store.dispatch('agents/get');
    this.fetchCatalog();
  },
  methods: {
    blank() {
      return {
        contract_type_id: null,
        catalog_item_id: null,
        customer_asset_id: null,
        assignee_id: null,
        title: '',
        quantity: 1,
        price: '',
        price_from_catalog: false,
        currency: 'MXN',
        every: 1,
        unit: 'month',
        starts_on: today(),
        next_charge_on: '',
        term_months: '',
        auto_renew: true,
        status: 'active',
        notes: '',
        custom_attributes: {},
      };
    },
    async fetchCatalog() {
      try {
        const { data } = await CatalogItemsAPI.search({ active: 'true' });
        this.catalog = data.catalog_items || [];
      } catch {
        this.catalog = [];
      }
    },
    async fetchAssets() {
      if (!this.chosenContactId) {
        this.assets = [];
        return;
      }
      try {
        const { data } = await CustomerAssetsAPI.forContact(
          this.chosenContactId
        );
        this.assets = data.customer_assets || [];
      } catch {
        this.assets = [];
      }
    },
    chooseType(id) {
      this.form.contract_type_id = id;
      const type = this.selectedType;
      if (!type || this.isEdit) return;
      this.form.every = type.default_every;
      this.form.unit = type.default_unit;
      this.form.term_months = type.default_term_months || '';
      this.form.auto_renew = type.default_auto_renew;
    },
    chooseItem(id) {
      this.form.catalog_item_id = id || null;
      const item = this.selectedItem;
      if (!item) {
        this.form.price_from_catalog = false;
        return;
      }
      if (!this.form.title) this.form.title = item.name;
      this.setPriceFromCatalog(true);
    },
    // Con la casilla se muestra el precio del producto (el servidor lo vuelve a tomar).
    setPriceFromCatalog(value) {
      this.form.price_from_catalog = value;
      const item = this.selectedItem;
      if (!value || !item) return;
      this.form.price = item.price;
      this.form.currency = item.currency || this.form.currency;
    },
    setCustom(key, value) {
      this.form.custom_attributes = {
        ...this.form.custom_attributes,
        [key]: value,
      };
    },
    payload() {
      const form = this.form;
      const data = {
        contract_type_id: form.contract_type_id,
        catalog_item_id: orNull(form.catalog_item_id),
        customer_asset_id: orNull(form.customer_asset_id),
        assignee_id: orNull(form.assignee_id),
        title: form.title.trim(),
        quantity: orNull(form.quantity) || 1,
        currency: (form.currency || 'MXN').toUpperCase(),
        every: orNull(form.every) || 1,
        unit: form.unit,
        starts_on: form.starts_on,
        next_charge_on: orNull(form.next_charge_on),
        term_months: orNull(form.term_months),
        auto_renew: form.auto_renew,
        notes: form.notes,
        custom_attributes: form.custom_attributes,
      };
      if (this.showAmounts) {
        data.price = orNull(form.price) || 0;
        data.price_from_catalog =
          !!form.catalog_item_id && form.price_from_catalog;
      }
      if (this.isEdit) data.status = form.status;
      else data.contact_id = this.chosenContactId;
      return data;
    },
    async save() {
      if (!this.canSave) return;
      this.saving = true;
      try {
        const { data } = this.isEdit
          ? await ContractsAPI.update(this.contract.id, this.payload())
          : await ContractsAPI.create(this.payload());
        useAlert(this.$t('CONTRACTS.SAVED'));
        this.$emit('saved', data.contract);
      } catch (error) {
        useAlert(error?.response?.data?.error || this.$t('CONTRACTS.ERROR'));
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal
    :show="show"
    :on-close="() => $emit('close')"
    modal-type="right-aligned"
    size="wide"
  >
    <div class="flex flex-col h-auto">
      <woot-modal-header
        :header-title="
          isEdit
            ? $t('CONTRACTS.FORM.EDIT_TITLE')
            : $t('CONTRACTS.FORM.NEW_TITLE')
        "
      />
      <form
        class="flex flex-col self-stretch w-full gap-1 px-8 pt-4 pb-0"
        @submit.prevent="save"
      >
        <p
          v-if="!typeOptions.length"
          class="p-3 mb-2 text-sm rounded-md text-amber-700 bg-amber-50 dark:bg-amber-900/30 dark:text-amber-300"
        >
          {{ $t('CONTRACTS.FORM.NO_TYPES') }}
        </p>

        <div v-if="!contactId && !isEdit" class="mb-3">
          <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
            {{ $t('CONTRACTS.FORM.CONTACT') }}
          </span>
          <ContactPicker v-model="contact" />
        </div>

        <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
          <label>
            {{ $t('CONTRACTS.FORM.TYPE') }}
            <select
              :value="form.contract_type_id"
              required
              @change="chooseType(Number($event.target.value))"
            >
              <option :value="null" disabled>
                {{ $t('CONTRACTS.FORM.NONE') }}
              </option>
              <option
                v-for="type in typeOptions"
                :key="type.id"
                :value="type.id"
              >
                {{ type.name }}
              </option>
            </select>
          </label>
          <label>
            {{ $t('CONTRACTS.FORM.FROM_CATALOG') }}
            <select
              :value="form.catalog_item_id"
              @change="chooseItem(Number($event.target.value) || null)"
            >
              <option :value="null">{{ $t('CONTRACTS.FORM.NONE') }}</option>
              <option v-for="item in catalog" :key="item.id" :value="item.id">
                {{ item.name }}
              </option>
            </select>
          </label>
        </div>

        <label>
          {{ $t('CONTRACTS.FORM.CONCEPT') }}
          <input
            v-model="form.title"
            type="text"
            required
            :placeholder="$t('CONTRACTS.FORM.CONCEPT_PLACEHOLDER')"
          />
        </label>

        <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-3">
          <label>
            {{ $t('CONTRACTS.FORM.QUANTITY') }}
            <input v-model="form.quantity" type="number" min="0" step="any" />
          </label>
          <label v-if="showAmounts">
            {{ $t('CONTRACTS.FORM.PRICE') }}
            <input
              v-model="form.price"
              type="number"
              min="0"
              step="0.01"
              :disabled="form.price_from_catalog"
            />
          </label>
          <label v-if="showAmounts">
            {{ $t('CONTRACTS.FORM.CURRENCY') }}
            <input
              v-model="form.currency"
              type="text"
              maxlength="3"
              class="uppercase"
              :disabled="form.price_from_catalog"
            />
          </label>
        </div>
        <label
          v-if="showAmounts && form.catalog_item_id"
          class="flex items-start gap-2 mb-3"
        >
          <input
            type="checkbox"
            class="!m-0 mt-1"
            :checked="form.price_from_catalog"
            @change="setPriceFromCatalog($event.target.checked)"
          />
          <span class="flex flex-col">
            {{ $t('CONTRACTS.FORM.PRICE_FROM_CATALOG') }}
            <span class="text-xs text-slate-500 dark:text-slate-400">{{
              $t('CONTRACTS.FORM.PRICE_FROM_CATALOG_HINT')
            }}</span>
          </span>
        </label>

        <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-3">
          <label>
            {{ $t('CONTRACTS.FORM.EVERY') }}
            <span class="flex gap-2">
              <input
                v-model.number="form.every"
                type="number"
                min="1"
                class="!w-20"
              />
              <select v-model="form.unit">
                <option v-for="unit in units" :key="unit" :value="unit">
                  {{ $t(`CONTRACTS.UNITS.${unit}`) }}
                </option>
              </select>
            </span>
          </label>
          <label>
            {{ $t('CONTRACTS.FORM.STARTS') }}
            <input v-model="form.starts_on" type="date" required />
          </label>
          <label>
            {{ $t('CONTRACTS.FORM.NEXT_CHARGE') }}
            <input v-model="form.next_charge_on" type="date" />
            <span class="text-xs text-slate-500 dark:text-slate-400">{{
              $t('CONTRACTS.FORM.NEXT_CHARGE_HINT')
            }}</span>
          </label>
        </div>

        <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
          <label>
            {{ $t('CONTRACTS.FORM.TERM') }}
            <input v-model="form.term_months" type="number" min="1" />
            <span class="text-xs text-slate-500 dark:text-slate-400">{{
              $t('CONTRACTS.FORM.TERM_HINT')
            }}</span>
          </label>
          <label class="flex items-center gap-2 sm:pt-6">
            <input v-model="form.auto_renew" type="checkbox" class="!m-0" />
            {{ $t('CONTRACTS.FORM.AUTO_RENEW') }}
          </label>
        </div>

        <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
          <label>
            {{ $t('CONTRACTS.FORM.ASSET') }}
            <select v-model="form.customer_asset_id">
              <option :value="null">{{ $t('CONTRACTS.FORM.NONE') }}</option>
              <option v-for="asset in assets" :key="asset.id" :value="asset.id">
                {{ asset.name }}
              </option>
            </select>
          </label>
          <label>
            {{ $t('CONTRACTS.FORM.ASSIGNEE') }}
            <select v-model="form.assignee_id">
              <option :value="null">
                {{ $t('CONTRACTS.FORM.ASSIGNEE_NONE') }}
              </option>
              <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                {{ agent.name }}
              </option>
            </select>
          </label>
        </div>

        <!-- Los datos propios del tipo -->
        <fieldset
          v-if="customFields.length"
          class="p-3 mb-3 border rounded-md border-slate-100 dark:border-slate-700"
        >
          <legend class="px-1 text-sm font-medium">
            {{ $t('CONTRACTS.FORM.EXTRA', { type: selectedType.name }) }}
          </legend>
          <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-2">
            <label v-for="field in customFields" :key="field.key">
              {{ field.label }}
              <input
                :type="field.type === 'text' ? 'text' : field.type"
                :value="form.custom_attributes[field.key]"
                @input="setCustom(field.key, $event.target.value)"
              />
            </label>
          </div>
        </fieldset>

        <label v-if="isEdit">
          {{ $t('CONTRACTS.FORM.STATUS') }}
          <select v-model="form.status">
            <option v-for="status in statuses" :key="status" :value="status">
              {{ $t(`CONTRACTS.STATUS.${status}`) }}
            </option>
          </select>
        </label>

        <label>
          {{ $t('CONTRACTS.FORM.NOTES') }}
          <textarea v-model="form.notes" rows="2" />
        </label>

        <div
          class="sticky bottom-0 z-10 flex justify-end gap-2 px-8 py-3 mt-4 -mx-8 bg-white border-t dark:bg-slate-800 border-slate-50 dark:border-slate-700"
        >
          <button type="button" class="button clear" @click="$emit('close')">
            {{ $t('CONTRACTS.FORM.CANCEL') }}
          </button>
          <woot-submit-button
            :loading="saving"
            :disabled="!canSave"
            :button-text="$t('CONTRACTS.FORM.SAVE')"
          />
        </div>
      </form>
    </div>
  </woot-modal>
</template>
