<!--
  ================================================================================
  proyecto@import_seguimiento
  ================================================================================
  Componente: ImportModal.vue
  Descripción: Modal para importar contactos desde Excel/CSV hacia contact_trackings.
               Muestra zona de carga, estado de procesamiento y reporte de resultados.
  ================================================================================
-->

<script>
import contactTrackingImportsAPI from 'dashboard/api/contactTrackingImports';

export default {
  props: {
    show: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['close'],
  data() {
    return {
      selectedFile: null,
      isDragging: false,
      isLoading: false,
      results: null,
      errorMessage: null,
    };
  },
  computed: {
    hasResults() {
      return this.results !== null;
    },
    hasErrors() {
      return this.results && this.results.errors && this.results.errors.length > 0;
    },
    acceptedFormats() {
      return '.xlsx,.xls,.csv';
    },
  },
  watch: {
    show(val) {
      if (!val) this.reset();
    },
  },
  methods: {
    reset() {
      this.selectedFile = null;
      this.isDragging = false;
      this.isLoading = false;
      this.results = null;
      this.errorMessage = null;
    },
    close() {
      this.$emit('close');
    },
    onDragOver(e) {
      e.preventDefault();
      this.isDragging = true;
    },
    onDragLeave() {
      this.isDragging = false;
    },
    onDrop(e) {
      e.preventDefault();
      this.isDragging = false;
      const file = e.dataTransfer.files[0];
      if (file) this.setFile(file);
    },
    onFileChange(e) {
      const file = e.target.files[0];
      if (file) this.setFile(file);
    },
    setFile(file) {
      const allowed = [
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.ms-excel',
        'text/csv',
      ];
      const extAllowed = /\.(xlsx|xls|csv)$/i.test(file.name);
      if (!allowed.includes(file.type) && !extAllowed) {
        this.errorMessage = this.$t('TRACKING_IMPORT.INVALID_FORMAT');
        return;
      }
      this.errorMessage = null;
      this.results = null;
      this.selectedFile = file;
    },
    clearFile() {
      this.selectedFile = null;
      this.results = null;
      this.errorMessage = null;
      if (this.$refs.fileInput) this.$refs.fileInput.value = '';
    },
    async upload() {
      if (!this.selectedFile) return;

      this.isLoading = true;
      this.errorMessage = null;
      this.results = null;

      try {
        const { data } = await contactTrackingImportsAPI.importFile(this.selectedFile);
        this.results = data;
      } catch (err) {
        const msg = err?.response?.data?.error || this.$t('TRACKING_IMPORT.UPLOAD_ERROR');
        this.errorMessage = msg;
      } finally {
        this.isLoading = false;
      }
    },
    downloadTemplate() {
      // Genera un CSV de ejemplo con las columnas esperadas y lo descarga
      const headers = [
        'template_name',
        'contact_phone',
        'contact_name',
        'scheduled_for',
        'inbox_id',
        'max_attempts',
        'retry_interval_value',
        'retry_interval_unit',
        'ai_context',
        'complementary_prompt',
      ].join(',');

      const example =
        'Seguimiento Post-Demo,+5491122334455,Juan Pérez,2026-04-15 09:00,,,,,, ';

      const content = `${headers}\n${example}`;
      const blob = new Blob([content], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = 'plantilla_importacion_seguimientos.csv';
      link.click();
      URL.revokeObjectURL(url);
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="close">
    <div class="p-6 w-full max-w-2xl">
      <!-- Header -->
      <div class="mb-5">
        <h2 class="text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('TRACKING_IMPORT.TITLE') }}
        </h2>
        <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
          {{ $t('TRACKING_IMPORT.DESCRIPTION') }}
        </p>
      </div>

      <!-- Zona de carga de archivo -->
      <div v-if="!hasResults">
        <!-- Drag & Drop area -->
        <div
          class="border-2 border-dashed rounded-lg p-8 text-center transition-colors cursor-pointer"
          :class="isDragging
            ? 'border-woot-500 bg-woot-50 dark:bg-woot-900/20'
            : 'border-slate-300 dark:border-slate-600 hover:border-woot-400'"
          @dragover="onDragOver"
          @dragleave="onDragLeave"
          @drop="onDrop"
          @click="$refs.fileInput.click()"
        >
          <input
            ref="fileInput"
            type="file"
            class="hidden"
            :accept="acceptedFormats"
            @change="onFileChange"
          />

          <div v-if="!selectedFile">
            <fluent-icon icon="cloud-arrow-up" size="40" class="mx-auto mb-3 text-slate-400 dark:text-slate-500" />
            <p class="text-sm font-medium text-slate-700 dark:text-slate-300">
              {{ $t('TRACKING_IMPORT.DROP_HINT') }}
            </p>
            <p class="text-xs text-slate-400 dark:text-slate-500 mt-1">
              {{ $t('TRACKING_IMPORT.FORMATS') }}
            </p>
          </div>

          <div v-else class="flex items-center justify-center gap-3">
            <fluent-icon icon="document" size="28" class="text-woot-500" />
            <div class="text-left">
              <p class="text-sm font-medium text-slate-800 dark:text-slate-200">
                {{ selectedFile.name }}
              </p>
              <p class="text-xs text-slate-400">
                {{ (selectedFile.size / 1024).toFixed(1) }} KB
              </p>
            </div>
            <woot-button
              variant="smooth"
              size="tiny"
              color-scheme="alert"
              icon="dismiss"
              @click.stop="clearFile"
            />
          </div>
        </div>

        <!-- Error de formato -->
        <p v-if="errorMessage" class="mt-2 text-xs text-red-600 dark:text-red-400">
          {{ errorMessage }}
        </p>

        <!-- Enlace plantilla de ejemplo -->
        <div class="mt-3 flex items-center gap-1">
          <fluent-icon icon="arrow-download" size="14" class="text-woot-500" />
          <button
            class="text-xs text-woot-600 dark:text-woot-400 hover:underline"
            type="button"
            @click="downloadTemplate"
          >
            {{ $t('TRACKING_IMPORT.DOWNLOAD_TEMPLATE') }}
          </button>
        </div>

        <!-- Columnas esperadas -->
        <div class="mt-4 rounded-md bg-slate-50 dark:bg-slate-800 p-4 text-xs text-slate-600 dark:text-slate-300">
          <p class="font-semibold mb-2">{{ $t('TRACKING_IMPORT.COLUMNS_TITLE') }}</p>
          <div class="grid grid-cols-2 gap-x-4 gap-y-1">
            <div>
              <span class="text-red-500">*</span>
              <code class="font-mono">template_name</code>
              — {{ $t('TRACKING_IMPORT.COL_TEMPLATE_NAME') }}
            </div>
            <div>
              <span class="text-red-500">*</span>
              <code class="font-mono">scheduled_for</code>
              — {{ $t('TRACKING_IMPORT.COL_SCHEDULED_FOR') }}
            </div>
            <div>
              <code class="font-mono">contact_phone</code>
              — {{ $t('TRACKING_IMPORT.COL_PHONE') }}
            </div>
            <div>
              <code class="font-mono">contact_name</code>
              — {{ $t('TRACKING_IMPORT.COL_NAME') }}
            </div>
            <div>
              <code class="font-mono">inbox_id</code>
              — {{ $t('TRACKING_IMPORT.COL_INBOX') }}
            </div>
            <div>
              <code class="font-mono">max_attempts</code>
              — {{ $t('TRACKING_IMPORT.COL_MAX_ATTEMPTS') }}
            </div>
            <div>
              <code class="font-mono">retry_interval_value</code>
              — {{ $t('TRACKING_IMPORT.COL_INTERVAL_VALUE') }}
            </div>
            <div>
              <code class="font-mono">retry_interval_unit</code>
              — {{ $t('TRACKING_IMPORT.COL_INTERVAL_UNIT') }}
            </div>
            <div>
              <code class="font-mono">ai_context</code>
              — {{ $t('TRACKING_IMPORT.COL_AI_CONTEXT') }}
            </div>
            <div>
              <code class="font-mono">complementary_prompt</code>
              — {{ $t('TRACKING_IMPORT.COL_COMPLEMENTARY') }}
            </div>
          </div>
          <p class="mt-2 text-slate-400 dark:text-slate-500">
            <span class="text-red-500">*</span> {{ $t('TRACKING_IMPORT.REQUIRED_NOTE') }}
          </p>
        </div>

        <!-- Botones -->
        <div class="flex justify-end gap-3 mt-6">
          <woot-button
            variant="smooth"
            color-scheme="secondary"
            @click="close"
          >
            {{ $t('TRACKING_IMPORT.CANCEL') }}
          </woot-button>
          <woot-button
            color-scheme="success"
            icon="upload"
            :disabled="!selectedFile || isLoading"
            :is-loading="isLoading"
            @click="upload"
          >
            {{ $t('TRACKING_IMPORT.IMPORT_BTN') }}
          </woot-button>
        </div>
      </div>

      <!-- Resultados -->
      <div v-else>
        <!-- Resumen -->
        <div class="grid grid-cols-3 gap-3 mb-5">
          <div class="rounded-lg bg-green-50 dark:bg-green-900/20 p-4 text-center">
            <p class="text-2xl font-bold text-green-600 dark:text-green-400">
              {{ results.inserted }}
            </p>
            <p class="text-xs text-green-700 dark:text-green-300 mt-1">
              {{ $t('TRACKING_IMPORT.RESULT_INSERTED') }}
            </p>
          </div>
          <div class="rounded-lg bg-yellow-50 dark:bg-yellow-900/20 p-4 text-center">
            <p class="text-2xl font-bold text-yellow-600 dark:text-yellow-400">
              {{ results.skipped }}
            </p>
            <p class="text-xs text-yellow-700 dark:text-yellow-300 mt-1">
              {{ $t('TRACKING_IMPORT.RESULT_SKIPPED') }}
            </p>
          </div>
          <div class="rounded-lg bg-red-50 dark:bg-red-900/20 p-4 text-center">
            <p class="text-2xl font-bold text-red-600 dark:text-red-400">
              {{ results.errors.length }}
            </p>
            <p class="text-xs text-red-700 dark:text-red-300 mt-1">
              {{ $t('TRACKING_IMPORT.RESULT_ERRORS') }}
            </p>
          </div>
        </div>

        <!-- Tabla de errores -->
        <div v-if="hasErrors" class="mb-5">
          <p class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">
            {{ $t('TRACKING_IMPORT.ERROR_DETAIL_TITLE') }}
          </p>
          <div class="max-h-48 overflow-y-auto rounded border border-red-200 dark:border-red-800">
            <table class="min-w-full text-xs">
              <thead class="bg-red-50 dark:bg-red-900/20">
                <tr>
                  <th class="px-3 py-2 text-left text-red-700 dark:text-red-300 font-semibold w-20">
                    {{ $t('TRACKING_IMPORT.ERROR_ROW') }}
                  </th>
                  <th class="px-3 py-2 text-left text-red-700 dark:text-red-300 font-semibold">
                    {{ $t('TRACKING_IMPORT.ERROR_MESSAGE') }}
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-red-100 dark:divide-red-900">
                <tr
                  v-for="(error, idx) in results.errors"
                  :key="idx"
                  class="bg-white dark:bg-slate-900"
                >
                  <td class="px-3 py-2 text-slate-600 dark:text-slate-400">
                    {{ error.row }}
                  </td>
                  <td class="px-3 py-2 text-red-600 dark:text-red-400">
                    {{ error.message }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Botones de resultado -->
        <div class="flex justify-end gap-3">
          <woot-button
            variant="smooth"
            color-scheme="secondary"
            @click="reset"
          >
            {{ $t('TRACKING_IMPORT.IMPORT_ANOTHER') }}
          </woot-button>
          <woot-button
            color-scheme="primary"
            @click="close"
          >
            {{ $t('TRACKING_IMPORT.CLOSE') }}
          </woot-button>
        </div>
      </div>
    </div>
  </woot-modal>
</template>
