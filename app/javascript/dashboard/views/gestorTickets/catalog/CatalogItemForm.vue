<!--
  Plan-Catalogo-Cotizaciones C1 — alta y edición de un producto, servicio o
  refacción (panel lateral, mismo estilo que el formulario de contacto).
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
    categories: { type: Array, default: () => [] },
    defaultCurrency: { type: String, default: 'MXN' },
    showCost: { type: Boolean, default: true },
  },
  emits: ['close', 'saved'],
  data() {
    return { form: this.blank(), saving: false };
  },
  computed: {
    isEdit() {
      return !!(this.item && this.item.id);
    },
    kinds() {
      return KINDS;
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(open) {
        if (open)
          this.form = this.item
            ? { ...this.blank(), ...this.item }
            : this.blank();
      },
    },
  },
  methods: {
    blank() {
      return {
        name: '',
        sku: '',
        kind: 'service',
        category: '',
        unit: '',
        price: '',
        currency: this.defaultCurrency,
        cost: '',
        description: '',
        active: true,
      };
    },
    async save() {
      if (!this.form.name.trim()) return;
      this.saving = true;
      const payload = { ...this.form };
      if (!this.showCost) delete payload.cost;
      try {
        const { data } = this.isEdit
          ? await CatalogItemsAPI.update(this.item.id, {
              catalog_item: payload,
            })
          : await CatalogItemsAPI.create({ catalog_item: payload });
        useAlert(this.$t('CATALOG.SAVED'));
        this.$emit('saved', data.catalog_item);
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
            <input
              v-model="form.category"
              type="text"
              list="catalog-categories"
            />
            <datalist id="catalog-categories">
              <option
                v-for="category in categories"
                :key="category"
                :value="category"
              />
            </datalist>
          </label>
          <label>
            {{ $t('CATALOG.FORM.UNIT') }}
            <input
              v-model="form.unit"
              type="text"
              :placeholder="$t('CATALOG.FORM.UNIT_PLACEHOLDER')"
            />
          </label>
        </div>
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
        <label>
          {{ $t('CATALOG.FORM.DESCRIPTION') }}
          <textarea v-model="form.description" rows="3" />
        </label>
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
