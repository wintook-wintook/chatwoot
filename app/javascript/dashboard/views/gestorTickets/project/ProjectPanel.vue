<!--
  @tickets_cases — Plan-Clase-Proyecto P1
  Pestaña «Proyecto» de la ficha: fechas (inicio y objetivo), presupuesto (horas
  y monto en la moneda de la cuenta) y avance, editables en línea (se guardan
  juntos con PATCH /case_tickets/:id; el backend deja `project_changed`).
  Atrasado = abierto con la fecha objetivo ya pasada. Cerrado = solo lectura,
  con el resumen de cierre. P2 — con casos dentro o hitos, el avance se calcula
  solo (casos terminados + hitos hechos) y el campo de avance se bloquea; las
  horas reales son la suma de sus órdenes de trabajo.
-->
<script>
import { formatDay, formatMoney } from 'dashboard/helper/caseCommercial';
import { formatHours } from 'dashboard/helper/caseWorkOrder';
import { projectPayload } from 'dashboard/helper/caseProject';

const FIELDS = [
  'project_start_on',
  'project_due_on',
  'budget_hours',
  'budget_amount',
  'progress',
];

export default {
  name: 'ProjectPanel',
  props: {
    ticket: { type: Object, required: true },
  },
  emits: ['updated'],
  data() {
    return { draft: this.fromTicket(), isSaving: false };
  },
  computed: {
    isFrozen() {
      return !!this.ticket.is_frozen;
    },
    isDirty() {
      const original = this.fromTicket();
      return FIELDS.some(f => String(this.draft[f]) !== String(original[f]));
    },
    progress() {
      return this.ticket.progress ?? 0;
    },
    summary() {
      return this.ticket.project_summary || {};
    },
    isAuto() {
      return !!this.summary.progress_auto;
    },
    // Horas reales (suma de las órdenes) contra presupuesto, en %.
    hoursUsedPct() {
      const budget = Number(this.ticket.budget_hours);
      if (!budget) return null;
      return Math.round(((this.summary.actual_hours || 0) / budget) * 100);
    },
  },
  watch: {
    ticket() {
      this.draft = this.fromTicket();
    },
  },
  methods: {
    fromTicket() {
      const t = this.ticket || {};
      return {
        project_start_on: t.project_start_on || '',
        project_due_on: t.project_due_on || '',
        budget_hours: t.budget_hours ?? '',
        budget_amount: t.budget_amount ?? '',
        progress: t.progress_manual ?? '',
      };
    },
    day(value) {
      return value ? formatDay(value) : '—';
    },
    hours(value) {
      return formatHours(value);
    },
    money(value) {
      return value === null || value === undefined
        ? '—'
        : formatMoney(value, this.ticket.currency);
    },
    discard() {
      this.draft = this.fromTicket();
    },
    async save() {
      this.isSaving = true;
      try {
        await this.$store.dispatch('caseTickets/updateWorkOrderData', {
          ticketId: this.ticket.id,
          data: projectPayload(this.draft, { clear: true }),
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.PROJECT.PANEL.SAVED'),
        });
        this.$emit('updated');
      } catch (e) {
        const error = e.response?.data?.error;
        this.$emitter.emit('newToastMessage', {
          message: Array.isArray(error)
            ? error.join(', ')
            : error || this.$t('CASE_TICKETS.PROJECT.PANEL.SAVE_ERROR'),
          type: 'error',
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
    class="flex flex-col gap-4 p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
  >
    <!-- Avance -->
    <div class="flex flex-wrap items-center gap-3">
      <span
        class="text-xs font-semibold tracking-wide uppercase text-indigo-700 dark:text-indigo-300"
      >
        {{ $t('CASE_TICKETS.PROJECT.PANEL.TITLE') }}
      </span>
      <span
        v-if="ticket.project_overdue"
        class="inline-flex items-center gap-1 px-2 py-0.5 text-[11px] font-medium rounded-full bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-300"
      >
        <fluent-icon icon="warning" size="12" />
        {{ $t('CASE_TICKETS.PROJECT.OVERDUE') }}
      </span>
      <div class="flex items-center flex-1 min-w-[12rem] gap-2">
        <span
          v-if="isAuto"
          class="text-xs text-slate-500 dark:text-slate-400 whitespace-nowrap"
        >
          {{
            $t('CASE_TICKETS.PROJECT.PANEL.AUTO', {
              done:
                (summary.children_done || 0) + (summary.milestones_done || 0),
              total:
                (summary.children_total || 0) + (summary.milestones_total || 0),
            })
          }}
        </span>
        <span
          class="flex-1 h-2 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-700"
          :title="$t('CASE_TICKETS.PROJECT.FIELDS.PROGRESS')"
        >
          <span
            class="block h-full rounded-full bg-indigo-500"
            :style="{ width: `${Math.min(100, progress)}%` }"
          />
        </span>
        <span
          class="text-sm font-semibold tabular-nums text-slate-800 dark:text-slate-100"
          >{{ progress }}%</span
        >
      </div>
    </div>

    <!-- Casos, hitos y horas reales contra presupuesto -->
    <div
      class="grid gap-3 text-sm grid-cols-[repeat(auto-fit,minmax(9rem,1fr))]"
    >
      <div class="flex flex-col">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.PROJECT.PANEL.CHILDREN') }}
        </span>
        <span class="tabular-nums text-slate-700 dark:text-slate-200">
          {{ summary.children_done || 0 }} / {{ summary.children_total || 0 }}
        </span>
      </div>
      <div class="flex flex-col">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.PROJECT.PANEL.MILESTONES') }}
        </span>
        <span class="tabular-nums text-slate-700 dark:text-slate-200">
          {{ summary.milestones_done || 0 }} /
          {{ summary.milestones_total || 0 }}
        </span>
      </div>
      <div class="flex flex-col">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.PROJECT.PANEL.HOURS') }}
        </span>
        <span
          class="tabular-nums"
          :class="
            hoursUsedPct > 100
              ? 'font-semibold text-red-600 dark:text-red-400'
              : 'text-slate-700 dark:text-slate-200'
          "
        >
          {{ hours(summary.actual_hours) }} / {{ hours(ticket.budget_hours) }}
          <template v-if="hoursUsedPct !== null">
            ({{ hoursUsedPct }}%)</template
          >
        </span>
      </div>
    </div>

    <!-- Cerrado: solo lectura + resumen de cierre -->
    <div v-if="isFrozen" class="flex flex-wrap items-start gap-x-8 gap-y-2">
      <div class="flex flex-col">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.PROJECT.FIELDS.START') }}
        </span>
        <span class="text-sm text-slate-700 dark:text-slate-200">
          {{ day(ticket.project_start_on) }}
        </span>
      </div>
      <div class="flex flex-col">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.PROJECT.FIELDS.DUE') }}
        </span>
        <span class="text-sm text-slate-700 dark:text-slate-200">
          {{ day(ticket.project_due_on) }}
        </span>
      </div>
      <div class="flex flex-col">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.PROJECT.FIELDS.BUDGET_HOURS') }}
        </span>
        <span class="text-sm tabular-nums text-slate-700 dark:text-slate-200">
          {{ hours(ticket.budget_hours) }}
        </span>
      </div>
      <div class="flex flex-col">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.PROJECT.FIELDS.BUDGET_AMOUNT') }}
        </span>
        <span class="text-sm tabular-nums text-slate-700 dark:text-slate-200">
          {{ money(ticket.budget_amount) }}
        </span>
      </div>
      <div
        v-if="ticket.closure_solution"
        class="flex flex-col flex-1 min-w-[12rem]"
      >
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.PROJECT.CLOSE.SUMMARY') }}
        </span>
        <span class="text-sm text-slate-700 dark:text-slate-200">
          {{ ticket.closure_solution }}
        </span>
      </div>
    </div>

    <!-- Abierto: edición en línea -->
    <form
      v-else
      class="flex flex-wrap items-end gap-3 [&_input]:!mb-0"
      @submit.prevent="save"
    >
      <label class="flex flex-col w-40 gap-1">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.PROJECT.FIELDS.START') }}
        </span>
        <input
          v-model="draft.project_start_on"
          type="date"
          class="h-8 text-sm"
        />
      </label>
      <label class="flex flex-col w-40 gap-1">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.PROJECT.FIELDS.DUE') }}
        </span>
        <input
          v-model="draft.project_due_on"
          type="date"
          class="h-8 text-sm"
          :min="draft.project_start_on || undefined"
        />
      </label>
      <label class="flex flex-col w-32 gap-1">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.PROJECT.FIELDS.BUDGET_HOURS') }}
        </span>
        <input
          v-model="draft.budget_hours"
          type="number"
          min="0"
          step="0.5"
          class="h-8 text-sm"
        />
      </label>
      <label class="flex flex-col w-40 gap-1">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.PROJECT.FIELDS.BUDGET_AMOUNT') }}
          <template v-if="ticket.currency">({{ ticket.currency }})</template>
        </span>
        <input
          v-model="draft.budget_amount"
          type="number"
          min="0"
          step="0.01"
          class="h-8 text-sm"
        />
      </label>
      <!-- Con casos o hitos el avance se calcula solo: no se captura -->
      <label
        v-if="!isAuto"
        class="flex flex-col w-24 gap-1"
        :title="$t('CASE_TICKETS.PROJECT.PANEL.MANUAL_HINT')"
      >
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.PROJECT.FIELDS.PROGRESS') }} %
        </span>
        <input
          v-model="draft.progress"
          type="number"
          min="0"
          max="100"
          step="5"
          class="h-8 text-sm"
        />
      </label>
      <div v-if="isDirty" class="flex gap-2 ml-auto">
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          type="button"
          @click="discard"
        >
          {{ $t('CASE_TICKETS.PROJECT.PANEL.CANCEL') }}
        </woot-button>
        <woot-button size="small" type="submit" :is-loading="isSaving">
          {{ $t('CASE_TICKETS.PROJECT.PANEL.SAVE') }}
        </woot-button>
      </div>
    </form>
  </div>
</template>
