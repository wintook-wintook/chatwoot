<!--
  @tickets_cases — Plan-Clase-Comercial F4
  Franja «Datos comerciales» del detalle de una oportunidad: monto, moneda,
  cierre estimado y probabilidad, editables en línea (se guardan juntos con
  PATCH /case_tickets/:id; el backend deja `amount_changed` en el historial).
  Cerrada, se congela y muestra el resultado con su motivo y nota.
-->
<script>
import {
  OUTCOME_BADGE,
  POSTPONED_BADGE,
  formatMoney,
  formatDay,
} from 'dashboard/helper/caseCommercial';

const FIELDS = ['amount', 'currency', 'expected_close_at', 'probability'];

export default {
  name: 'CommercialPanel',
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
    weighted() {
      const { amount, probability } = this.ticket;
      if (amount === null || amount === undefined) return '—';
      if (probability === null || probability === undefined) return '—';
      return formatMoney(
        (Number(amount) * Number(probability)) / 100,
        this.ticket.currency
      );
    },
    outcomeBadge() {
      return OUTCOME_BADGE[this.ticket.outcome] || '';
    },
    postponedBadge() {
      return POSTPONED_BADGE;
    },
  },
  watch: {
    // Otro cambio (mover de etapa, cerrar, reabrir) trae datos nuevos.
    ticket() {
      this.draft = this.fromTicket();
    },
  },
  methods: {
    fromTicket() {
      const t = this.ticket || {};
      return {
        amount: t.amount ?? '',
        currency: t.currency || '',
        expected_close_at: t.expected_close_at || '',
        probability: t.probability ?? '',
      };
    },
    money(amount, currency) {
      return formatMoney(amount, currency);
    },
    day(value) {
      return formatDay(value);
    },
    discard() {
      this.draft = this.fromTicket();
    },
    async save() {
      this.isSaving = true;
      try {
        const data = {
          amount: this.draft.amount === '' ? null : this.draft.amount,
          currency: this.draft.currency.trim().toUpperCase() || null,
          expected_close_at: this.draft.expected_close_at || null,
          probability:
            this.draft.probability === '' ? null : this.draft.probability,
        };
        await this.$store.dispatch('caseTickets/updateCommercialData', {
          ticketId: this.ticket.id,
          data,
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.COMMERCIAL.PANEL.SAVED'),
        });
        this.$emit('updated');
      } catch (e) {
        const error = e.response?.data?.error;
        this.$emitter.emit('newToastMessage', {
          message: Array.isArray(error)
            ? error.join(', ')
            : error || this.$t('CASE_TICKETS.COMMERCIAL.PANEL.SAVE_ERROR'),
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
    class="flex flex-col flex-shrink-0 gap-2 px-6 py-3 border-b bg-violet-50 dark:bg-slate-800/50 border-slate-50 dark:border-slate-800/50"
  >
    <div class="flex flex-wrap items-center gap-2">
      <span
        class="text-xs font-semibold tracking-wide uppercase text-violet-700 dark:text-violet-300"
      >
        {{ $t('CASE_TICKETS.COMMERCIAL.PANEL.TITLE') }}
      </span>
      <span
        v-if="ticket.outcome"
        class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded"
        :class="outcomeBadge"
      >
        {{ $t(`CASE_TICKETS.COMMERCIAL.OUTCOMES.${ticket.outcome}`) }}
      </span>
      <span
        v-if="ticket.is_postponed"
        class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded"
        :class="postponedBadge"
      >
        {{
          $t('CASE_TICKETS.COMMERCIAL.POSTPONED_UNTIL', {
            date: day(ticket.postponed_until),
          })
        }}<template v-if="ticket.postpone_reason">
          · {{ ticket.postpone_reason.label }}</template
        >
      </span>
    </div>

    <!-- Cerrada: solo lectura + resultado -->
    <div v-if="isFrozen" class="flex flex-wrap items-start gap-x-8 gap-y-2">
      <div class="flex flex-col">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.AMOUNT') }}
        </span>
        <span class="text-sm font-semibold text-slate-800 dark:text-slate-100">
          {{ money(ticket.amount, ticket.currency) }}
        </span>
      </div>
      <div class="flex flex-col">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.OUTCOME_AT') }}
        </span>
        <span class="text-sm text-slate-700 dark:text-slate-200">
          {{ day(ticket.outcome_at) }}
        </span>
      </div>
      <div v-if="ticket.outcome_reason" class="flex flex-col">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.REASON') }}
        </span>
        <span class="text-sm text-slate-700 dark:text-slate-200">
          {{ ticket.outcome_reason.label }}
        </span>
      </div>
      <div
        v-if="ticket.outcome_note"
        class="flex flex-col flex-1 min-w-[12rem]"
      >
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.NOTE') }}
        </span>
        <span class="text-sm text-slate-700 dark:text-slate-200">
          {{ ticket.outcome_note }}
        </span>
      </div>
      <p class="w-full m-0 text-xs text-slate-400 dark:text-slate-500">
        {{ $t('CASE_TICKETS.COMMERCIAL.PANEL.FROZEN') }}
      </p>
    </div>

    <!-- Abierta: edición en línea -->
    <form
      v-else
      class="flex flex-wrap items-end gap-3 [&_input]:!mb-0"
      @submit.prevent="save"
    >
      <label class="flex flex-col gap-1 w-36">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.AMOUNT') }}
        </span>
        <input
          v-model="draft.amount"
          type="number"
          min="0"
          step="0.01"
          class="h-8 text-sm"
        />
      </label>
      <label class="flex flex-col w-20 gap-1">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.CURRENCY') }}
        </span>
        <input
          v-model="draft.currency"
          type="text"
          maxlength="3"
          class="h-8 text-sm uppercase"
        />
      </label>
      <label class="flex flex-col gap-1 w-40">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.EXPECTED_CLOSE') }}
        </span>
        <input
          v-model="draft.expected_close_at"
          type="date"
          class="h-8 text-sm"
        />
      </label>
      <label
        class="flex flex-col w-24 gap-1"
        :title="$t('CASE_TICKETS.COMMERCIAL.PANEL.PROBABILITY_HINT')"
      >
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.PROBABILITY') }} %
        </span>
        <input
          v-model="draft.probability"
          type="number"
          min="0"
          max="100"
          step="1"
          class="h-8 text-sm"
        />
      </label>
      <div class="flex flex-col gap-1">
        <span class="text-xs uppercase text-slate-400 dark:text-slate-500">
          {{ $t('CASE_TICKETS.COMMERCIAL.FIELDS.WEIGHTED') }}
        </span>
        <span
          class="flex items-center h-8 text-sm font-semibold text-slate-700 dark:text-slate-200"
        >
          {{ weighted }}
        </span>
      </div>
      <div v-if="isDirty" class="flex gap-2 ml-auto">
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          type="button"
          @click="discard"
        >
          {{ $t('CASE_TICKETS.COMMERCIAL.PANEL.CANCEL') }}
        </woot-button>
        <woot-button size="small" type="submit" :is-loading="isSaving">
          {{ $t('CASE_TICKETS.COMMERCIAL.PANEL.SAVE') }}
        </woot-button>
      </div>
    </form>
  </div>
</template>
