<!--
  Cotizaciones › Formatos — el diseñador: a la izquierda el formato (marca, bloques prendidos y en orden, sus
  opciones y textos) y los datos de la empresa (una sola vez para todos); a la derecha la vista previa en vivo
  con una cotización real o de ejemplo (la misma vista que la liga del cliente y el PDF: Quotes::Document).
  Varios formatos; uno es el de por omisión. Lo cambia quien edita el catálogo; los demás solo lo ven.
-->
<script>
import { useAlert } from 'dashboard/composables';
import QuoteFormatsAPI from 'dashboard/api/quoteFormats';
import Spinner from 'shared/components/Spinner.vue';

const clone = value => JSON.parse(JSON.stringify(value || {}));
const COMPANY_FIELDS = [
  'legal_name',
  'tax_id',
  'address',
  'phone',
  'email',
  'website',
];
const CLIENT_FIELDS = ['name', 'organization', 'tax_id', 'email', 'phone'];
const ITEM_COLUMNS = ['sku', 'image', 'unit', 'discount', 'tax'];
const TEXT_BLOCKS = ['intro', 'terms', 'bank', 'footer'];

export default {
  name: 'QuoteFormats',
  components: { Spinner },
  data() {
    return {
      loading: true,
      saving: false,
      data: null,
      selectedId: null,
      name: '',
      isDefault: false,
      settings: null,
      company: {},
      companyDirty: false,
      dirty: false,
      openBlock: null,
      previewHtml: '',
      previewLoading: false,
      timer: null,
      companyFields: COMPANY_FIELDS,
      clientFields: CLIENT_FIELDS,
      itemColumns: ITEM_COLUMNS,
      textBlocks: TEXT_BLOCKS,
    };
  },
  computed: {
    canEdit() {
      return !!(this.data && this.data.can_edit);
    },
    formats() {
      return (this.data && this.data.formats) || [];
    },
    selected() {
      return this.formats.find(f => f.id === this.selectedId) || null;
    },
    fonts() {
      return (this.data && this.data.fonts) || [];
    },
    variables() {
      return ((this.data && this.data.variables) || [])
        .map(v => `{{${v}}}`)
        .join(' ');
    },
    blocks() {
      return (this.settings && this.settings.blocks) || [];
    },
  },
  mounted() {
    this.load();
  },
  beforeDestroy() {
    clearTimeout(this.timer);
  },
  methods: {
    t(key, values) {
      return this.$t(`QUOTE_FORMATS.${key}`, values);
    },
    async load(keepId = null) {
      this.loading = !this.data;
      try {
        const { data } = await QuoteFormatsAPI.list();
        this.apply(data, keepId);
      } catch {
        useAlert(this.t('ERROR'));
      } finally {
        this.loading = false;
      }
    },
    apply(data, keepId = null) {
      this.data = data;
      this.company = clone(data.company);
      this.companyDirty = false;
      const id =
        keepId ||
        this.selectedId ||
        (data.formats.find(f => f.is_default) || data.formats[0] || {}).id;
      this.select(data.formats.find(f => f.id === id) || data.formats[0]);
    },
    select(format) {
      if (!format) return;
      this.selectedId = format.id;
      this.name = format.name;
      this.isDefault = format.is_default;
      this.settings = clone(format.settings);
      this.dirty = false;
      this.refreshPreview(0);
    },
    pick(id) {
      // eslint-disable-next-line no-alert
      if (this.dirty && !window.confirm(this.t('DISCARD'))) return;
      this.select(this.formats.find(f => f.id === Number(id)));
    },
    touch() {
      this.dirty = true;
      this.refreshPreview();
    },
    refreshPreview(delay = 500) {
      clearTimeout(this.timer);
      this.timer = setTimeout(this.preview, delay);
    },
    async preview() {
      if (!this.settings) return;
      this.previewLoading = true;
      try {
        const { data } = await QuoteFormatsAPI.preview(
          this.settings,
          this.selectedId
        );
        this.previewHtml = data.html;
      } catch {
        // la vista previa se queda como estaba
      } finally {
        this.previewLoading = false;
      }
    },
    async request(call, message = 'SAVED') {
      this.saving = true;
      try {
        const { data } = await call();
        useAlert(this.t(message));
        return data;
      } catch (error) {
        const list = error?.response?.data?.error;
        useAlert(Array.isArray(list) ? list.join(', ') : this.t('ERROR'));
        return null;
      } finally {
        this.saving = false;
      }
    },
    async save() {
      const data = await this.request(() =>
        QuoteFormatsAPI.save(
          {
            name: this.name,
            is_default: this.isDefault,
            settings: this.settings,
          },
          this.selectedId
        )
      );
      if (data) this.apply(data, this.selectedId);
    },
    async create() {
      const name = this.t('NEW_NAME', { n: this.formats.length + 1 });
      const data = await this.request(() =>
        QuoteFormatsAPI.save({ name, settings: this.data.defaults })
      );
      if (!data) return;
      const created = data.formats.reduce((a, b) => (a.id > b.id ? a : b));
      this.apply(data, created.id);
    },
    async duplicate() {
      const data = await this.request(() =>
        QuoteFormatsAPI.duplicate(this.selectedId)
      );
      if (!data) return;
      const created = data.formats.reduce((a, b) => (a.id > b.id ? a : b));
      this.apply(data, created.id);
    },
    async remove() {
      // eslint-disable-next-line no-alert
      if (!window.confirm(this.t('DELETE_CONFIRM', { name: this.name }))) {
        return;
      }
      const data = await this.request(
        () => QuoteFormatsAPI.remove(this.selectedId),
        'DELETED'
      );
      if (data) {
        this.selectedId = null;
        this.apply(data);
      }
    },
    async saveCompany() {
      const data = await this.request(() =>
        QuoteFormatsAPI.saveCompany(this.company)
      );
      if (data) {
        this.apply(data, this.selectedId);
      }
    },
    async upload(event, target) {
      const [file] = event.target.files || [];
      event.target.value = '';
      if (!file) return;
      const data = await this.request(() =>
        target === 'company'
          ? QuoteFormatsAPI.uploadCompanyLogo(file)
          : QuoteFormatsAPI.uploadLogo(this.selectedId, file)
      );
      if (data) this.apply(data, this.selectedId);
    },
    async dropLogo(target) {
      const data = await this.request(() =>
        target === 'company'
          ? QuoteFormatsAPI.removeCompanyLogo()
          : QuoteFormatsAPI.removeLogo(this.selectedId)
      );
      if (data) this.apply(data, this.selectedId);
    },
    move(index, step) {
      const list = [...this.blocks];
      const to = index + step;
      if (to < 0 || to >= list.length) return;
      [list[index], list[to]] = [list[to], list[index]];
      this.settings.blocks = list;
      this.touch();
    },
    toggleBlock(block) {
      block.on = !block.on;
      this.touch();
    },
    // Casillas de una lista (campos de la empresa, del cliente, columnas).
    has(path, key) {
      return (this.settings[path[0]][path[1]] || []).includes(key);
    },
    toggleIn(path, key) {
      const [section, field] = path;
      const list = this.settings[section][field] || [];
      this.$set(
        this.settings[section],
        field,
        list.includes(key) ? list.filter(k => k !== key) : [...list, key]
      );
      this.touch();
    },
    setOption(section, key, value) {
      this.$set(this.settings[section], key, value);
      this.touch();
    },
    setCompanyOverride(key, value) {
      const company = { ...(this.settings.header.company || {}) };
      if (value) company[key] = value;
      else delete company[key];
      this.$set(this.settings.header, 'company', company);
      this.touch();
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-white dark:bg-slate-900"
  >
    <header
      class="flex flex-wrap items-center justify-between gap-3 px-6 pt-5 pb-3 border-b border-slate-50 dark:border-slate-800"
    >
      <div>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ t('TITLE') }}
        </h1>
        <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
          {{ t('DESCRIPTION') }}
        </p>
      </div>
      <div v-if="data" class="flex flex-wrap items-center gap-2">
        <select
          :value="selectedId"
          class="!mb-0 w-80"
          @change="pick($event.target.value)"
        >
          <option v-for="f in formats" :key="f.id" :value="f.id">
            {{ f.name }}{{ f.is_default ? ` · ${t('DEFAULT')}` : '' }}
          </option>
        </select>
        <template v-if="canEdit">
          <woot-button
            size="small"
            variant="smooth"
            icon="add"
            :disabled="saving"
            @click="create"
          >
            {{ t('NEW') }}
          </woot-button>
          <woot-button
            size="small"
            variant="smooth"
            color-scheme="secondary"
            icon="copy"
            :disabled="saving"
            @click="duplicate"
          >
            {{ t('DUPLICATE') }}
          </woot-button>
          <woot-button
            v-if="formats.length > 1"
            size="small"
            variant="clear"
            color-scheme="alert"
            icon="delete"
            :disabled="saving"
            @click="remove"
          />
        </template>
      </div>
    </header>

    <Spinner v-if="loading" class="mt-8" />

    <div
      v-else-if="settings"
      class="grid flex-1 min-h-0 grid-cols-1 lg:grid-cols-[minmax(22rem,28rem)_1fr]"
    >
      <!-- El formato -->
      <div
        class="flex flex-col min-h-0 overflow-y-auto border-r border-slate-50 dark:border-slate-800"
      >
        <div class="flex flex-col gap-3 p-4">
          <fieldset :disabled="!canEdit" class="flex flex-col gap-3">
            <section class="fmt-box">
              <label class="block">
                <span class="fmt-label">{{ t('NAME') }}</span>
                <input
                  v-model="name"
                  type="text"
                  maxlength="80"
                  class="!mb-0"
                  @input="dirty = true"
                />
              </label>
              <label class="flex items-center gap-2 text-sm">
                <input
                  v-model="isDefault"
                  type="checkbox"
                  class="m-0"
                  @change="dirty = true"
                />
                {{ t('IS_DEFAULT') }}
              </label>
              <p v-if="selected && selected.quotes" class="fmt-hint">
                {{ t('USED_BY', { count: selected.quotes }) }}
              </p>
            </section>

            <!-- Marca -->
            <section class="fmt-box">
              <h2 class="fmt-title">{{ t('BRAND.TITLE') }}</h2>
              <div class="grid grid-cols-2 gap-2">
                <label class="block">
                  <span class="fmt-label">{{ t('BRAND.COLOR') }}</span>
                  <input
                    :value="settings.brand.color"
                    type="color"
                    class="!mb-0 !h-9 !p-1"
                    @input="setOption('brand', 'color', $event.target.value)"
                  />
                </label>
                <label class="block">
                  <span class="fmt-label">{{ t('BRAND.FONT') }}</span>
                  <select
                    :value="settings.brand.font"
                    class="!mb-0"
                    @change="setOption('brand', 'font', $event.target.value)"
                  >
                    <option v-for="font in fonts" :key="font" :value="font">
                      {{ font }}
                    </option>
                  </select>
                </label>
                <label class="block">
                  <span class="fmt-label">{{ t('BRAND.PAPER') }}</span>
                  <select
                    :value="settings.brand.paper"
                    class="!mb-0"
                    @change="setOption('brand', 'paper', $event.target.value)"
                  >
                    <option value="letter">{{ t('BRAND.LETTER') }}</option>
                    <option value="a4">{{ t('BRAND.A4') }}</option>
                  </select>
                </label>
                <label class="block">
                  <span class="fmt-label">{{ t('BRAND.LOGO_POSITION') }}</span>
                  <select
                    :value="settings.brand.logo_position"
                    class="!mb-0"
                    @change="
                      setOption('brand', 'logo_position', $event.target.value)
                    "
                  >
                    <option
                      v-for="key in ['left', 'center', 'right']"
                      :key="key"
                      :value="key"
                    >
                      {{ t(`BRAND.POSITIONS.${key}`) }}
                    </option>
                  </select>
                </label>
                <label class="block">
                  <span class="fmt-label">{{ t('BRAND.LOGO_SIZE') }}</span>
                  <select
                    :value="settings.brand.logo_size"
                    class="!mb-0"
                    @change="
                      setOption('brand', 'logo_size', $event.target.value)
                    "
                  >
                    <option
                      v-for="key in ['small', 'medium', 'large']"
                      :key="key"
                      :value="key"
                    >
                      {{ t(`BRAND.SIZES.${key}`) }}
                    </option>
                  </select>
                </label>
              </div>
              <div class="flex flex-col gap-1">
                <span class="fmt-label">{{ t('BRAND.FORMAT_LOGO') }}</span>
                <div class="flex items-center gap-2">
                  <img
                    v-if="selected && selected.logo_url"
                    :src="selected.logo_url"
                    alt=""
                    class="object-contain h-10 border rounded border-slate-100"
                  />
                  <label
                    class="mb-0 cursor-pointer button smooth secondary tiny"
                  >
                    {{ t('UPLOAD') }}
                    <input
                      type="file"
                      accept="image/png,image/jpeg,image/webp"
                      class="hidden"
                      @change="upload($event, 'format')"
                    />
                  </label>
                  <button
                    v-if="selected && selected.logo_url"
                    type="button"
                    class="text-xs text-red-600 hover:underline"
                    @click="dropLogo('format')"
                  >
                    {{ t('REMOVE') }}
                  </button>
                </div>
                <span class="fmt-hint">{{ t('BRAND.FORMAT_LOGO_HINT') }}</span>
              </div>
            </section>

            <!-- Bloques -->
            <section class="fmt-box">
              <h2 class="fmt-title">{{ t('BLOCKS.TITLE') }}</h2>
              <p class="fmt-hint">{{ t('BLOCKS.HINT') }}</p>
              <div
                v-for="(block, index) in blocks"
                :key="block.key"
                class="border rounded-md border-slate-100 dark:border-slate-700"
              >
                <div class="flex items-center gap-2 px-2 py-1.5">
                  <input
                    type="checkbox"
                    class="m-0"
                    :checked="block.on"
                    @change="toggleBlock(block)"
                  />
                  <button
                    type="button"
                    class="flex-1 text-sm font-medium text-left"
                    :class="block.on ? '' : 'text-slate-400'"
                    @click="
                      openBlock = openBlock === block.key ? null : block.key
                    "
                  >
                    {{ t(`BLOCKS.${block.key}.TITLE`) }}
                    <span class="ml-1 text-xs font-normal text-woot-600">
                      {{ openBlock === block.key ? t('CLOSE') : t('OPTIONS') }}
                    </span>
                  </button>
                  <woot-button
                    v-tooltip="t('UP')"
                    size="tiny"
                    variant="clear"
                    color-scheme="secondary"
                    icon="chevron-up"
                    :disabled="index === 0"
                    @click="move(index, -1)"
                  />
                  <woot-button
                    v-tooltip="t('DOWN')"
                    size="tiny"
                    variant="clear"
                    color-scheme="secondary"
                    icon="chevron-down"
                    :disabled="index === blocks.length - 1"
                    @click="move(index, 1)"
                  />
                </div>
                <div
                  v-if="openBlock === block.key"
                  class="flex flex-col gap-2 px-3 pt-1 pb-3 border-t border-slate-50 dark:border-slate-800"
                >
                  <p class="fmt-hint">{{ t(`BLOCKS.${block.key}.HINT`) }}</p>
                  <!-- Encabezado: qué datos de la empresa y cuáles cambian en este formato -->
                  <template v-if="block.key === 'header'">
                    <div class="flex flex-wrap gap-x-3 gap-y-1">
                      <label
                        v-for="field in companyFields"
                        :key="field"
                        class="flex items-center gap-1 mb-0 text-sm"
                      >
                        <input
                          type="checkbox"
                          class="m-0"
                          :checked="has(['header', 'fields'], field)"
                          @change="toggleIn(['header', 'fields'], field)"
                        />
                        {{ t(`COMPANY.${field}`) }}
                      </label>
                    </div>
                    <p class="mt-1 fmt-label">
                      {{ t('BLOCKS.header.OVERRIDE') }}
                    </p>
                    <input
                      v-for="field in companyFields"
                      :key="`o${field}`"
                      :value="(settings.header.company || {})[field]"
                      type="text"
                      class="!mb-0 text-sm"
                      :placeholder="`${t(`COMPANY.${field}`)}: ${
                        company[field] ||
                        (field === 'legal_name' ? data.account_name : '—')
                      }`"
                      @input="setCompanyOverride(field, $event.target.value)"
                    />
                  </template>
                  <div
                    v-else-if="block.key === 'client'"
                    class="flex flex-wrap gap-x-3 gap-y-1"
                  >
                    <label
                      v-for="field in clientFields"
                      :key="field"
                      class="flex items-center gap-1 mb-0 text-sm"
                    >
                      <input
                        type="checkbox"
                        class="m-0"
                        :checked="has(['client', 'fields'], field)"
                        @change="toggleIn(['client', 'fields'], field)"
                      />
                      {{ t(`CLIENT.${field}`) }}
                    </label>
                  </div>
                  <template v-else-if="block.key === 'items'">
                    <div class="flex flex-wrap gap-x-3 gap-y-1">
                      <label
                        v-for="column in itemColumns"
                        :key="column"
                        class="flex items-center gap-1 mb-0 text-sm"
                      >
                        <input
                          type="checkbox"
                          class="m-0"
                          :checked="has(['items', 'columns'], column)"
                          @change="toggleIn(['items', 'columns'], column)"
                        />
                        {{ t(`COLUMNS.${column}`) }}
                      </label>
                    </div>
                    <label class="flex items-center gap-1 mb-0 text-sm">
                      <input
                        type="checkbox"
                        class="m-0"
                        :checked="settings.items.prices_with_tax"
                        @change="
                          setOption(
                            'items',
                            'prices_with_tax',
                            $event.target.checked
                          )
                        "
                      />
                      {{ t('BLOCKS.items.PRICES_WITH_TAX') }}
                    </label>
                  </template>
                  <template v-else-if="block.key === 'totals'">
                    <label
                      v-for="key in [
                        'tax_breakdown',
                        'withholdings',
                        'amount_in_words',
                      ]"
                      :key="key"
                      class="flex items-center gap-1 mb-0 text-sm"
                    >
                      <input
                        type="checkbox"
                        class="m-0"
                        :checked="settings.totals[key]"
                        @change="
                          setOption('totals', key, $event.target.checked)
                        "
                      />
                      {{ t(`BLOCKS.totals.${key}`) }}
                    </label>
                  </template>
                  <template v-else-if="block.key === 'signatures'">
                    <label
                      v-for="key in ['seller', 'client']"
                      :key="key"
                      class="flex items-center gap-1 mb-0 text-sm"
                    >
                      <input
                        type="checkbox"
                        class="m-0"
                        :checked="settings.signatures[key]"
                        @change="
                          setOption('signatures', key, $event.target.checked)
                        "
                      />
                      {{ t(`BLOCKS.signatures.${key}`) }}
                    </label>
                  </template>
                  <template v-if="textBlocks.includes(block.key)">
                    <textarea
                      :value="settings[block.key].text"
                      rows="4"
                      maxlength="3000"
                      class="!mb-0 text-sm"
                      :placeholder="t(`BLOCKS.${block.key}.PLACEHOLDER`)"
                      @input="setOption(block.key, 'text', $event.target.value)"
                    />
                    <span class="fmt-hint">
                      {{ t('VARIABLES', { list: variables }) }}
                    </span>
                  </template>
                </div>
              </div>
            </section>
          </fieldset>

          <!-- Datos de la empresa: para todos los formatos -->
          <fieldset :disabled="!canEdit" class="fmt-box">
            <h2 class="fmt-title">{{ t('COMPANY.TITLE') }}</h2>
            <p class="fmt-hint">{{ t('COMPANY.HINT') }}</p>
            <label v-for="field in companyFields" :key="field" class="block">
              <span class="fmt-label">{{ t(`COMPANY.${field}`) }}</span>
              <input
                v-model="company[field]"
                type="text"
                class="!mb-0"
                :maxlength="field === 'address' ? 300 : 120"
                :placeholder="field === 'legal_name' ? data.account_name : ''"
                @input="companyDirty = true"
              />
            </label>
            <div class="flex flex-col gap-1">
              <span class="fmt-label">{{ t('COMPANY.LOGO') }}</span>
              <div class="flex items-center gap-2">
                <img
                  v-if="company.logo_url"
                  :src="company.logo_url"
                  alt=""
                  class="object-contain h-10 border rounded border-slate-100"
                />
                <label class="mb-0 cursor-pointer button smooth secondary tiny">
                  {{ t('UPLOAD') }}
                  <input
                    type="file"
                    accept="image/png,image/jpeg,image/webp"
                    class="hidden"
                    @change="upload($event, 'company')"
                  />
                </label>
                <button
                  v-if="company.logo_url"
                  type="button"
                  class="text-xs text-red-600 hover:underline"
                  @click="dropLogo('company')"
                >
                  {{ t('REMOVE') }}
                </button>
              </div>
            </div>
            <woot-button
              v-if="canEdit"
              size="small"
              variant="smooth"
              class="self-start"
              :is-loading="saving"
              :disabled="!companyDirty"
              @click="saveCompany"
            >
              {{ t('COMPANY.SAVE') }}
            </woot-button>
          </fieldset>
        </div>
        <div
          v-if="canEdit"
          class="sticky bottom-0 flex items-center justify-between gap-2 px-4 py-3 mt-auto bg-white border-t dark:bg-slate-900 border-slate-50 dark:border-slate-800"
        >
          <span class="text-xs text-slate-500">
            {{ dirty ? t('UNSAVED') : '' }}
          </span>
          <woot-button
            size="small"
            :is-loading="saving"
            :disabled="!dirty"
            @click="save"
          >
            {{ t('SAVE') }}
          </woot-button>
        </div>
      </div>

      <!-- Vista previa -->
      <div class="flex flex-col min-h-0 p-4 bg-slate-50 dark:bg-slate-800">
        <div class="flex items-center justify-between mb-2">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            {{ t('PREVIEW') }}
          </span>
          <span class="text-xs text-slate-500">
            {{ previewLoading ? t('UPDATING') : t('PREVIEW_HINT') }}
          </span>
        </div>
        <iframe
          :srcdoc="previewHtml"
          :title="t('PREVIEW')"
          class="flex-1 w-full max-w-4xl mx-auto bg-white border-0 rounded shadow-sm min-h-[36rem]"
        />
        <p v-if="data && !data.pdf" class="mt-2 text-xs text-amber-700">
          {{ t('NO_PDF') }}
        </p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.fmt-box {
  @apply flex flex-col gap-2 p-3 border rounded-lg border-slate-75 dark:border-slate-700;
}
.fmt-title {
  @apply m-0 text-sm font-semibold text-slate-800 dark:text-slate-100;
}
.fmt-label {
  @apply block mb-1 text-xs font-medium text-slate-600 dark:text-slate-300;
}
.fmt-hint {
  @apply m-0 text-xs text-slate-500 dark:text-slate-400;
}
</style>
