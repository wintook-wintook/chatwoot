<!--
  Plan-Catalogo-Cotizaciones C1 — alta y edición de un producto, servicio o
  refacción (panel lateral, mismo estilo que el formulario de contacto).
  Categoría, unidad e impuesto se eligen de las listas de «Parámetros» (params); se ofrecen las activas y la
  que ya tenga el producto aunque esté desactivada.
-->
<script>
import { useAlert } from 'dashboard/composables';
import CatalogItemsAPI from 'dashboard/api/catalogItems';

const KINDS = ['service', 'product', 'part'];

export default {
  name: 'CatalogItemForm',
  props: {
    show: { type: Boolean, default: false },
    item: { type: Object, default: null },
    params: {
      type: Object,
      default: () => ({ categories: [], taxes: [], units: [] }),
    },
    defaultCurrency: { type: String, default: 'MXN' },
    showCost: { type: Boolean, default: true },
  },
  emits: ['close', 'saved'],
  data() {
    // image: la foto que eligió (se sube al guardar); dropImage: quitar la que tenía.
    return { form: this.blank(), saving: false, image: null, dropImage: false };
  },
  computed: {
    isEdit() {
      return !!(this.item && this.item.id);
    },
    kinds() {
      return KINDS;
    },
    categoryOptions() {
      return (this.params.categories || []).flatMap(category =>
        [
          category,
          ...(category.children || []).map(child => ({
            ...child,
            label: `\u00a0\u00a0· ${child.name}`,
          })),
        ].filter(row => this.offered(row, this.form.catalog_category_id))
      );
    },
    unitOptions() {
      return (this.params.units || []).filter(row =>
        this.offered(row, this.form.catalog_unit_id)
      );
    },
    taxOptions() {
      return (this.params.taxes || []).filter(
        row =>
          row.kind !== 'withholding' && this.offered(row, this.form.tax_rate_id)
      );
    },
    // Retenciones: las activas y las que ya lleva el producto.
    withholdingOptions() {
      const chosen = this.form.withholding_rate_ids || [];
      return (this.params.taxes || []).filter(
        row =>
          row.kind === 'withholding' && (row.active || chosen.includes(row.id))
      );
    },
    defaultTax() {
      return (this.params.taxes || []).find(
        tax => tax.is_default && tax.kind !== 'withholding'
      );
    },
    manageable() {
      return !!this.params.can_edit;
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(open) {
        if (!open) return;
        this.form = this.item
          ? { ...this.blank(), ...this.item }
          : this.blank();
        this.image = null;
        this.dropImage = false;
      },
    },
  },
  methods: {
    pickImage(event) {
      const [file] = event.target.files || [];
      this.image = file || null;
      this.dropImage = false;
    },
    // La foto va aparte del producto (multipart): después de guardarlo.
    async saveImage(item) {
      if (this.image) {
        const { data } = await CatalogItemsAPI.uploadImage(item.id, this.image);
        return data.catalog_item;
      }
      if (this.dropImage && item.image_url) {
        const { data } = await CatalogItemsAPI.removeImage(item.id);
        return data.catalog_item;
      }
      return item;
    },
    blank() {
      return {
        name: '',
        sku: '',
        kind: 'service',
        catalog_category_id: null,
        catalog_unit_id: null,
        tax_rate_id: null,
        price_includes_tax: false,
        sat_code: '',
        withholding_rate_ids: [],
        price: '',
        currency: this.defaultCurrency,
        cost: '',
        description: '',
        active: true,
      };
    },
    // Las activas y la que ya tiene el producto.
    offered(row, currentId) {
      return row.active || row.id === currentId;
    },
    async save() {
      if (!this.form.name.trim()) return;
      this.saving = true;
      // La categoría y la unidad van por su lista (el texto lo arma el servidor).
      const { category, unit, ...payload } = this.form;
      if (!this.showCost) delete payload.cost;
      try {
        const { data } = this.isEdit
          ? await CatalogItemsAPI.update(this.item.id, {
              catalog_item: payload,
            })
          : await CatalogItemsAPI.create({ catalog_item: payload });
        const saved = await this.saveImage(data.catalog_item);
        useAlert(this.$t('CATALOG.SAVED'));
        this.$emit('saved', saved);
      } catch (error) {
        const message = error?.response?.data?.error;
        useAlert(
          Array.isArray(message) ? message.join(', ') : this.$t('CATALOG.ERROR')
        );
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
          isEdit ? $t('CATALOG.FORM.EDIT_TITLE') : $t('CATALOG.FORM.NEW_TITLE')
        "
      />
      <form
        class="flex flex-col self-stretch w-full gap-1 px-8 pt-4 pb-0"
        @submit.prevent="save"
      >
        <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-[2fr_1fr]">
          <label>
            {{ $t('CATALOG.FORM.NAME') }}
            <input v-model="form.name" type="text" required />
          </label>
          <label>
            {{ $t('CATALOG.FORM.SKU') }}
            <input v-model="form.sku" type="text" />
            <span class="text-xs text-slate-500 dark:text-slate-400">{{
              $t('CATALOG.FORM.SKU_HINT')
            }}</span>
          </label>
        </div>
        <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-3">
          <label>
            {{ $t('CATALOG.FORM.KIND') }}
            <select v-model="form.kind">
              <option v-for="kind in kinds" :key="kind" :value="kind">
                {{ $t(`CATALOG.KINDS.${kind}`) }}
              </option>
            </select>
          </label>
          <label>
            {{ $t('CATALOG.FORM.CATEGORY') }}
            <select v-model="form.catalog_category_id">
              <option :value="null">
                {{ $t('CATALOG.FORM_EXTRA.CATEGORY_NONE') }}
              </option>
              <option
                v-for="option in categoryOptions"
                :key="option.id"
                :value="option.id"
              >
                {{ option.label || option.name }}
              </option>
            </select>
          </label>
          <label>
            {{ $t('CATALOG.FORM.UNIT') }}
            <select v-model="form.catalog_unit_id">
              <option :value="null">
                {{ $t('CATALOG.FORM_EXTRA.UNIT_NONE') }}
              </option>
              <option
                v-for="option in unitOptions"
                :key="option.id"
                :value="option.id"
              >
                {{ option.name }} ({{ option.abbreviation }})
              </option>
            </select>
          </label>
        </div>
        <p v-if="manageable" class="mb-2 -mt-2 text-xs text-slate-500">
          {{ $t('CATALOG.FORM_EXTRA.MANAGE') }}
        </p>
        <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-3">
          <label>
            {{ $t('CATALOG.FORM.PRICE') }}
            <input v-model="form.price" type="number" min="0" step="0.01" />
          </label>
          <label>
            {{ $t('CATALOG.FORM.CURRENCY') }}
            <input
              v-model="form.currency"
              type="text"
              maxlength="3"
              class="uppercase"
            />
          </label>
          <label v-if="showCost">
            {{ $t('CATALOG.FORM.COST') }}
            <input v-model="form.cost" type="number" min="0" step="0.01" />
            <span class="text-xs text-slate-500 dark:text-slate-400">{{
              $t('CATALOG.FORM.COST_HINT')
            }}</span>
          </label>
        </div>
        <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-3">
          <label>
            {{ $t('CATALOG.FORM_EXTRA.TAX') }}
            <select v-model="form.tax_rate_id">
              <option :value="null">
                {{
                  $t('CATALOG.FORM_EXTRA.TAX_DEFAULT', {
                    name: defaultTax ? defaultTax.name : '—',
                  })
                }}
              </option>
              <option
                v-for="option in taxOptions"
                :key="option.id"
                :value="option.id"
              >
                {{ option.name }}
              </option>
            </select>
          </label>
          <label class="flex items-start gap-2 sm:col-span-2 sm:pt-6">
            <input
              v-model="form.price_includes_tax"
              type="checkbox"
              class="m-0 mt-1"
            />
            <span>
              {{ $t('CATALOG.FORM_EXTRA.PRICE_INCLUDES_TAX') }}
              <span class="block text-xs text-slate-500 dark:text-slate-400">
                {{ $t('CATALOG.FORM_EXTRA.PRICE_INCLUDES_TAX_HINT') }}
              </span>
            </span>
          </label>
        </div>
        <div v-if="withholdingOptions.length" class="flex flex-col gap-1 mb-4">
          <span>{{ $t('CATALOG.FORM_EXTRA.WITHHOLDINGS') }}</span>
          <div class="flex flex-wrap gap-x-4 gap-y-1">
            <label
              v-for="option in withholdingOptions"
              :key="option.id"
              class="flex items-center gap-1 mb-0 text-sm"
            >
              <input
                v-model="form.withholding_rate_ids"
                type="checkbox"
                class="m-0"
                :value="option.id"
              />
              {{ option.name }}
            </label>
          </div>
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ $t('CATALOG.FORM_EXTRA.WITHHOLDINGS_HINT') }}
          </span>
        </div>
        <label>
          {{ $t('CATALOG.FORM_EXTRA.SAT_CODE') }}
          <input
            v-model="form.sat_code"
            type="text"
            maxlength="20"
            class="uppercase"
          />
          <span class="text-xs text-slate-500 dark:text-slate-400">{{
            $t('CATALOG.FORM_EXTRA.SAT_CODE_HINT')
          }}</span>
        </label>
        <label>
          {{ $t('CATALOG.FORM.DESCRIPTION') }}
          <textarea v-model="form.description" rows="3" />
        </label>
        <div class="flex flex-col gap-1">
          <span>{{ $t('CATALOG.FORM.IMAGE') }}</span>
          <div
            v-if="form.image_url && !dropImage && !image"
            class="flex items-center gap-3"
          >
            <img
              :src="form.image_url"
              :alt="form.name"
              class="object-cover w-16 h-16 rounded"
            />
            <button
              type="button"
              class="text-xs text-red-600 hover:underline"
              @click="dropImage = true"
            >
              {{ $t('CATALOG.FORM.IMAGE_REMOVE') }}
            </button>
          </div>
          <input
            type="file"
            accept="image/png,image/jpeg,image/webp"
            class="!mb-0"
            @change="pickImage"
          />
          <span class="text-xs text-slate-500 dark:text-slate-400">{{
            $t('CATALOG.FORM.IMAGE_HINT')
          }}</span>
        </div>
        <label class="flex items-center gap-2">
          <input v-model="form.active" type="checkbox" class="m-0" />
          {{ $t('CATALOG.FORM.ACTIVE') }}
        </label>
        <div
          class="sticky bottom-0 z-10 flex justify-end gap-2 px-8 py-3 mt-4 -mx-8 bg-white border-t dark:bg-slate-800 border-slate-50 dark:border-slate-700"
        >
          <button type="button" class="button clear" @click="$emit('close')">
            {{ $t('CATALOG.FORM.CANCEL') }}
          </button>
          <woot-submit-button
            :loading="saving"
            :button-text="$t('CATALOG.FORM.SAVE')"
          />
        </div>
      </form>
    </div>
  </woot-modal>
</template>
