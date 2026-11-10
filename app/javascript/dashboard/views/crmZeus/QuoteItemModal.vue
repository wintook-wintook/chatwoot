<!--
  CrmZeus Q2 — partida de una cotización (el modal «Artículo» de CRMZeus): artículo por
  clave o nombre, descripción, unidad, cantidad, lista de precios (pone el precio del
  artículo en esa lista), precio, % de descuento, impuestos y notas. Sin artículo también
  se puede (descripción libre). Los importes los calcula el servidor al cerrar.
  Emite `save` con la partida y `close`.
-->
<script>
import CrmArticles from 'dashboard/api/crmArticles';
import ArticlePicker from './ArticlePicker.vue';
import { defaultId, errorMessage } from './crmHelpers';

export default {
  name: 'CrmQuoteItemModal',
  components: { ArticlePicker },
  props: {
    item: { type: Object, required: true },
    taxes: { type: Array, default: () => [] },
    priceLists: { type: Array, default: () => [] },
  },
  data() {
    return {
      form: { ...this.item, tax_ids: [...(this.item.tax_ids || [])] },
      prices: [],
      loadingArticle: false,
      error: '',
    };
  },
  computed: {
    isNew() {
      return this.item.uid === undefined;
    },
    // Precio con impuestos (sin descuento), como lo enseña CRMZeus junto al precio.
    priceWithTaxes() {
      const percent = this.taxes
        .filter(tax => this.form.tax_ids.includes(tax.id))
        .reduce(
          (sum, tax) =>
            sum + (tax.tax_type.endsWith('withholding') ? -1 : 1) * tax.percent,
          0
        );
      return (Number(this.form.unit_price || 0) * (1 + percent / 100)).toFixed(
        2
      );
    },
  },
  mounted() {
    if (this.form.article_id) this.loadPrices(this.form.article_id);
  },
  methods: {
    async loadPrices(articleId) {
      try {
        const { data } = await CrmArticles.show(articleId);
        this.prices = data.article.prices;
        return data.article;
      } catch (e) {
        this.prices = [];
        return null;
      }
    },
    async pickArticle(listItem) {
      this.loadingArticle = true;
      this.error = '';
      try {
        const article = await this.loadPrices(listItem.id);
        if (!article) throw new Error(this.$t('CRM_ZEUS.ERROR'));
        const listId =
          [defaultId(this.priceLists), ...this.prices.map(p => p.price_list_id)]
            .filter(id => this.prices.some(p => p.price_list_id === id))
            .shift() || null;
        this.form = {
          ...this.form,
          article_id: article.id,
          key: article.key,
          description: article.name,
          unit: article.unit ? article.unit.name : '',
          tax_ids: [...article.tax_ids],
          price_list_id: listId,
        };
        this.applyPrice();
      } catch (e) {
        this.error = errorMessage(e, e.message);
      } finally {
        this.loadingArticle = false;
      }
    },
    clearArticle() {
      this.form = {
        ...this.form,
        article_id: null,
        key: '',
        price_list_id: null,
      };
      this.prices = [];
    },
    applyPrice() {
      const price = this.prices.find(
        p => p.price_list_id === this.form.price_list_id
      );
      if (price) this.form.unit_price = price.price;
    },
    toggleTax(id) {
      const ids = this.form.tax_ids;
      this.form.tax_ids = ids.includes(id)
        ? ids.filter(taxId => taxId !== id)
        : [...ids, id];
    },
    save() {
      if (!String(this.form.description || '').trim()) {
        this.error = this.$t('CRM_ZEUS.QUOTE_FORM.ITEM_DESCRIPTION_REQUIRED');
        return;
      }
      if (!(Number(this.form.quantity) > 0)) {
        this.error = this.$t('CRM_ZEUS.QUOTE_FORM.ITEM_QUANTITY_REQUIRED');
        return;
      }
      this.$emit('save', { ...this.form });
    },
  },
};
</script>

