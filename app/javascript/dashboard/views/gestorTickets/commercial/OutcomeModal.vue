<!--
  @tickets_cases — Plan-Clase-Comercial F4
  Cierre de una oportunidad: Ganada / Perdida / Cancelada. Las tres piden un
  motivo del catálogo si lo hay; sin catálogo, Perdida y Cancelada piden la nota.
  La regla la valida el backend (CaseTicket#validate_outcome!); aquí solo se guía.
  Emite `confirm` con { outcome, outcome_reason_id, outcome_note }; quien lo
  abre decide si va por /outcome (detalle) o por /move (Kanban).
-->
<script>
import CaseOutcomeReasonsAPI from 'dashboard/api/caseOutcomeReasons';
import { OUTCOMES } from 'dashboard/helper/caseCommercial';

export default {
  name: 'OutcomeModal',
  props: {
    show: { type: Boolean, default: false },
    folio: { type: String, default: '' },
    // Resultado ya decidido (botón o columna); null = el agente lo elige.
    outcome: { type: String, default: null },
    isSaving: { type: Boolean, default: false },
  },
  emits: ['close', 'confirm'],
  data() {
    return {
      result: this.outcome || 'won',
      reasonId: '',
      note: '',
      reasons: [],
    };
  },
  computed: {
    outcomes() {
      return OUTCOMES;
    },
    reasonsForResult() {
      return this.reasons.filter(r => r.outcome === this.result && r.active);
    },
    needsReason() {
      return this.reasonsForResult.length > 0;
    },
    needsNote() {
      return this.result !== 'won' && !this.reasonsForResult.length;
    },
    canConfirm() {
      if (this.needsReason) return !!this.reasonId;
      if (this.needsNote) return !!this.note.trim();
      return true;
    },
  },
  watch: {
    result() {
      this.reasonId = '';
    },
  },
  async mounted() {
    try {
      const { data } = await CaseOutcomeReasonsAPI.get();
      this.reasons = data.case_outcome_reasons || [];
    } catch (_e) {
      this.reasons = [];
    }
  },
  methods: {
    outcomeLabel(key) {
      return this.$t(`CASE_TICKETS.COMMERCIAL.OUTCOMES.${key}`);
    },
    submit() {
      if (!this.canConfirm) return;
      this.$emit('confirm', {
        outcome: this.result,
        outcome_reason_id: this.reasonId || undefined,
        outcome_note: this.note.trim() || undefined,
      });
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="small">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="
          $t('CASE_TICKETS.COMMERCIAL.OUTCOME_MODAL.TITLE', { folio })
        "
      />
      <form
        class="flex flex-col self-stretch w-full gap-4 pb-8"
        @submit.prevent="submit"
      >
        <div class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            {{ $t('CASE_TICKETS.COMMERCIAL.OUTCOME_MODAL.RESULT') }}
          </span>
          <div class="flex gap-2">
            <button
              v-for="o in outcomes"
              :key="o"
              type="button"
              class="flex-1 px-3 py-2 text-sm font-medium border rounded-lg"
              :class="
                result === o
                  ? 'border-woot-500 bg-woot-50 text-woot-700 dark:bg-woot-800/30 dark:text-woot-200'
                  : 'border-slate-100 text-slate-600 dark:border-slate-700 dark:text-slate-300'
              "
              :disabled="!!outcome && outcome !== o"
              @click="result = o"
            >
              {{ outcomeLabel(o) }}
            </button>
          </div>
        </div>

        <p
          v-if="result === 'won'"
          class="m-0 text-sm text-slate-500 dark:text-slate-400"
        >
          {{ $t('CASE_TICKETS.COMMERCIAL.OUTCOME_MODAL.WON_HINT') }}
        </p>

        <label v-if="reasonsForResult.length" class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            {{ $t('CASE_TICKETS.COMMERCIAL.OUTCOME_MODAL.REASON') }}
          </span>
          <select v-model="reasonId" class="input !mb-0">
            <option value="">
              {{
                $t('CASE_TICKETS.COMMERCIAL.OUTCOME_MODAL.REASON_PLACEHOLDER')
              }}
            </option>
            <option v-for="r in reasonsForResult" :key="r.id" :value="r.id">
              {{ r.label }}
            </option>
          </select>
        </label>
        <p
          v-else-if="needsNote"
          class="m-0 text-sm text-amber-700 dark:text-amber-300"
        >
          {{ $t('CASE_TICKETS.COMMERCIAL.OUTCOME_MODAL.NO_REASONS') }}
        </p>

        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            {{
              needsNote
                ? $t('CASE_TICKETS.COMMERCIAL.OUTCOME_MODAL.NOTE_REQUIRED')
                : $t('CASE_TICKETS.COMMERCIAL.OUTCOME_MODAL.NOTE')
            }}
          </span>
          <textarea
            v-model="note"
            class="input !mb-0"
            rows="3"
            :placeholder="
              $t('CASE_TICKETS.COMMERCIAL.OUTCOME_MODAL.NOTE_PLACEHOLDER')
            "
          />
        </label>

        <div class="flex justify-end gap-2 mt-2">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            type="button"
            @click="$emit('close')"
          >
            {{ $t('CASE_TICKETS.COMMERCIAL.OUTCOME_MODAL.CANCEL') }}
          </woot-button>
          <woot-button
            type="submit"
            :is-loading="isSaving"
            :disabled="!canConfirm"
          >
            {{ $t('CASE_TICKETS.COMMERCIAL.OUTCOME_MODAL.CONFIRM') }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>
