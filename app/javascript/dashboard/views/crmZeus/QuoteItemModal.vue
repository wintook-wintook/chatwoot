<!--
  CrmZeus Q2 — partida de una cotización (el modal «Artículo» de CRMZeus): artículo por
  clave o nombre, descripción, unidad, cantidad, lista de precios (pone el precio del
  artículo en esa lista), precio, % de descuento, impuestos y notas. Sin artículo también
  se puede (descripción libre). Los importes los calcula el servidor al cerrar.
  Emite `save` con la partida y `close`.
  Q3: si el artículo es un kit no almacenable, la partida es un kit y trae sus componentes
  (unidades por kit × cantidad); se pueden cambiar las unidades, y reemplazar o quitar el
  componente si es reemplazable (como CRMZeus). También se agregan componentes: entran con 1
  unidad por kit, unidades editables y se pueden quitar. Los componentes no llevan precio.
-->
<script>
import CrmArticles from 'dashboard/api/crmArticles';
import ArticlePicker from './ArticlePicker.vue';
import {
  defaultId,
  errorMessage,
  isQuotableKit,
  kitComponentRows,
  scaleComponents,
  withUnitsPerKit,
} from './crmHelpers';

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
      form: {
        ...this.item,
        tax_ids: [...(this.item.tax_ids || [])],
        components:
          this.item.role === 'kit'
            ? withUnitsPerKit(this.item.components, this.item.quantity)
            : [],
      },
      prices: [],
      replacing: null,
      loadingArticle: false,
      error: '',
    };
  },
  computed: {
    isKit() {
      return this.form.role === 'kit';
    },
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
  watch: {
    'form.quantity': function scale(quantity) {
      if (this.isKit)
        this.form.components = scaleComponents(this.form.components, quantity);
    },
  },
  async mounted() {
    if (!this.form.article_id) return;
    const article = await this.loadPrices(this.form.article_id);
    if (article && this.isKit) this.applyComponentRules(article);
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
        const kit = isQuotableKit(article);
        if (kit && !(article.components || []).length)
          throw new Error(
            this.$t('CRM_ZEUS.QUOTE_FORM.KIT_WITHOUT_COMPONENTS')
          );
        this.form = {
          ...this.form,
          role: kit ? 'kit' : 'normal',
          article_id: article.id,
          key: article.key,
          description: article.name,
          unit: article.unit ? article.unit.name : '',
          tax_ids: [...article.tax_ids],
          price_list_id: listId,
          components: kit ? kitComponentRows(article, this.form.quantity) : [],
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
        role: 'normal',
        article_id: null,
        key: '',
        price_list_id: null,
        components: [],
      };
      this.prices = [];
      this.replacing = null;
    },
    // Una partida ya guardada no trae «reemplazable» ni «permite cambiar unidades»: se toman
    // del kit en el catálogo, por artículo; lo que no está en el catálogo se agregó aquí.
    applyComponentRules(article) {
      const rules = Object.fromEntries(
        (article.components || []).map(row => [row.component_id, row])
      );
      this.form.components = this.form.components.map(row => {
        const rule = rules[row.article_id];
        // No está en el kit del catálogo: se agregó en la cotización.
        if (!rule) return { ...row, replaceable: true, units_editable: true };
        return {
          ...row,
          replaceable: Boolean(rule.replaceable),
          units_editable: Boolean(rule.units_editable),
        };
      });
    },
    setUnitsPerKit(index, value) {
      const rows = [...this.form.components];
      rows[index] = { ...rows[index], units_per_kit: value };
      this.form.components = scaleComponents(rows, this.form.quantity);
    },
    replaceComponent(index, article) {
      const rows = [...this.form.components];
      rows[index] = {
        ...rows[index],
        article_id: article.id,
        key: article.key || '',
        description: article.name,
        unit: article.unit ? article.unit.name : '',
      };
      this.form.components = rows;
      this.replacing = null;
    },
    addComponent(article) {
      const quantity = Number(this.form.quantity || 0);
      this.form.components = [
        ...this.form.components,
        {
          role: 'component',
          article_id: article.id,
          key: article.key || '',
          description: article.name,
          unit: article.unit ? article.unit.name : '',
          units_per_kit: 1,
          quantity,
          replaceable: true,
          units_editable: true,
          tax_ids: [],
        },
      ];
    },
    // Solo los reemplazables; el kit se queda con al menos uno (se valida al aceptar).
    removeComponent(index) {
      if (!this.form.components[index]?.replaceable) return;
      this.form.components = this.form.components.filter((_, i) => i !== index);
      this.replacing = null;
    },
    componentExcludeIds(index) {
      return [
        this.form.article_id,
        ...this.form.components
          .filter((_, i) => i !== index)
          .map(row => row.article_id),
      ];
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
      if (this.isKit && !this.form.components.length) {
        this.error = this.$t('CRM_ZEUS.QUOTE_FORM.KIT_WITHOUT_COMPONENTS');
        return;
      }
      if (
        this.isKit &&
        this.form.components.some(row => !(Number(row.units_per_kit) > 0))
      ) {
        this.error = this.$t('CRM_ZEUS.QUOTE_FORM.COMPONENT_UNITS_REQUIRED');
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
            <span
              v-if="isKit"
              class="px-1.5 py-0.5 text-xs rounded bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300"
            >
              {{ $t('CRM_ZEUS.ARTICLES.KIT') }}
            </span>
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
            allow-kits
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
        <fieldset v-if="isKit" class="mb-3">
          <legend class="mb-1 text-sm">
            {{ $t('CRM_ZEUS.QUOTE_FORM.KIT_COMPONENTS') }}
          </legend>
          <p class="m-0 mb-2 text-xs text-slate-500">
            {{ $t('CRM_ZEUS.QUOTE_FORM.KIT_COMPONENTS_HINT') }}
          </p>
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-xs text-slate-500">
                <th class="py-1 pr-2">
                  {{ $t('CRM_ZEUS.QUOTE_FORM.COLUMNS.KEY') }}
                </th>
                <th class="py-1 pr-2">
                  {{ $t('CRM_ZEUS.QUOTE_FORM.COLUMNS.DESCRIPTION') }}
                </th>
                <th class="w-28 py-1 pr-2 text-right">
                  {{ $t('CRM_ZEUS.QUOTE_FORM.UNITS_PER_KIT') }}
                </th>
                <th class="py-1 pr-2 text-right">
                  {{ $t('CRM_ZEUS.QUOTE_FORM.COLUMNS.QUANTITY') }}
                </th>
                <th class="w-24 py-1" />
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="(row, index) in form.components"
                :key="index"
                class="align-top border-t border-slate-50 dark:border-slate-700"
              >
                <td class="py-1 pr-2 text-slate-500">{{ row.key || '—' }}</td>
                <td class="py-1 pr-2">
                  <ArticlePicker
                    v-if="replacing === index"
                    :exclude-ids="componentExcludeIds(index)"
                    :placeholder="$t('CRM_ZEUS.QUOTE_FORM.REPLACE_SEARCH')"
                    @pick="article => replaceComponent(index, article)"
                  />
                  <span v-else>{{ row.description }}</span>
                </td>
                <td class="py-1 pr-2 text-right">
                  <input
                    v-if="row.units_editable"
                    :value="row.units_per_kit"
                    type="number"
                    min="0"
                    step="any"
                    class="!mb-0 text-right"
                    @input="setUnitsPerKit(index, $event.target.value)"
                  />
                  <span v-else>{{ Number(row.units_per_kit) }}</span>
                </td>
                <td class="py-1 pr-2 text-right whitespace-nowrap">
                  {{ Number(row.quantity) }} {{ row.unit }}
                </td>
                <td class="py-1 text-right whitespace-nowrap">
                  <button
                    v-if="row.replaceable"
                    type="button"
                    class="p-0 text-xs text-woot-600 hover:underline"
                    @click="replacing = replacing === index ? null : index"
                  >
                    {{
                      replacing === index
                        ? $t('CRM_ZEUS.CANCEL')
                        : $t('CRM_ZEUS.QUOTE_FORM.REPLACE')
                    }}
                  </button>
                  <button
                    v-if="row.replaceable && replacing !== index"
                    type="button"
                    class="p-0 ml-2 text-xs text-red-600 hover:underline"
                    @click="removeComponent(index)"
                  >
                    {{ $t('CRM_ZEUS.QUOTE_FORM.REMOVE_COMPONENT') }}
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
          <ArticlePicker
            class="mt-2"
            :exclude-ids="componentExcludeIds(-1)"
            :placeholder="$t('CRM_ZEUS.QUOTE_FORM.ADD_COMPONENT_SEARCH')"
            @pick="addComponent"
          />
        </fieldset>
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