<template>
  <woot-modal
    show
    :on-close="() => $emit('close')"
    modal-type="right-aligned"
    size="wide"
  >
    <div class="flex flex-col h-auto">
      <woot-modal-header
        :header-title="
          isNew
            ? $t('CRM_ZEUS.QUOTE_FORM.ITEM_NEW')
            : $t('CRM_ZEUS.QUOTE_FORM.ITEM_EDIT')
        "
      />
      <form class="flex flex-col w-full gap-1 px-8 pt-4" @submit.prevent="save">
        <div
          v-if="error"
          class="p-2 mb-2 text-sm text-red-800 rounded-md bg-red-50 dark:bg-red-900/30 dark:text-red-300"
        >
          {{ error }}
        </div>
        <div class="mb-3">
          <span class="block mb-1 text-sm">
            {{ $t('CRM_ZEUS.QUOTE_FORM.ARTICLE') }}
          </span>
          <div
            v-if="form.article_id"
            class="flex items-center gap-2 px-3 py-2 text-sm rounded-md bg-slate-50 dark:bg-slate-700"
          >
            <span v-if="form.key" class="text-slate-500">{{ form.key }}</span>
            <span class="flex-1">{{ form.description }}</span>
            <button
              type="button"
              class="p-0 text-woot-600 hover:underline"
              @click="clearArticle"
            >
              {{ $t('CRM_ZEUS.QUOTE_FORM.CHANGE_ARTICLE') }}
            </button>
          </div>
          <ArticlePicker
            v-else
            :placeholder="$t('CRM_ZEUS.QUOTE_FORM.ARTICLE_SEARCH')"
            @pick="pickArticle"
          />
          <p v-if="!form.article_id" class="m-0 mt-1 text-xs text-slate-500">
            {{ $t('CRM_ZEUS.QUOTE_FORM.FREE_TEXT_HINT') }}
          </p>
        </div>
        <label>
          {{ $t('CRM_ZEUS.QUOTE_FORM.DESCRIPTION') }} *
          <input v-model="form.description" type="text" maxlength="200" />
        </label>
        <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-3">
          <label>
            {{ $t('CRM_ZEUS.QUOTE_FORM.QUANTITY') }} *
            <input v-model="form.quantity" type="number" min="0" step="any" />
          </label>
          <label>
            {{ $t('CRM_ZEUS.QUOTE_FORM.UNIT') }}
            <input v-model="form.unit" type="text" maxlength="20" />
          </label>
          <label>
            {{ $t('CRM_ZEUS.QUOTE_FORM.PRICE_LIST') }}
            <select
              v-model="form.price_list_id"
              :disabled="!prices.length"
              @change="applyPrice"
            >
              <option :value="null">—</option>
              <option
                v-for="list in priceLists"
                :key="list.id"
                :value="list.id"
                :disabled="!prices.some(p => p.price_list_id === list.id)"
              >
                {{ list.name }}
              </option>
            </select>
          </label>
        </div>
        <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-3">
          <label>
            {{ $t('CRM_ZEUS.QUOTE_FORM.UNIT_PRICE') }}
            <input v-model="form.unit_price" type="number" min="0" step="any" />
          </label>
          <label>
            {{ $t('CRM_ZEUS.QUOTE_FORM.DISCOUNT_PERCENT') }}
            <input
              v-model="form.discount_percent"
              type="number"
              min="0"
              max="100"
              step="any"
            />
          </label>
          <label>
            {{ $t('CRM_ZEUS.QUOTE_FORM.PRICE_WITH_TAXES') }}
            <input :value="priceWithTaxes" type="text" disabled />
          </label>
        </div>
        <fieldset class="mb-3">
          <legend class="mb-1 text-sm">
            {{ $t('CRM_ZEUS.QUOTE_FORM.TAXES') }}
          </legend>
          <div class="flex flex-wrap gap-x-4 gap-y-1">
            <label
              v-for="tax in taxes"
              :key="tax.id"
              class="flex items-center gap-2 text-sm"
            >
              <input
                type="checkbox"
                class="!m-0"
                :checked="form.tax_ids.includes(tax.id)"
                @change="toggleTax(tax.id)"
              />
              {{ tax.name }}
            </label>
          </div>
        </fieldset>
        <label>
          {{ $t('CRM_ZEUS.QUOTE_FORM.NOTES') }}
          <textarea v-model="form.notes" rows="2" />
        </label>
        <label>
          {{ $t('CRM_ZEUS.QUOTE_FORM.EXTRA_NOTES') }}
          <textarea v-model="form.extra_notes" rows="2" />
        </label>
        <div
          class="sticky bottom-0 z-10 flex justify-end gap-2 px-8 py-3 mt-4 -mx-8 bg-white border-t dark:bg-slate-800 border-slate-50 dark:border-slate-700"
        >
          <button type="button" class="button clear" @click="$emit('close')">
            {{ $t('CRM_ZEUS.CANCEL') }}
          </button>
          <woot-submit-button
            :loading="loadingArticle"
            :button-text="$t('CRM_ZEUS.QUOTE_FORM.ITEM_ACCEPT')"
          />
        </div>
      </form>
    </div>
  </woot-modal>
</template>
