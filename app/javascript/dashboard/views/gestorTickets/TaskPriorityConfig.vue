<!--
  @tickets_cases — Plan-Bandeja-Prioridad F3: Configuración → Tareas.
  Pesos del puntaje con el que «Mi día» ordena las tareas pendientes (ver
  Cases::TaskPriorityScore). Agrupados por de dónde viene la urgencia; dos
  ejemplos se recalculan en vivo para que se vea el efecto antes de guardar.
  «Restaurar» vuelve a los de fábrica (hay que guardar). Solo administradores.
-->
<script>
import { mapGetters } from 'vuex';

// Grupos de pesos (mismas llaves que DEFAULT_WEIGHTS del backend).
const GROUPS = [
  {
    key: 'DUE',
    weights: [
      'overdue',
      'overdue_per_day',
      'overdue_days_max',
      'due_today',
      'due_tomorrow',
      'due_week',
    ],
  },
  {
    key: 'PRIORITY',
    weights: ['priority_urgent', 'priority_high', 'priority_medium'],
  },
  {
    key: 'PROJECT',
    weights: ['project_overdue', 'milestone', 'project_due_soon'],
  },
  { key: 'SUPPORT', weights: ['sla_overdue', 'sla_at_risk', 'case_urgent'] },
  { key: 'WORK_ORDER', weights: ['visit_overdue', 'visit_today'] },
  { key: 'COMMERCIAL', weights: ['close_soon'] },
  {
    key: 'OTHER',
    weights: ['planned_missed', 'age_per_day', 'age_max', 'waiting'],
  },
  { key: 'ALERT', weights: ['urgent_score'] },
];

// Rango que acepta el backend (CaseSetting::WEIGHT_RANGE / URGENT_SCORE_RANGE).
const rangeOf = key => (key === 'urgent_score' ? [1, 500] : [-100, 200]);

