<!--
  Cobranza › Subir la cartera: el Excel o CSV (una fila por factura con saldo). Primero la vista previa (columnas
  reconocidas, errores, totales, antigüedad y qué cambia contra el corte anterior); después «Aplicar el corte». Las
  columnas del Excel propio se eligen una vez y se recuerdan. Cada corte reemplaza al anterior: lo que ya no viene,
  pagado.
-->
<script>
import { useAlert } from 'dashboard/composables';
import CollectionsAPI from 'dashboard/api/collections';
import AgingTable from './AgingTable.vue';
import { money, FIELDS, REQUIRED } from './money';

export default {
  name: 'UploadPanel',
  components: { AgingTable },
  emits: ['applied'],
  data() {
    return {
      file: null,
      headers: [],
      mapping: {},
      preview: null,
      loading: false,
      applying: false,
      result: null,
    };
  },
  computed: {
    fields() {
      return FIELDS;
    },
    missing() {
      return REQUIRED.filter(f => !this.mapping[f]);
    },
    diff() {
      return this.preview?.diff || {};
    },
  },
  methods: {
    money,
    t(key, params) {
      return this.$t(`COLLECTIONS.UPLOAD.${key}`, params);
    },
    required(field) {
      return REQUIRED.includes(field);
    },
    async downloadTemplate() {
      const { data } = await CollectionsAPI.downloadTemplate();
      const url = URL.createObjectURL(data);
      const link = document.createElement('a');
      link.href = url;
      link.download = 'cartera_kontrolya.csv';
      link.click();
      URL.revokeObjectURL(url);
    },
    onFile(event) {
      this.file = event.target.files[0] || null;
      this.preview = null;
      this.result = null;
      this.mapping = {};
      if (this.file) this.loadPreview();
    },
    async loadPreview() {
      this.loading = true;
      try {
        const { data } = await CollectionsAPI.preview(this.file, this.mapping);
        this.headers = data.headers;
        this.mapping = { ...data.mapping };
        this.preview = data.preview;
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('ERROR'));
      } finally {
        this.loading = false;
      }
    },
    setColumn(field, header) {
      this.mapping = { ...this.mapping, [field]: header };
      this.loadPreview();
    },
    async apply() {
      this.applying = true;
      try {
        const { data } = await CollectionsAPI.apply(this.file, this.mapping);
        this.result = data;
        this.preview = null;
        this.file = null;
        this.$emit('applied');
        useAlert(this.t('APPLIED'));
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('ERROR'));
      } finally {
        this.applying = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <div
      class="flex flex-col gap-2 p-4 border rounded-lg border-slate-100 dark:border-slate-700"
    >
      <p class="m-0 text-sm text-slate-700 dark:text-slate-200">
        {{ t('INTRO') }}
      </p>
      <p class="m-0 text-xs text-slate-500">{{ t('REPLACES') }}</p>
      <div class="flex flex-wrap items-center gap-3">
        <input
          type="file"
          accept=".xlsx,.csv,text/csv"
          class="!mb-0 text-sm"
          @change="onFile"
        />
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          size="small"
          icon="arrow-download"
          @click="downloadTemplate"
        >
          {{ t('TEMPLATE') }}
        </woot-button>
      </div>
      <p v-if="loading" class="m-0 text-xs text-slate-500">
        {{ t('READING') }}
      </p>
    </div>

    <!-- Columnas: reconocidas solas; las del Excel propio se eligen una vez -->
    <div
      v-if="headers.length"
      class="p-4 border rounded-lg border-slate-100 dark:border-slate-700"
    >
      <p class="m-0 mb-2 text-sm font-medium">{{ t('COLUMNS') }}</p>
      <div class="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-3">
        <label v-for="f in fields" :key="f" class="block">
          <span class="field-label">
            {{ t(`FIELDS.${f}`) }}
            <span v-if="required(f)" class="text-red-600">{{
              t('REQUIRED_MARK')
            }}</span>
          </span>
          <select
            class="!mb-0"
            :value="mapping[f] || ''"
            @change="setColumn(f, $event.target.value)"
          >
            <option value="">{{ t('NONE') }}</option>
            <option v-for="h in headers" :key="h" :value="h">{{ h }}</option>
          </select>
        </label>
      </div>
      <p v-if="missing.length" class="m-0 mt-2 text-xs text-red-600">
        {{ t('MISSING') }}
      </p>
    </div>

    <!-- Vista previa -->
    <div
      v-if="preview"
      class="flex flex-col gap-3 p-4 border rounded-lg border-slate-100 dark:border-slate-700"
    >
      <p class="m-0 text-sm font-medium">
        {{
          t('SUMMARY', {
            valid: preview.valid,
            rows: preview.rows,
            customers: preview.customers,
            invoices: preview.invoices,
          })
        }}
      </p>
      <AgingTable :aging="preview.aging" />
      <div class="grid grid-cols-2 gap-2 text-sm sm:grid-cols-4">
        <div class="p-2 rounded-md bg-slate-25 dark:bg-slate-800">
          <p class="m-0 text-lg font-semibold">{{ diff.new || 0 }}</p>
          <p class="m-0 text-xs text-slate-500">{{ t('DIFF.new') }}</p>
        </div>
        <div class="p-2 rounded-md bg-slate-25 dark:bg-slate-800">
          <p class="m-0 text-lg font-semibold">{{ diff.payments || 0 }}</p>
          <p class="m-0 text-xs text-slate-500">
            {{ t('DIFF.payments', { amount: money(diff.payments_amount) }) }}
          </p>
        </div>
        <div class="p-2 rounded-md bg-slate-25 dark:bg-slate-800">
          <p class="m-0 text-lg font-semibold">{{ diff.paid || 0 }}</p>
          <p class="m-0 text-xs text-slate-500">
            {{ t('DIFF.paid', { amount: money(diff.paid_amount) }) }}
          </p>
        </div>
        <div class="p-2 rounded-md bg-slate-25 dark:bg-slate-800">
          <p class="m-0 text-lg font-semibold">{{ preview.unlinked || 0 }}</p>
          <p class="m-0 text-xs text-slate-500">{{ t('DIFF.unlinked') }}</p>
        </div>
      </div>
      <div v-if="(preview.errors || []).length">
        <p class="m-0 text-xs font-medium text-amber-700">
          {{ t('ERRORS', { n: preview.errors.length }) }}
        </p>
        <ul class="pl-5 m-0 overflow-y-auto text-xs max-h-40 text-slate-600">
          <li v-for="(e, i) in preview.errors" :key="i">
            {{ t('ERROR_ROW', { row: e.row, reason: e.reason }) }}
          </li>
        </ul>
      </div>
      <div>
        <woot-button
          icon="checkmark"
          :is-loading="applying"
          :disabled="missing.length > 0 || !preview.valid"
          @click="apply"
        >
          {{ t('APPLY') }}
        </woot-button>
      </div>
    </div>

    <div
      v-if="result"
      class="p-4 text-sm rounded-lg bg-green-50 dark:bg-green-900/20 text-green-800 dark:text-green-200"
    >
      {{
        t('RESULT', {
          invoices: result.stats.invoices,
          customers: result.stats.customers,
          unlinked: result.stats.unlinked || 0,
        })
      }}
    </div>
  </div>
</template>
