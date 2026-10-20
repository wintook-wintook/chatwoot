<!--
  @tickets_cases — Plan-Clase-Comercial F4
  Posponer una oportunidad hasta una fecha. Ese día Cases::ResumePostponedJob la
  regresa a la etapa donde estaba. Emite `confirm` con
  { postponed_until, postpone_reason_id, reason }. El motivo del catálogo es
  obligatorio si la cuenta tiene motivos de pospuesta activos (lo valida el backend).
-->
<script>
import CaseOutcomeReasonsAPI from 'dashboard/api/caseOutcomeReasons';
import { isoDayFromToday } from 'dashboard/helper/caseCommercial';

export default {
  name: 'PostponeModal',
  props: {
    show: { type: Boolean, default: false },
    folio: { type: String, default: '' },
    // Fecha actual de «retomar el» (al cambiar una pospuesta).
    current: { type: String, default: '' },
    isSaving: { type: Boolean, default: false },
  },
  emits: ['close', 'confirm'],
  data() {
    return {
      until: this.current || isoDayFromToday(7),
      reasonId: '',
      reason: '',
      reasons: [],
    };
  },
  computed: {
    minDay() {
      return isoDayFromToday(1);
    },
    canConfirm() {
      if (this.reasons.length && !this.reasonId) return false;
      return !!this.until && this.until >= this.minDay;
    },
  },
  async mounted() {
    try {
      const { data } = await CaseOutcomeReasonsAPI.get();
      this.reasons = (data.case_outcome_reasons || []).filter(
        r => r.outcome === 'postponed' && r.active
      );
    } catch (_e) {
      this.reasons = [];
    }
  },
  methods: {
    submit() {
      if (!this.canConfirm) return;
      this.$emit('confirm', {
        postponed_until: this.until,
        postpone_reason_id: this.reasonId || undefined,
        reason: this.reason.trim() || undefined,
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
          $t('CASE_TICKETS.COMMERCIAL.POSTPONE_MODAL.TITLE', { folio })
        "
      />
      <form
        class="flex flex-col self-stretch w-full gap-4 pb-8"
        @submit.prevent="submit"
      >
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            {{ $t('CASE_TICKETS.COMMERCIAL.POSTPONE_MODAL.UNTIL') }}
          </span>
          <input v-model="until" type="date" class="!mb-0" :min="minDay" />
        </label>
        <label v-if="reasons.length" class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            {{ $t('CASE_TICKETS.COMMERCIAL.POSTPONE_MODAL.REASON_CATALOG') }}
          </span>
          <select v-model="reasonId" class="input !mb-0">
            <option value="">
              {{
                $t('CASE_TICKETS.COMMERCIAL.OUTCOME_MODAL.REASON_PLACEHOLDER')
              }}
            </option>
            <option v-for="r in reasons" :key="r.id" :value="r.id">
              {{ r.label }}
            </option>
          </select>
        </label>
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            {{ $t('CASE_TICKETS.COMMERCIAL.POSTPONE_MODAL.REASON') }}
          </span>
          <textarea
            v-model="reason"
            class="input !mb-0"
            rows="2"
            :placeholder="
              $t('CASE_TICKETS.COMMERCIAL.POSTPONE_MODAL.REASON_PLACEHOLDER')
            "
          />
        </label>
        <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('CASE_TICKETS.COMMERCIAL.POSTPONE_MODAL.HINT') }}
        </p>
        <div class="flex justify-end gap-2 mt-2">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            type="button"
            @click="$emit('close')"
          >
            {{ $t('CASE_TICKETS.COMMERCIAL.POSTPONE_MODAL.CANCEL') }}
          </woot-button>
          <woot-button
            type="submit"
            :is-loading="isSaving"
            :disabled="!canConfirm"
          >
            {{ $t('CASE_TICKETS.COMMERCIAL.POSTPONE_MODAL.CONFIRM') }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>
