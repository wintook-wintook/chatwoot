<!--
  @tickets_cases 3A — Configuración de IA por cuenta (mixto configurable).
  Toggle global + modo por acción (off / suggest / auto). Las 5 acciones de la
  Fase 3 están implementadas (3B classify, 3C reply, 3E summarize, 3D duplicate,
  3F follow_up); cualquiera fuera de esta lista se muestra como "próximamente".
-->
<script>
import { mapGetters } from 'vuex';

const IMPLEMENTED = [
  'classify',
  'reply',
  'summarize',
  'duplicate',
  'follow_up',
];

export default {
  name: 'AiConfig',
  data() {
    return {
      form: { enabled: false, modes: {} },
      implemented: IMPLEMENTED,
    };
  },
  computed: {
    ...mapGetters({
      aiConfig: 'caseTickets/getAiConfig',
      uiFlags: 'caseTickets/getAiConfigUIFlags',
    }),
    isFetching() {
      return this.uiFlags.isFetching;
    },
    isSaving() {
      return this.uiFlags.isSaving;
    },
    actions() {
      return this.aiConfig?.actions || [];
    },
    modeOptions() {
      return this.aiConfig?.mode_options || ['off', 'suggest', 'auto'];
    },
    available() {
      return this.aiConfig?.available;
    },
  },
  watch: {
    aiConfig(cfg) {
      if (cfg) this.syncForm(cfg);
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchAiConfig');
  },
  methods: {
    syncForm(cfg) {
      this.form = {
        enabled: cfg.enabled,
        modes: { ...cfg.modes },
      };
    },
    isImplemented(action) {
      return this.implemented.includes(action);
    },
    async save() {
      try {
        await this.$store.dispatch('caseTickets/updateAiConfig', {
          enabled: this.form.enabled,
          modes: this.form.modes,
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.AI.SAVED'),
        });
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.AI.SAVE_ERROR'),
        });
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <!-- Header -->
    <div
      class="flex items-center justify-between flex-shrink-0 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex items-center gap-4">
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          icon="arrow-left"
          @click="$router.push({ name: 'gestorTickets_index' })"
        >
          {{ $t('CASE_TICKETS.AI.BACK') }}
        </woot-button>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CASE_TICKETS.AI.TITLE') }}
        </h1>
      </div>
      <woot-button size="small" :is-loading="isSaving" @click="save">
        {{ $t('CASE_TICKETS.AI.SAVE') }}
      </woot-button>
    </div>

    <div
      v-if="isFetching"
      class="flex items-center justify-center flex-1 text-slate-400"
    >
      {{ $t('CASE_TICKETS.AI.LOADING') }}
    </div>

    <div
      v-else
      class="flex flex-col flex-1 max-w-3xl gap-5 px-6 py-5 overflow-y-auto"
    >
      <p class="m-0 text-sm text-slate-500 dark:text-slate-400">
        {{ $t('CASE_TICKETS.AI.HELP') }}
      </p>

      <!-- Aviso si no hay API key -->
      <div
        v-if="!available"
        class="flex items-start gap-2 p-3 text-sm rounded-lg bg-amber-50 text-amber-800 dark:bg-amber-900/20 dark:text-amber-300"
      >
        <fluent-icon icon="warning" size="16" class="mt-0.5 flex-shrink-0" />
        <span>{{ $t('CASE_TICKETS.AI.NO_KEY') }}</span>
      </div>

      <!-- Toggle global -->
      <div
        class="flex items-center justify-between p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <div class="flex flex-col gap-0.5">
          <span
            class="text-sm font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ $t('CASE_TICKETS.AI.ENABLED_LABEL') }}
          </span>
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ $t('CASE_TICKETS.AI.ENABLED_HELP') }}
          </span>
        </div>
        <input v-model="form.enabled" type="checkbox" class="scale-125" />
      </div>

      <!-- Modos por acción -->
      <div
        class="bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        :class="{ 'opacity-50 pointer-events-none': !form.enabled }"
      >
        <div
          v-for="action in actions"
          :key="action"
          class="flex items-center justify-between gap-4 px-4 py-3 border-b last:border-b-0 border-slate-50 dark:border-slate-700/50"
        >
          <div class="flex flex-col gap-0.5 min-w-0">
            <div class="flex items-center gap-2">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >{{ $t(`CASE_TICKETS.AI.ACTIONS.${action}.LABEL`) }}</span
              >
              <span
                v-if="!isImplemented(action)"
                class="px-1.5 py-0.5 text-[10px] rounded-full bg-slate-100 text-slate-500 dark:bg-slate-700 dark:text-slate-400"
                >{{ $t('CASE_TICKETS.AI.SOON') }}</span
              >
            </div>
            <span class="text-xs text-slate-400 dark:text-slate-500">
              {{ $t(`CASE_TICKETS.AI.ACTIONS.${action}.HELP`) }}
            </span>
          </div>
          <select
            v-model="form.modes[action]"
            class="flex-shrink-0 w-40 input"
            :disabled="!isImplemented(action)"
          >
            <option v-for="m in modeOptions" :key="m" :value="m">
              {{ $t(`CASE_TICKETS.AI.MODES.${m}`) }}
            </option>
          </select>
        </div>
      </div>
    </div>
  </div>
</template>