export default {
  name: 'TaskPriorityConfig',
  data() {
    return { form: {}, isSaving: false };
  },
  computed: {
    ...mapGetters({ settings: 'caseTickets/getCaseSettings' }),
    groups() {
      return GROUPS;
    },
    defaults() {
      return this.settings.task_priority_defaults || {};
    },
    saved() {
      return this.settings.task_priority_weights || {};
    },
    loaded() {
      return Object.keys(this.defaults).length > 0;
    },
    dirty() {
      return Object.keys(this.form).some(
        k => Number(this.form[k]) !== Number(this.saved[k])
      );
    },
    isDefault() {
      return Object.keys(this.form).every(
        k => Number(this.form[k]) === Number(this.defaults[k])
      );
    },
    invalidKeys() {
      return Object.keys(this.form).filter(k => {
        const v = this.form[k];
        const [min, max] = rangeOf(k);
        return v === '' || !Number.isInteger(Number(v)) || v < min || v > max;
      });
    },
    // Ejemplos en vivo (misma fórmula que el backend, solo los factores que usan).
    exampleProject() {
      const w = this.num;
      const late = Math.min(2 * w('overdue_per_day'), w('overdue_days_max'));
      return w('overdue') + late + w('priority_urgent') + w('project_overdue');
    },
    exampleSupport() {
      const w = this.num;
      return w('due_today') + w('priority_medium') + w('sla_overdue');
    },
  },
  watch: {
    saved: { immediate: true, handler: 'reset' },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchSettings');
  },
  methods: {
    num(key) {
      return Number(this.form[key]) || 0;
    },
    reset() {
      this.form = { ...this.saved };
    },
    restoreDefaults() {
      this.form = { ...this.defaults };
    },
    changed(key) {
      return Number(this.form[key]) !== Number(this.defaults[key]);
    },
    range(key) {
      return rangeOf(key);
    },
    label(key) {
      return this.$t(`CASE_TICKETS.TASK_PRIORITY.WEIGHTS.${key}`);
    },
    async save() {
      if (this.invalidKeys.length || this.isSaving) return;
      this.isSaving = true;
      try {
        const weights = {};
        Object.keys(this.form).forEach(k => {
          weights[k] = Number(this.form[k]);
        });
        await this.$store.dispatch('caseTickets/updateSettings', {
          task_priority_weights: weights,
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.TASK_PRIORITY.SAVED'),
        });
      } catch (e) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.TASK_PRIORITY.SAVE_ERROR'),
        });
      } finally {
        this.isSaving = false;
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <div
      class="flex flex-wrap items-center flex-shrink-0 gap-3 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
        {{ $t('CASE_TICKETS.TASK_PRIORITY.PAGE_TITLE') }}
      </h1>
      <div class="flex items-center gap-2 ml-auto">
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          size="small"
          :disabled="isDefault"
          @click="restoreDefaults"
        >
          {{ $t('CASE_TICKETS.TASK_PRIORITY.RESTORE') }}
        </woot-button>
        <woot-button
          size="small"
          :is-loading="isSaving"
          :disabled="!dirty || invalidKeys.length > 0"
          @click="save"
        >
          {{ $t('CASE_TICKETS.TASK_PRIORITY.SAVE') }}
        </woot-button>
      </div>
    </div>

    <div class="flex flex-col flex-1 gap-4 px-6 py-4 overflow-y-auto">
      <p class="max-w-3xl m-0 text-sm text-slate-600 dark:text-slate-300">
        {{ $t('CASE_TICKETS.TASK_PRIORITY.INTRO') }}
      </p>

      <!-- Ejemplos en vivo -->
      <div v-if="loaded" class="grid max-w-3xl gap-3 sm:grid-cols-2">
        <div
          class="p-3 border rounded-lg bg-white border-slate-100 dark:bg-slate-800 dark:border-slate-700"
        >
          <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
            {{ $t('CASE_TICKETS.TASK_PRIORITY.EXAMPLE_PROJECT') }}
          </p>
          <p
            class="m-0 mt-1 font-mono text-2xl font-bold tabular-nums text-woot-600 dark:text-woot-300"
          >
            {{ exampleProject }}
          </p>
        </div>
        <div
          class="p-3 border rounded-lg bg-white border-slate-100 dark:bg-slate-800 dark:border-slate-700"
        >
          <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
            {{ $t('CASE_TICKETS.TASK_PRIORITY.EXAMPLE_SUPPORT') }}
          </p>
          <p
            class="m-0 mt-1 font-mono text-2xl font-bold tabular-nums text-woot-600 dark:text-woot-300"
          >
            {{ exampleSupport }}
          </p>
        </div>
        <p class="m-0 text-xs sm:col-span-2 text-slate-500 dark:text-slate-400">
          {{
            exampleProject === exampleSupport
              ? $t('CASE_TICKETS.TASK_PRIORITY.EXAMPLE_TIE')
              : $t(
                  exampleProject > exampleSupport
                    ? 'CASE_TICKETS.TASK_PRIORITY.EXAMPLE_PROJECT_FIRST'
                    : 'CASE_TICKETS.TASK_PRIORITY.EXAMPLE_SUPPORT_FIRST'
                )
          }}
        </p>
      </div>

      <p v-if="!loaded" class="m-0 text-sm text-slate-400">
        {{ $t('CASE_TICKETS.LIST.LOADING') }}
      </p>

      <template v-else>
        <section
          v-for="group in groups"
          :key="group.key"
          class="max-w-3xl p-4 bg-white border rounded-lg border-slate-100 dark:bg-slate-800 dark:border-slate-700"
        >
          <h2
            class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ $t(`CASE_TICKETS.TASK_PRIORITY.GROUPS.${group.key}`) }}
          </h2>
          <div class="grid gap-x-6 gap-y-3 mt-3 sm:grid-cols-2">
            <label
              v-for="key in group.weights"
              :key="key"
              class="flex items-center justify-between gap-3"
            >
              <span class="text-sm text-slate-700 dark:text-slate-200">
                {{ label(key) }}
                <span
                  v-if="changed(key)"
                  class="ml-1 text-xs text-slate-400 dark:text-slate-500"
                >
                  {{
                    $t('CASE_TICKETS.TASK_PRIORITY.DEFAULT_WAS', {
                      value: defaults[key],
                    })
                  }}
                </span>
              </span>
              <input
                v-model.number="form[key]"
                type="number"
                step="1"
                :min="range(key)[0]"
                :max="range(key)[1]"
                class="!mb-0 w-24 text-right tabular-nums"
                :class="
                  invalidKeys.includes(key)
                    ? '!border-red-400 dark:!border-red-500'
                    : ''
                "
              />
            </label>
          </div>
        </section>
      </template>
    </div>
  </div>
</template>
