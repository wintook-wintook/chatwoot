<!--
  «Primeros pasos» — panel lateral que se abre SOLO si el usuario pulsa el botón en Inicio.
  Cada paso se palomea solo con lo que ya hizo (Onboarding::Steps en el servidor): «Hazlo»
  lleva a la pantalla y «¿Cómo?» le pregunta a Dali, que contesta con su guía.
-->
<script>
import { toggleAssistant } from 'dashboard/helper/assistantState';

const T = 'CASE_TICKETS.HOME.ONBOARDING';

// A dónde lleva «Hazlo» (ruta, o un evento para abrir una ventana).
const ACTIONS = {
  whatsapp: { route: 'settings_inbox_new' },
  team: { route: 'agent_list' },
  organization: { route: 'organizations_list', query: { new: '1' } },
  contact: { event: 'contact' },
  case: { route: 'gestorTickets_index' },
  meeting: { route: 'google_calendar' },
  follow_up: { route: 'gestorTickets_index' },
  dali: { dali: true },
};

export default {
  name: 'OnboardingPanel',
  props: {
    show: { type: Boolean, default: false },
    steps: { type: Array, default: () => [] },
  },
  emits: ['close'],
  computed: {
    doneCount() {
      return this.steps.filter(s => s.done).length;
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    ask(question) {
      toggleAssistant(true);
      this.$nextTick(() => this.$emitter.emit('assistant:ask', question));
    },
    doIt(key) {
      const action = ACTIONS[key] || {};
      this.$emit('close');
      if (action.dali) {
        this.ask(this.t('STEPS.dali.QUESTION'));
      } else if (action.event) {
        this.$emitter.emit('topbar:open', action.event);
      } else if (action.route) {
        this.$router.push({ name: action.route, query: action.query || {} });
      }
    },
    how(key) {
      this.$emit('close');
      this.ask(this.t(`STEPS.${key}.HOW`));
    },
  },
};
</script>

<template>
  <div v-if="show" class="fixed inset-0 z-50 flex justify-end">
    <div class="absolute inset-0 bg-black/20" @click="$emit('close')" />
    <aside
      class="relative flex flex-col w-full h-full max-w-md overflow-y-auto bg-white shadow-xl dark:bg-slate-900"
    >
      <header
        class="flex items-start justify-between gap-2 px-5 py-4 border-b border-slate-100 dark:border-slate-800"
      >
        <div>
          <h2
            class="m-0 text-lg font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ t('TITLE') }}
          </h2>
          <p class="m-0 text-sm text-slate-500 dark:text-slate-400">
            {{ t('PROGRESS', { done: doneCount, total: steps.length }) }}
          </p>
        </div>
        <woot-button
          variant="clear"
          color-scheme="secondary"
          icon="dismiss"
          :title="t('CLOSE')"
          @click="$emit('close')"
        />
      </header>
      <ol class="flex flex-col gap-1 p-3 m-0 list-none">
        <li
          v-for="(step, index) in steps"
          :key="step.key"
          class="flex gap-3 p-3 rounded-lg"
          :class="step.done ? 'opacity-70' : 'bg-slate-25 dark:bg-slate-800/60'"
        >
          <span
            class="flex items-center justify-center flex-shrink-0 w-6 h-6 text-xs font-semibold rounded-full"
            :class="
              step.done
                ? 'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300'
                : 'bg-woot-50 text-woot-700 dark:bg-woot-900/40 dark:text-woot-200'
            "
          >
            <fluent-icon v-if="step.done" icon="checkmark" size="14" />
            <template v-else>{{ index + 1 }}</template>
          </span>
          <div class="flex flex-col flex-1 min-w-0 gap-1">
            <p
              class="m-0 text-sm font-medium"
              :class="
                step.done
                  ? 'line-through text-slate-500'
                  : 'text-slate-800 dark:text-slate-100'
              "
            >
              {{ t(`STEPS.${step.key}.TITLE`) }}
            </p>
            <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
              {{ t(`STEPS.${step.key}.DESC`) }}
            </p>
            <div class="flex gap-2 mt-1">
              <woot-button
                size="tiny"
                :variant="step.done ? 'clear' : 'smooth'"
                @click="doIt(step.key)"
              >
                {{ step.done ? t('AGAIN') : t('DO_IT') }}
              </woot-button>
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                icon="wand"
                @click="how(step.key)"
              >
                {{ t('HOW') }}
              </woot-button>
            </div>
          </div>
        </li>
      </ol>
      <p
        v-if="steps.length && doneCount === steps.length"
        class="px-5 pb-5 m-0 text-sm text-green-700 dark:text-green-300"
      >
        {{ t('ALL_DONE') }}
      </p>
    </aside>
  </div>
</template>
