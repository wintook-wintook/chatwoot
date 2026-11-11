<!--
  @tickets_cases — Plan-Clase-Comercial F4
  Franja «Datos comerciales» del detalle de una oportunidad: monto, moneda,
  cierre estimado, probabilidad y la casilla «Comprometida por el cliente»
  (Plan-Metricas-Comercial: marcada, el cierre es la fecha que prometió el
  cliente). Se guardan juntos con PATCH /case_tickets/:id; el backend deja
  `amount_changed` / `commitment_changed` en el historial.
  Plan Actividad del caso (P3) — en UNA línea para no quitarle espacio a las
  pestañas; el lápiz (o un clic en la línea) abre la ventanita para editarlos.
  Cerrada, se congela y muestra el resultado con su motivo y nota.
-->
<script>
import {
  COMMITTED_BADGE,
  OUTCOME_BADGE,
  POSTPONED_BADGE,
  PROMISE_OVERDUE_BADGE,
  formatMoney,
  formatDay,
  isOpenCommitted,
  isoDayFromToday,
  promiseOverdue,
} from 'dashboard/helper/caseCommercial';
import CommitmentFields from './CommitmentFields.vue';

const FIELDS = [
  'amount',
  'currency',
  'expected_close_at',
  'probability',
  'committed',
  'commit_note',
];

