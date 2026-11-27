<!--
  CrmZeus A2 — alta y edición de un artículo (catalogado o no catalogado), en página
  aparte con las pestañas de CRMZeus: General · Precios (precio por lista e impuestos) ·
  Otros (unidad de compra, contenido, peso, notas e imagen), y Componentes si es kit (A3).
  Al dar de alta se proponen los predeterminados (línea, unidad, impuesto y un precio en
  la lista predeterminada).
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import CrmArticles from 'dashboard/api/crmArticles';
import CrmCatalogs from 'dashboard/api/crmCatalogs';
import Spinner from 'shared/components/Spinner.vue';
import ArticlePicker from './ArticlePicker.vue';
import { crmAccess, defaultId, errorMessage } from './crmHelpers';

const TABS = ['general', 'prices', 'others', 'components'];
const FIELDS = [
  'catalog_status',
  'key',
  'name',
  'line_id',
  'unit_id',
  'status',
  'suspended_on',
  'suspension_reason',
  'is_stockable',
  'is_kit',
  'purchase_unit',
  'purchase_unit_content',
  'unit_weight',
  'notes',
];
// Rails borra un precio o componente existente con `_destroy` (accepts_nested_attributes_for).
const DESTROY = '_destroy';
const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
const IMAGE_MAX_SIZE = 5 * 1024 * 1024;

const blankArticle = () => ({
  ...Object.fromEntries(FIELDS.map(field => [field, ''])),
  catalog_status: 'uncatalogued',
  status: 'active',
  is_stockable: true,
  is_kit: false,
  purchase_unit_content: 1,
  unit_weight: 0,
  tax_ids: [],
  prices: [],
  components: [],
  image_url: null,
});

