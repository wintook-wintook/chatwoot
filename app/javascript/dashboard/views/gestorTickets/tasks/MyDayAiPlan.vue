<!--
  @tickets_cases — Plan-Bandeja-Prioridad F4: «Plan de mi día» con IA.
  A pedido (botón): la IA lee «Mi día» ya ordenado, la agenda y las duraciones,
  y responde en texto qué hacer en cada bloque y qué puede esperar a mañana.
  NO cambia el orden; lo que propone dejar para mañana se aplica solo si el
  agente pulsa «Pasar a mañana» (evento `postpone`, lo resuelve la bandeja).
-->
<script>
import CaseTasksAPI from 'dashboard/api/caseTasks';
import { localDay } from 'dashboard/helper/caseTaskPriority';

export default {
  name: 'MyDayAiPlan',
  props: {
    rows: { type: Array, default: () => [] },
  },
  emits: ['openTask', 'postpone'],
  data() {
    return { plan: null, isLoading: false, error: '', open: false };
  },
  computed: {
    byId() {
      return Object.fromEntries(this.rows.map(r => [r.id, r]));
    },
    steps() {
      return ((this.plan && this.plan.steps) || []).filter(
        s => this.byId[s.task_id]
      );
    },
    later() {
      return ((this.plan && this.plan.later) || []).filter(
        s => this.byId[s.task_id]
      );
    },
  },
  methods: {
    async generate() {
      this.open = true;
      this.isLoading = true;
      this.error = '';
      try {
        const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
        const { data } = await CaseTasksAPI.myDayAi(localDay(), tz);
        this.plan = data.plan;
      } catch (e) {
        const msg = e && e.response && e.response.data && e.response.data.error;
        this.error = msg || this.$t('CASE_TICKETS.TASKS.MY_DAY.AI.ERROR');
      } finally {
        this.isLoading = false;
      }
    },
    close() {
      this.open = false;
    },
    title(id) {
      return this.byId[id] ? this.byId[id].title : '';
    },
    postpone(item) {
      const row = this.byId[item.task_id];
      if (!row) return;
      this.$emit('postpone', row);
      this.plan = {
        ...this.plan,
        later: this.plan.later.filter(l => l.task_id !== item.task_id),
      };
    },
  },
};
</script>

<template>
  <div>
    <woot-button
      v-if="!open"
      size="small"
      variant="smooth"
      color-scheme="primary"
      icon="wand"
      @click="generate"
    >
      {{ $t('CASE_TICKETS.TASKS.MY_DAY.AI.BUTTON') }}
    </woot-button>

    <section
      v-else
      class="p-4 border rounded-xl bg-woot-25 border-woot-100 dark:bg-woot-900/20 dark:border-woot-800"
      aria-live="polite"
    >
      <div class="flex items-center gap-2 mb-2">
        <fluent-icon
          icon="wand"
          size="16"
          class="text-woot-600 dark:text-woot-300"
        />
        <h2
          class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ $t('CASE_TICKETS.TASKS.MY_DAY.AI.TITLE') }}
        </h2>
        <div class="flex items-center gap-1 ml-auto">
          <woot-button
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            icon="arrow-clockwise"
            :is-loading="isLoading"
            :title="$t('CASE_TICKETS.TASKS.MY_DAY.AI.REGENERATE')"
            @click="generate"
          />
          <woot-button
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            icon="dismiss"
            :title="$t('CASE_TICKETS.TASKS.MY_DAY.AI.CLOSE')"
            @click="close"
          />
        </div>
      </div>

      <p
        v-if="isLoading && !plan"
        class="m-0 text-sm text-slate-500 dark:text-slate-400"
      >
        {{ $t('CASE_TICKETS.TASKS.MY_DAY.AI.LOADING') }}
      </p>
      <p v-else-if="error" class="m-0 text-sm text-red-700 dark:text-red-300">
        {{ error }}
      </p>

      <template v-else-if="plan">
        <p
          v-if="plan.intro"
          class="m-0 mb-3 text-sm text-slate-700 dark:text-slate-200"
        >
          {{ plan.intro }}
        </p>
        <p
          v-if="plan.warning"
          class="px-2 py-1 m-0 mb-3 text-xs rounded bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300"
        >
          {{ plan.warning }}
        </p>

        <ol v-if="steps.length" class="flex flex-col gap-2 p-0 m-0 list-none">
          <li v-for="s in steps" :key="s.task_id" class="flex gap-3 text-sm">
            <span
              class="w-24 flex-shrink-0 font-mono text-xs font-semibold pt-0.5 text-woot-700 dark:text-woot-300"
            >
              {{ s.when }}
            </span>
            <span class="min-w-0">
              <button
                type="button"
                class="font-medium text-left text-slate-800 dark:text-slate-100 hover:underline"
                @click="$emit('openTask', byId[s.task_id])"
              >
                {{ title(s.task_id) }}
              </button>
              <span
                v-if="s.note"
                class="block text-xs text-slate-500 dark:text-slate-400"
              >
                {{ s.note }}
              </span>
            </span>
          </li>
        </ol>

        <div v-if="later.length" class="mt-4">
          <h3
            class="m-0 mb-2 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
          >
            {{ $t('CASE_TICKETS.TASKS.MY_DAY.AI.LATER') }}
          </h3>
          <ul class="flex flex-col gap-2 p-0 m-0 list-none">
            <li
              v-for="l in later"
              :key="l.task_id"
              class="flex flex-wrap items-center gap-2 text-sm"
            >
              <span class="min-w-0 flex-1">
                <span class="font-medium text-slate-800 dark:text-slate-100">
                  {{ title(l.task_id) }}
                </span>
                <span
                  v-if="l.note"
                  class="block text-xs text-slate-500 dark:text-slate-400"
                >
                  {{ l.note }}
                </span>
              </span>
              <woot-button
                size="tiny"
                variant="smooth"
                color-scheme="secondary"
                icon="snooze"
                @click="postpone(l)"
              >
                {{ $t('CASE_TICKETS.TASKS.MY_DAY.POSTPONE') }}
              </woot-button>
            </li>
          </ul>
        </div>

        <p class="m-0 mt-3 text-[11px] text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.TASKS.MY_DAY.AI.DISCLAIMER') }}
        </p>
      </template>
    </section>
  </div>
</template>
