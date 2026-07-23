<!--
  @tickets_cases
  Configuración de la plantilla de folio de tickets. Tailwind + dark mode.
-->
<template>
  <div class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900">
    <!-- Header -->
    <div class="flex items-center justify-between flex-shrink-0 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50">
      <div class="flex items-center gap-4">
        <woot-button size="small" variant="clear" color-scheme="secondary" icon="chevron-left" @click="$router.push({ name: 'gestorTickets_index' })">
          Volver
        </woot-button>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">{{ $t('CASE_TICKETS.FOLIO.TITLE') }}</h1>
      </div>
      <woot-button size="small" :is-loading="isSaving" :disabled="!form" @click="save">
        {{ $t('CASE_TICKETS.FOLIO.SAVE') }}
      </woot-button>
    </div>

    <div v-if="!form" class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500">
      <span>Cargando configuración...</span>
    </div>

    <div v-else class="flex flex-col flex-1 gap-6 p-6 overflow-y-auto max-w-3xl">
      <!-- Activar -->
      <label class="flex items-center gap-3 cursor-pointer">
        <button
          type="button"
          role="switch"
          :aria-checked="form.enabled"
          class="relative inline-flex items-center w-9 h-5 transition-colors rounded-full"
          :class="form.enabled ? 'bg-woot-500' : 'bg-slate-300 dark:bg-slate-600'"
          @click="form.enabled = !form.enabled"
        >
          <span class="inline-block w-3.5 h-3.5 transform bg-white rounded-full transition-transform" :class="form.enabled ? 'translate-x-4' : 'translate-x-1'" />
        </button>
        <span class="text-sm font-medium text-slate-700 dark:text-slate-200">{{ $t('CASE_TICKETS.FOLIO.ENABLED') }}</span>
      </label>

      <template v-if="form.enabled">
        <!-- Plantilla -->
        <div class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">{{ $t('CASE_TICKETS.FOLIO.TEMPLATE_LABEL') }}</span>
          <input v-model="form.template" type="text" class="w-full font-mono" placeholder="{PREFIX}-{SEQ:5}" />
          <!-- Preview en vivo -->
          <div class="flex items-center gap-2 mt-1">
            <span class="text-xs text-slate-400 dark:text-slate-500">{{ $t('CASE_TICKETS.FOLIO.PREVIEW') }}:</span>
            <span class="px-2 py-0.5 font-mono text-sm rounded bg-slate-100 text-slate-800 dark:bg-slate-700 dark:text-slate-200">{{ preview }}</span>
          </div>
        </div>

        <!-- Tokens disponibles -->
        <div class="p-4 border rounded-lg bg-slate-50 dark:bg-slate-800/50 border-slate-100 dark:border-slate-700">
          <p class="m-0 mb-2 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400">{{ $t('CASE_TICKETS.FOLIO.TOKENS_TITLE') }}</p>
          <div class="grid grid-cols-2 gap-x-6 gap-y-1 text-sm">
            <div v-for="tk in tokens" :key="tk.token" class="flex items-center gap-2">
              <button
                type="button"
                class="px-1.5 py-0.5 font-mono text-xs rounded bg-woot-100 text-woot-700 dark:bg-woot-700 dark:text-woot-100 hover:opacity-80"
                @click="insertToken(tk.token)"
              >{{ tk.token }}</button>
              <span class="text-slate-500 dark:text-slate-400">{{ tk.desc }}</span>
            </div>
          </div>
        </div>

        <!-- Alcance del consecutivo -->
        <div class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">{{ $t('CASE_TICKETS.FOLIO.SCOPE_LABEL') }}</span>
          <label class="flex items-center gap-2 text-sm cursor-pointer text-slate-600 dark:text-slate-300">
            <input v-model="form.per_type" type="checkbox" />
            <span>{{ $t('CASE_TICKETS.FOLIO.PER_TYPE') }}</span>
          </label>
        </div>

        <!-- Reinicio -->
        <div class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">{{ $t('CASE_TICKETS.FOLIO.RESET_LABEL') }}</span>
          <select v-model="form.reset_period" class="w-56">
            <option value="never">{{ $t('CASE_TICKETS.FOLIO.RESET.never') }}</option>
            <option value="daily">{{ $t('CASE_TICKETS.FOLIO.RESET.daily') }}</option>
            <option value="monthly">{{ $t('CASE_TICKETS.FOLIO.RESET.monthly') }}</option>
            <option value="yearly">{{ $t('CASE_TICKETS.FOLIO.RESET.yearly') }}</option>
          </select>
        </div>

        <p class="m-0 text-xs text-slate-400 dark:text-slate-500">{{ $t('CASE_TICKETS.FOLIO.NOTE') }}</p>
      </template>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';

const TOKENS = [
  { token: '{PREFIX}', desc: 'Prefijo del tipo de caso' },
  { token: '{SEQ:5}',  desc: 'Consecutivo (5 dígitos)' },
  { token: '{YYYY}',   desc: 'Año (4 dígitos)' },
  { token: '{YY}',     desc: 'Año (2 dígitos)' },
  { token: '{MM}',     desc: 'Mes' },
  { token: '{DD}',     desc: 'Día' },
];

export default {
  name: 'FolioConfig',
  data() {
    return { form: null, isSaving: false };
  },
  computed: {
    ...mapGetters({ folioConfig: 'caseTickets/getFolioConfig', types: 'caseTickets/getTypes' }),
    tokens() { return TOKENS; },
    preview() {
      if (!this.form) return '';
      const now = new Date();
      const samplePrefix = this.types[0]?.prefix || 'SOP';
      return this.form.template
        .replace(/\{PREFIX\}/g, samplePrefix)
        .replace(/\{SEQ:(\d+)\}/g, (_, n) => '1'.padStart(Number(n), '0'))
        .replace(/\{SEQ\}/g, '1')
        .replace(/\{YYYY\}/g, String(now.getFullYear()))
        .replace(/\{YY\}/g, String(now.getFullYear()).slice(-2))
        .replace(/\{MM\}/g, String(now.getMonth() + 1).padStart(2, '0'))
        .replace(/\{DD\}/g, String(now.getDate()).padStart(2, '0'));
    },
  },
  async mounted() {
    await this.$store.dispatch('caseTickets/fetchTypes');
    await this.$store.dispatch('caseTickets/fetchFolioConfig');
    this.form = { ...this.folioConfig };
  },
  methods: {
    insertToken(token) {
      this.form.template = (this.form.template || '') + token;
    },
    async save() {
      this.isSaving = true;
      try {
        await this.$store.dispatch('caseTickets/updateFolioConfig', this.form);
        this.$emitter.emit('newToastMessage', { message: this.$t('CASE_TICKETS.FOLIO.SAVED'), type: 'success' });
      } catch (_e) {
        this.$emitter.emit('newToastMessage', { message: this.$t('CASE_TICKETS.FOLIO.SAVE_ERROR'), type: 'error' });
      } finally {
        this.isSaving = false;
      }
    },
  },
};
</script>