export default {
  name: 'CommercialPanel',
  components: { CommitmentFields },
  props: {
    ticket: { type: Object, required: true },
  },
  emits: ['updated', 'editPostpone'],
  data() {
    return { draft: this.fromTicket(), isSaving: false, editing: false };
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
    probabilityText() {
      const pct = this.ticket.probability;
      return pct === null || pct === undefined ? '—' : pct;
    },
    // Cierre estimado ya pasado y la oportunidad sigue abierta.
    closeOverdue() {
      const day = this.ticket.expected_close_at;
      return !this.isFrozen && !!day && day < isoDayFromToday(0);
    },
    outcomeBadge() {
      return OUTCOME_BADGE[this.ticket.outcome] || '';
    },
    postponedBadge() {
      return POSTPONED_BADGE;
    },
    // «Comprometida · 24 oct» (o «Promesa vencida») mientras siga abierta.
    commitment() {
      if (!isOpenCommitted(this.ticket)) return null;
      const overdue = promiseOverdue(this.ticket, isoDayFromToday(0));
      return {
        key: overdue ? 'PROMISE_OVERDUE' : 'COMMITTED_ON',
        cls: overdue ? PROMISE_OVERDUE_BADGE : COMMITTED_BADGE,
      };
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
        committed: !!t.committed,
        commit_note: t.commit_note || '',
      };
    },
    money(amount, currency) {
      return formatMoney(amount, currency);
    },
    day(value) {
      return formatDay(value);
    },
    editPostpone() {
      if (this.isFrozen) return;
      this.editing = false;
      this.$emit('editPostpone');
    },
    openEditor() {
      if (this.isFrozen) return;
      this.draft = this.fromTicket();
      this.editing = true;
    },
    discard() {
      this.draft = this.fromTicket();
      this.editing = false;
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
          committed: this.draft.committed,
          commit_note: this.draft.commit_note.trim() || null,
        };
        await this.$store.dispatch('caseTickets/updateCommercialData', {
          ticketId: this.ticket.id,
          data,
        });
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.COMMERCIAL.PANEL.SAVED'),
        });
        this.editing = false;
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
    class="flex flex-wrap items-center flex-shrink-0 px-6 py-2 border-b gap-x-3 gap-y-1 bg-violet-50 dark:bg-slate-800/50 border-slate-50 dark:border-slate-800/50"
  >
    <span
      class="text-xs font-semibold tracking-wide uppercase text-violet-700 dark:text-violet-300"
    >
      {{ $t('CASE_TICKETS.COMMERCIAL.PANEL.SHORT_TITLE') }}
    </span>

    <!-- Una línea: monto · probabilidad → ponderado · cierre (y el resultado si cerró) -->
    <button
      type="button"
      class="flex flex-wrap items-baseline min-w-0 p-0 text-sm text-left bg-transparent border-0 gap-x-1.5 text-slate-700 dark:text-slate-200"
      :class="isFrozen ? 'cursor-default' : 'cursor-pointer hover:underline'"
      :title="isFrozen ? $t('CASE_TICKETS.COMMERCIAL.PANEL.FROZEN') : ''"
      @click="openEditor"
    >
      <span class="font-semibold text-slate-800 dark:text-slate-100">
        {{ money(ticket.amount, ticket.currency) }}
      </span>
      <template v-if="!isFrozen">
        <span class="text-slate-400">·</span>
        <span>
          {{
            $t('CASE_TICKETS.COMMERCIAL.PANEL.WEIGHTED_LINE', {
              pct: probabilityText,
              weighted,
            })
          }}
        </span>
        <span class="text-slate-400">·</span>
        <span :class="closeOverdue ? 'text-red-600 dark:text-red-400' : ''">
          {{
            $t('CASE_TICKETS.COMMERCIAL.PANEL.CLOSE_LINE', {
              date: day(ticket.expected_close_at),
            })
          }}<template v-if="closeOverdue">
            ({{ $t('CASE_TICKETS.COMMERCIAL.PANEL.OVERDUE') }})</template
          >
        </span>
      </template>
      <template v-else>
        <span class="text-slate-400">·</span>
        <span>{{ day(ticket.outcome_at) }}</span>
        <template v-if="ticket.outcome_reason">
          <span class="text-slate-400">·</span>
          <span>{{ ticket.outcome_reason.label }}</span>
        </template>
        <template v-if="ticket.outcome_note">
          <span class="text-slate-400">·</span>
          <span class="max-w-md truncate">{{ ticket.outcome_note }}</span>
        </template>
      </template>
    </button>

    <span
      v-if="ticket.outcome"
      class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded"
      :class="outcomeBadge"
    >
      {{ $t(`CASE_TICKETS.COMMERCIAL.OUTCOMES.${ticket.outcome}`) }}
    </span>
    <!-- Pospuesta: clic (o su lapicito) para cambiar la fecha, el motivo o el comentario -->
    <button
      v-if="ticket.is_postponed"
      type="button"
      class="inline-flex items-center gap-1 px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded border-0"
      :class="[postponedBadge, isFrozen ? 'cursor-default' : 'cursor-pointer']"
      :title="
        isFrozen ? '' : $t('CASE_TICKETS.COMMERCIAL.ACTIONS.CHANGE_POSTPONE')
      "
      @click="editPostpone"
    >
      {{
        $t('CASE_TICKETS.COMMERCIAL.POSTPONED_UNTIL', {
          date: day(ticket.postponed_until),
        })
      }}<template v-if="ticket.postpone_reason">
        · {{ ticket.postpone_reason.label }}</template
      >
      <fluent-icon v-if="!isFrozen" icon="edit" size="11" />
    </button>
    <span
      v-if="commitment"
      class="px-1.5 py-0.5 text-[11px] font-medium uppercase tracking-wide rounded"
      :class="commitment.cls"
      :title="ticket.commit_note || ''"
    >
      {{
        $t(`CASE_TICKETS.COMMERCIAL.COMMITMENT.${commitment.key}`, {
          date: day(ticket.expected_close_at),
        })
      }}
    </span>
    <woot-button
      v-if="!isFrozen"
      size="tiny"
      variant="clear"
      color-scheme="secondary"
      icon="edit"
      :title="$t('CASE_TICKETS.COMMERCIAL.PANEL.EDIT')"
      @click="openEditor"
    />

    <!-- Editar: los mismos campos de siempre en una ventanita -->
    <woot-modal :show="editing" :on-close="discard" size="medium">
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="$t('CASE_TICKETS.COMMERCIAL.PANEL.TITLE')"
        />
        <!-- Pospuesta: se cambia en su propia ventana (fecha, motivo y comentario). -->
        <p
          v-if="ticket.is_postponed"
          class="flex flex-wrap items-center gap-2 px-8 m-0 mb-3 text-sm text-slate-600 dark:text-slate-300"
        >
          {{
            $t('CASE_TICKETS.COMMERCIAL.POSTPONED_UNTIL', {
              date: day(ticket.postponed_until),
            })
          }}<template v-if="ticket.postpone_reason">
            · {{ ticket.postpone_reason.label }}</template
          >
          <woot-button size="tiny" variant="link" @click="editPostpone">
            {{ $t('CASE_TICKETS.COMMERCIAL.ACTIONS.CHANGE_POSTPONE') }}
          </woot-button>
        </p>
        <form
          class="flex flex-wrap items-end gap-3 px-8 pb-8 [&_input]:!mb-0"
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
              {{
                draft.committed
                  ? $t('CASE_TICKETS.COMMERCIAL.COMMITMENT.DATE')
                  : $t('CASE_TICKETS.COMMERCIAL.FIELDS.EXPECTED_CLOSE')
              }}
            </span>
            <input
              v-model="draft.expected_close_at"
              type="date"
              class="h-8 text-sm"
              :required="draft.committed"
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
          <CommitmentFields
            :committed.sync="draft.committed"
            :note.sync="draft.commit_note"
            compact
            class="w-full"
          />
          <div class="flex justify-end w-full gap-2">
            <woot-button
              size="small"
              variant="clear"
              color-scheme="secondary"
              type="button"
              @click="discard"
            >
              {{ $t('CASE_TICKETS.COMMERCIAL.PANEL.CANCEL') }}
            </woot-button>
            <woot-button
              size="small"
              type="submit"
              :is-loading="isSaving"
              :is-disabled="!isDirty"
            >
              {{ $t('CASE_TICKETS.COMMERCIAL.PANEL.SAVE') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>
  </div>
</template>