export default {
  name: 'CrmZeusArticleForm',
  components: { ArticlePicker, Spinner },
  props: {
    articleId: { type: String, default: '' },
  },
  data() {
    return {
      tab: 'general',
      article: blankArticle(),
      catalogs: {
        lookups: {},
        article_lines: [],
        units: [],
        taxes: [],
        currencies: [],
        article_statuses: [],
      },
      pendingImage: null,
      pendingImagePreview: null,
      loading: true,
      saving: false,
      uploading: false,
    };
  },
  computed: {
    ...mapGetters({ currentUser: 'getCurrentUser' }),
    isNew() {
      return !this.articleId;
    },
    // «Componentes» solo para kits.
    tabs() {
      return this.article.is_kit ? TABS : TABS.filter(t => t !== 'components');
    },
    canEdit() {
      return crmAccess(this.currentUser, this.$route.params.accountId).canEdit;
    },
    priceLists() {
      return this.catalogs.lookups.price_list || [];
    },
    visiblePrices() {
      return this.article.prices.filter(price => !price[DESTROY]);
    },
    visibleComponents() {
      return this.article.components.filter(row => !row[DESTROY]);
    },
    // Ni el propio kit ni los que ya lleva.
    componentExcludeIds() {
      return [
        this.article.id,
        ...this.visibleComponents.map(row => row.component_id),
      ].filter(Boolean);
    },
    isSuspended() {
      return this.article.status && this.article.status !== 'active';
    },
    // «Baja» pide fecha y motivo de baja; las suspensiones, de suspensión.
    suspensionLabels() {
      const kind =
        this.article.status === 'inactive' ? 'INACTIVE' : 'SUSPENDED';
      return {
        date: this.$t(`CRM_ZEUS.SUSPENSION.${kind}_ON`),
        reason: this.$t(`CRM_ZEUS.SUSPENSION.${kind}_REASON`),
      };
    },
    usedPriceLists() {
      return this.visiblePrices.map(price => price.price_list_id);
    },
    // Un precio por lista (como Microsip): para otro precio hace falta otra lista.
    allListsUsed() {
      return this.usedPriceLists.length >= this.priceLists.length;
    },
    imageSrc() {
      return this.pendingImagePreview || this.article.image_url;
    },
    title() {
      return this.isNew
        ? this.$t('CRM_ZEUS.ARTICLE_FORM.NEW_TITLE')
        : this.article.name || this.$t('CRM_ZEUS.ARTICLE_FORM.EDIT_TITLE');
    },
  },
  watch: {
    articleId() {
      this.load();
    },
  },
  mounted() {
    this.load();
  },
  beforeDestroy() {
    if (this.pendingImagePreview) URL.revokeObjectURL(this.pendingImagePreview);
  },
  methods: {
    async load() {
      this.loading = true;
      try {
        const { data } = await CrmCatalogs.fetch();
        this.catalogs = data;
        if (this.isNew) {
          this.article = this.withDefaults(blankArticle());
        } else {
          const response = await CrmArticles.show(this.articleId);
          this.article = this.fromApi(response.data.article);
        }
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      } finally {
        this.loading = false;
      }
    },
    withDefaults(article) {
      const type = this.$route.query.type;
      const defaultList = defaultId(this.priceLists);
      const defaultTax = defaultId(this.catalogs.taxes);
      return {
        ...article,
        catalog_status: type === 'catalogued' ? 'catalogued' : 'uncatalogued',
        line_id: defaultId(this.catalogs.article_lines) || '',
        unit_id: defaultId(this.catalogs.units) || '',
        tax_ids: defaultTax ? [defaultTax] : [],
        prices: defaultList
          ? [
              {
                price_list_id: defaultList,
                price: 0,
                currency_id: defaultId(this.catalogs.currencies),
              },
            ]
          : [],
      };
    },
    fromApi(data) {
      const result = { ...blankArticle() };
      FIELDS.forEach(field => {
        const value = data[field];
        result[field] = value === null || value === undefined ? '' : value;
      });
      result.id = data.id;
      result.tax_ids = [...data.tax_ids];
      result.prices = data.prices.map(price => ({
        id: price.id,
        price_list_id: price.price_list_id,
        price: price.price,
        currency_id: price.currency_id,
      }));
      result.components = data.components.map(row => ({ ...row }));
      result.image_url = data.image_url;
      return result;
    },
    payload() {
      const article = {};
      FIELDS.forEach(field => {
        const value = this.article[field];
        article[field] = value === '' ? null : value;
      });
      if (!this.isSuspended) {
        article.suspended_on = null;
        article.suspension_reason = null;
      }
      article.tax_ids = this.article.tax_ids;
      article.prices_attributes = this.article.prices.map(price => ({
        ...price,
        currency_id: price.currency_id || null,
      }));
      article.components_attributes = this.componentsPayload();
      return { article };
    },
    // El orden de la tabla queda en `position`; los quitados van con `_destroy`.
    componentsPayload() {
      const fields = row => ({
        id: row.id,
        component_id: row.component_id,
        quantity: row.quantity,
        replaceable: row.replaceable,
        units_editable: row.units_editable,
      });
      const kept = this.visibleComponents.map((row, index) => ({
        ...fields(row),
        position: index,
      }));
      const removed = this.article.components
        .filter(row => row[DESTROY])
        .map(row => ({ id: row.id, [DESTROY]: true }));
      return [...kept, ...removed];
    },
    addPrice() {
      const free = this.priceLists.find(
        list => !this.usedPriceLists.includes(list.id)
      );
      this.article.prices.push({
        price_list_id: free ? free.id : '',
        price: 0,
        currency_id: defaultId(this.catalogs.currencies),
      });
    },
    removePrice(price) {
      if (price.id) this.$set(price, DESTROY, true);
      else this.article.prices.splice(this.article.prices.indexOf(price), 1);
    },
    addComponent(item) {
      this.article.components.push({
        component_id: item.id,
        key: item.key,
        name: item.name,
        catalog_status: item.catalog_status,
        unit: item.unit ? item.unit.name : null,
        quantity: 1,
        replaceable: false,
        units_editable: false,
      });
    },
    removeComponent(row) {
      if (row.id) this.$set(row, DESTROY, true);
      else
        this.article.components.splice(this.article.components.indexOf(row), 1);
    },
    // Al desmarcar «Juego (kit)» con componentes se confirma; al guardar se borran.
    async onKitChange(event) {
      const checked = event.target.checked;
      if (!checked && this.visibleComponents.length) {
        event.target.checked = true;
        if (!(await this.$refs.unkitDialog.showConfirmation())) return;
        [...this.visibleComponents].forEach(this.removeComponent);
      }
      this.article.is_kit = checked;
      if (!checked && this.tab === 'components') this.tab = 'general';
    },
    toggleTax(taxId, checked) {
      const ids = this.article.tax_ids.filter(id => id !== taxId);
      this.article.tax_ids = checked ? [...ids, taxId] : ids;
    },
    async save() {
      if (!this.article.name.trim()) {
        this.tab = 'general';
        useAlert(this.$t('CRM_ZEUS.ARTICLE_FORM.REQUIRED'));
        return;
      }
      this.saving = true;
      try {
        if (this.isNew) {
          const { data } = await CrmArticles.create(this.payload());
          if (this.pendingImage) {
            await this.uploadTo(data.article.id, this.pendingImage);
            URL.revokeObjectURL(this.pendingImagePreview);
            this.pendingImage = null;
            this.pendingImagePreview = null;
          }
          useAlert(this.$t('CRM_ZEUS.ARTICLE_FORM.CREATED'));
          this.$router.replace({
            name: 'crmzeus_article_edit',
            params: { articleId: data.article.id },
          });
        } else {
          const { data } = await CrmArticles.update(
            this.articleId,
            this.payload()
          );
          this.article = this.fromApi(data.article);
          useAlert(this.$t('CRM_ZEUS.ARTICLE_FORM.SAVED'));
        }
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      } finally {
        this.saving = false;
      }
    },
    // Imagen: en uno ya guardado se sube al momento; en uno nuevo, al guardarlo.
    async onImageSelected(event) {
      const [file] = event.target.files;
      event.target.value = '';
      if (!file) return;
      if (!IMAGE_TYPES.includes(file.type) || file.size > IMAGE_MAX_SIZE) {
        useAlert(this.$t('CRM_ZEUS.ARTICLE_FORM.IMAGE_INVALID'));
        return;
      }
      if (this.isNew) {
        if (this.pendingImagePreview) {
          URL.revokeObjectURL(this.pendingImagePreview);
        }
        this.pendingImage = file;
        this.pendingImagePreview = URL.createObjectURL(file);
        return;
      }
      try {
        await this.uploadTo(this.articleId, file);
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      }
    },
    async uploadTo(id, file) {
      this.uploading = true;
      try {
        const { data } = await CrmArticles.uploadImage(id, file);
        this.article.image_url = data.article.image_url;
      } finally {
        this.uploading = false;
      }
    },
    async removeImage() {
      if (this.isNew) {
        URL.revokeObjectURL(this.pendingImagePreview);
        this.pendingImage = null;
        this.pendingImagePreview = null;
        return;
      }
      try {
        const { data } = await CrmArticles.deleteImage(this.articleId);
        this.article.image_url = data.article.image_url;
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      }
    },
    async catalog() {
      if (!(await this.$refs.catalogDialog.showConfirmation())) return;
      try {
        const { data } = await CrmArticles.catalog(this.articleId);
        this.article = this.fromApi(data.article);
        useAlert(this.$t('CRM_ZEUS.ARTICLE_FORM.CATALOGED'));
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      }
    },
    async remove() {
      if (!(await this.$refs.deleteDialog.showConfirmation())) return;
      try {
        await CrmArticles.delete(this.articleId);
        useAlert(this.$t('CRM_ZEUS.ARTICLE_FORM.DELETED'));
        this.back();
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      }
    },
    back() {
      this.$router.push({ name: 'crmzeus_articles' });
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
      <div class="flex items-start gap-3">
        <img
          v-if="imageSrc"
          :src="imageSrc"
          :alt="article.name"
          class="object-cover w-12 h-12 mt-5 rounded-md"
        />
        <div>
          <button
            type="button"
            class="p-0 mb-1 text-sm text-woot-600 hover:underline"
            @click="back"
          >
            {{ $t('CRM_ZEUS.ARTICLE_FORM.BACK') }}
          </button>
          <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
            {{ title }}
            <span
              v-if="!isNew && !loading"
              class="ml-2 px-2 py-0.5 text-xs font-medium rounded-full align-middle"
              :class="
                article.catalog_status === 'catalogued'
                  ? 'bg-green-50 text-green-800'
                  : 'bg-amber-50 text-amber-800'
              "
            >
              {{
                $t(
                  `CRM_ZEUS.CATALOG_STATUS.${article.catalog_status.toUpperCase()}`
                )
              }}
            </span>
          </h1>
          <p v-if="!isNew && article.key" class="m-0 text-sm text-slate-500">
            {{ article.key }}
          </p>
        </div>
      </div>
      <div v-if="canEdit && !loading" class="flex flex-wrap gap-2">
        <woot-button
          v-if="!isNew && article.catalog_status === 'uncatalogued'"
          size="small"
          variant="smooth"
          color-scheme="success"
          icon="checkmark"
          @click="catalog"
        >
          {{ $t('CRM_ZEUS.ARTICLE_FORM.CATALOG') }}
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
          {{ $t(`CRM_ZEUS.ARTICLE_FORM.TABS.${t.toUpperCase()}`) }}
        </button>
      </nav>

      <form class="flex-1 px-6 py-4 overflow-auto" @submit.prevent="save">
        <fieldset :disabled="!canEdit" class="max-w-4xl">
          <!-- General -->
          <div v-show="tab === 'general'" class="flex flex-col gap-1">
            <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-[1fr_2fr]">
              <label>
                {{ $t('CRM_ZEUS.ARTICLE_FIELDS.KEY') }}
                <input v-model="article.key" type="text" maxlength="20" />
              </label>
              <label v-if="isNew">
                {{ $t('CRM_ZEUS.ARTICLE_FIELDS.CATALOG_STATUS') }}
                <select v-model="article.catalog_status">
                  <option value="uncatalogued">
                    {{ $t('CRM_ZEUS.CATALOG_STATUS.UNCATALOGUED') }}
                  </option>
                  <option value="catalogued">
                    {{ $t('CRM_ZEUS.CATALOG_STATUS.CATALOGUED') }}
                  </option>
                </select>
              </label>
            </div>
            <label>
              {{ $t('CRM_ZEUS.ARTICLE_FIELDS.NAME') }} *
              <input
                v-model="article.name"
                type="text"
                maxlength="200"
                required
              />
            </label>
            <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-3">
              <label>
                {{ $t('CRM_ZEUS.ARTICLE_FIELDS.LINE') }}
                <select v-model="article.line_id">
                  <option value="">—</option>
                  <option
                    v-for="line in catalogs.article_lines"
                    :key="line.id"
                    :value="line.id"
                  >
                    {{ line.name }}
                  </option>
                </select>
              </label>
              <label>
                {{ $t('CRM_ZEUS.ARTICLE_FIELDS.UNIT') }}
                <select v-model="article.unit_id">
                  <option value="">—</option>
                  <option
                    v-for="unit in catalogs.units"
                    :key="unit.id"
                    :value="unit.id"
                  >
                    {{
                      unit.sat_key
                        ? `${unit.name} (${unit.sat_key})`
                        : unit.name
                    }}
                  </option>
                </select>
              </label>
              <label>
                {{ $t('CRM_ZEUS.ARTICLE_FIELDS.STATUS') }}
                <select v-model="article.status">
                  <option
                    v-for="status in catalogs.article_statuses"
                    :key="status"
                    :value="status"
                  >
                    {{ $t(`CRM_ZEUS.ARTICLE_STATUS.${status.toUpperCase()}`) }}
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
                <input v-model="article.suspended_on" type="date" />
              </label>
              <label>
                {{ suspensionLabels.reason }}
                <input
                  v-model="article.suspension_reason"
                  type="text"
                  maxlength="250"
                />
              </label>
            </div>
            <div class="flex flex-wrap gap-6">
              <label class="flex items-center gap-2">
                <input
                  v-model="article.is_stockable"
                  type="checkbox"
                  class="!m-0"
                />
                {{ $t('CRM_ZEUS.ARTICLE_FIELDS.IS_STOCKABLE') }}
              </label>
              <label class="flex items-center gap-2">
                <input
                  :checked="article.is_kit"
                  type="checkbox"
                  class="!m-0"
                  @change="onKitChange"
                />
                {{ $t('CRM_ZEUS.ARTICLE_FIELDS.IS_KIT') }}
              </label>
            </div>
          </div>

          <!-- Precios e impuestos -->
          <div v-show="tab === 'prices'" class="flex flex-col gap-4">
            <section>
              <p
                class="mt-0 mb-2 text-sm font-medium text-slate-800 dark:text-slate-100"
              >
                {{ $t('CRM_ZEUS.ARTICLE_FORM.PRICES') }}
              </p>
              <p v-if="!visiblePrices.length" class="text-sm text-slate-500">
                {{ $t('CRM_ZEUS.ARTICLE_FORM.NO_PRICES') }}
              </p>
              <div
                v-for="(price, index) in visiblePrices"
                :key="price.id || `new-${index}`"
                class="grid items-center grid-cols-[2fr_1fr_1fr_auto] gap-2 mb-2"
              >
                <select v-model="price.price_list_id" class="!mb-0" required>
                  <option
                    v-for="list in priceLists"
                    :key="list.id"
                    :value="list.id"
                    :disabled="
                      list.id !== price.price_list_id &&
                      usedPriceLists.includes(list.id)
                    "
                  >
                    {{ list.name }}
                  </option>
                </select>
                <input
                  v-model.number="price.price"
                  type="number"
                  min="0"
                  step="0.000001"
                  class="!mb-0 text-right"
                />
                <select v-model="price.currency_id" class="!mb-0">
                  <option
                    v-for="currency in catalogs.currencies"
                    :key="currency.id"
                    :value="currency.id"
                  >
                    {{ currency.iso_code || currency.name }}
                  </option>
                </select>
                <woot-button
                  type="button"
                  size="tiny"
                  variant="clear"
                  color-scheme="alert"
                  icon="dismiss"
                  :title="$t('CRM_ZEUS.DELETE')"
                  @click="removePrice(price)"
                />
              </div>
              <div class="flex flex-wrap items-center gap-3">
                <woot-button
                  type="button"
                  size="small"
                  variant="smooth"
                  color-scheme="secondary"
                  icon="add"
                  :disabled="allListsUsed"
                  @click="addPrice"
                >
                  {{ $t('CRM_ZEUS.ARTICLE_FORM.ADD_PRICE') }}
                </woot-button>
                <span
                  v-if="allListsUsed"
                  class="text-xs text-slate-500 dark:text-slate-400"
                >
                  {{ $t('CRM_ZEUS.ARTICLE_FORM.ALL_LISTS_USED') }}
                  <router-link
                    :to="{ name: 'crmzeus_catalogs' }"
                    class="text-woot-600 hover:underline"
                  >
                    {{ $t('CRM_ZEUS.ARTICLE_FORM.GO_TO_CATALOGS') }}
                  </router-link>
                </span>
              </div>
            </section>
            <section>
              <p
                class="mt-0 mb-2 text-sm font-medium text-slate-800 dark:text-slate-100"
              >
                {{ $t('CRM_ZEUS.ARTICLE_FORM.TAXES') }}
              </p>
              <div class="grid grid-cols-1 gap-1 sm:grid-cols-2">
                <label
                  v-for="tax in catalogs.taxes"
                  :key="tax.id"
                  class="flex items-center gap-2"
                >
                  <input
                    type="checkbox"
                    class="!m-0"
                    :checked="article.tax_ids.includes(tax.id)"
                    @change="toggleTax(tax.id, $event.target.checked)"
                  />
                  {{ tax.name }}
                  <span class="text-xs text-slate-500">
                    {{ $t(`CRM_ZEUS.TAX_TYPE.${tax.tax_type.toUpperCase()}`) }}
                  </span>
                </label>
              </div>
            </section>
          </div>

          <!-- Otros -->
          <div v-show="tab === 'others'" class="flex flex-col gap-1">
            <div class="grid grid-cols-1 gap-x-4 sm:grid-cols-3">
              <label>
                {{ $t('CRM_ZEUS.ARTICLE_FIELDS.PURCHASE_UNIT') }}
                <input
                  v-model="article.purchase_unit"
                  type="text"
                  maxlength="20"
                />
              </label>
              <label>
                {{ $t('CRM_ZEUS.ARTICLE_FIELDS.PURCHASE_UNIT_CONTENT') }}
                <input
                  v-model.number="article.purchase_unit_content"
                  type="number"
                  min="0.00001"
                  step="0.00001"
                />
              </label>
              <label>
                {{ $t('CRM_ZEUS.ARTICLE_FIELDS.UNIT_WEIGHT') }}
                <input
                  v-model.number="article.unit_weight"
                  type="number"
                  min="0"
                  step="0.00001"
                />
              </label>
            </div>
            <label>
              {{ $t('CRM_ZEUS.ARTICLE_FIELDS.NOTES') }}
              <textarea v-model="article.notes" rows="4" />
            </label>
            <div class="mt-2">
              <span
                class="block mb-1 text-sm text-slate-800 dark:text-slate-100"
              >
                {{ $t('CRM_ZEUS.ARTICLE_FIELDS.IMAGE') }}
              </span>
              <div class="flex items-center gap-3">
                <img
                  v-if="imageSrc"
                  :src="imageSrc"
                  :alt="article.name"
                  class="object-cover w-24 h-24 border rounded-md border-slate-100"
                />
                <label class="button small secondary !mb-0 cursor-pointer">
                  {{
                    imageSrc
                      ? $t('CRM_ZEUS.ARTICLE_FORM.CHANGE_IMAGE')
                      : $t('CRM_ZEUS.ARTICLE_FORM.ADD_IMAGE')
                  }}
                  <input
                    type="file"
                    accept="image/jpeg,image/png,image/webp,image/gif"
                    class="hidden"
                    @change="onImageSelected"
                  />
                </label>
                <woot-button
                  v-if="imageSrc"
                  type="button"
                  size="small"
                  variant="clear"
                  color-scheme="alert"
                  icon="delete"
                  :is-loading="uploading"
                  @click="removeImage"
                >
                  {{ $t('CRM_ZEUS.ARTICLE_FORM.REMOVE_IMAGE') }}
                </woot-button>
              </div>
              <p class="mt-1 text-xs text-slate-500">
                {{ $t('CRM_ZEUS.ARTICLE_FORM.IMAGE_HINT') }}
              </p>
            </div>
          </div>

          <!-- Componentes del kit -->
          <div v-show="tab === 'components'" class="flex flex-col gap-3">
            <p class="m-0 text-sm text-slate-500 dark:text-slate-400">
              {{ $t('CRM_ZEUS.ARTICLE_FORM.COMPONENTS_HINT') }}
            </p>
            <p
              v-if="!visibleComponents.length"
              class="m-0 text-sm text-slate-500"
            >
              {{ $t('CRM_ZEUS.ARTICLE_FORM.NO_COMPONENTS') }}
            </p>
            <table v-else class="w-full text-sm">
              <thead>
                <tr class="text-left text-slate-500">
                  <th class="px-2 py-1 font-medium">
                    {{ $t('CRM_ZEUS.ARTICLES.COLUMNS.KEY') }}
                  </th>
                  <th class="px-2 py-1 font-medium">
                    {{ $t('CRM_ZEUS.ARTICLES.COLUMNS.NAME') }}
                  </th>
                  <th class="px-2 py-1 font-medium">
                    {{ $t('CRM_ZEUS.ARTICLES.COLUMNS.UNIT') }}
                  </th>
                  <th class="px-2 py-1 font-medium text-right">
                    {{ $t('CRM_ZEUS.ARTICLE_FORM.COMPONENT_QUANTITY') }}
                  </th>
                  <th class="px-2 py-1 font-medium text-center">
                    {{ $t('CRM_ZEUS.ARTICLE_FORM.COMPONENT_REPLACEABLE') }}
                  </th>
                  <th class="px-2 py-1 font-medium text-center">
                    {{ $t('CRM_ZEUS.ARTICLE_FORM.COMPONENT_UNITS_EDITABLE') }}
                  </th>
                  <th />
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="(row, index) in visibleComponents"
                  :key="row.id || `new-${row.component_id}-${index}`"
                  class="border-t border-slate-50 dark:border-slate-700"
                >
                  <td class="px-2 py-1 text-slate-500">{{ row.key || '—' }}</td>
                  <td class="px-2 py-1 text-slate-800 dark:text-slate-100">
                    {{ row.name }}
                  </td>
                  <td class="px-2 py-1">{{ row.unit || '—' }}</td>
                  <td class="w-32 px-2 py-1">
                    <input
                      v-model.number="row.quantity"
                      type="number"
                      min="0.00001"
                      step="0.00001"
                      required
                      class="!mb-0 text-right"
                    />
                  </td>
                  <td class="px-2 py-1 text-center">
                    <input
                      v-model="row.replaceable"
                      type="checkbox"
                      class="!m-0"
                    />
                  </td>
                  <td class="px-2 py-1 text-center">
                    <input
                      v-model="row.units_editable"
                      type="checkbox"
                      class="!m-0"
                    />
                  </td>
                  <td class="px-2 py-1 text-right">
                    <woot-button
                      type="button"
                      size="tiny"
                      variant="clear"
                      color-scheme="alert"
                      icon="dismiss"
                      :title="$t('CRM_ZEUS.DELETE')"
                      @click="removeComponent(row)"
                    />
                  </td>
                </tr>
              </tbody>
            </table>
            <ArticlePicker
              v-if="canEdit"
              class="max-w-md"
              :exclude-ids="componentExcludeIds"
              @pick="addComponent"
            />
          </div>
        </fieldset>
      </form>
    </template>

    <woot-confirm-modal
      ref="catalogDialog"
      :title="$t('CRM_ZEUS.ARTICLE_FORM.CATALOG')"
      :description="
        $t('CRM_ZEUS.ARTICLE_FORM.CONFIRM_CATALOG', { name: article.name })
      "
      :confirm-label="$t('CRM_ZEUS.ARTICLE_FORM.CATALOG')"
      :cancel-label="$t('CRM_ZEUS.CANCEL')"
    />
    <woot-confirm-modal
      ref="unkitDialog"
      :title="$t('CRM_ZEUS.ARTICLE_FORM.UNKIT_TITLE')"
      :description="
        $t('CRM_ZEUS.ARTICLE_FORM.CONFIRM_UNKIT', {
          count: visibleComponents.length,
        })
      "
      :confirm-label="$t('CRM_ZEUS.ARTICLE_FORM.UNKIT_CONFIRM')"
      :cancel-label="$t('CRM_ZEUS.CANCEL')"
    />
    <woot-confirm-modal
      ref="deleteDialog"
      :title="$t('CRM_ZEUS.ARTICLE_FORM.DELETE_TITLE')"
      :description="
        $t('CRM_ZEUS.ARTICLE_FORM.CONFIRM_DELETE', { name: article.name })
      "
      :confirm-label="$t('CRM_ZEUS.DELETE')"
      :cancel-label="$t('CRM_ZEUS.CANCEL')"
    />
  </div>
</template>
