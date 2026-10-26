<!--
  Plan-Catalogo-Cotizaciones V1 — marcar una cotización como ganada, perdida,
  pospuesta o cancelada, con los mismos motivos de las oportunidades
  (Ajustes › Motivos). Pospuesta pide hasta cuándo.
-->
<script>
import CaseOutcomeReasonsAPI from 'dashboard/api/caseOutcomeReasons';

export default {
  name: 'QuoteOutcomeModal',
  props: {
    show: { type: Boolean, default: false },
    status: { type: String, required: true },
    isSaving: { type: Boolean, default: false },
  },
  emits: ['close', 'confirm'],
  data() {
    return { reasons: [], reasonId: '', note: '', until: '' };
  },
  computed: {
    reasonsForStatus() {
      return this.reasons.filter(r => r.outcome === this.status && r.active);
    },
    title() {
      return this.$t('QUOTES.OUTCOME.TITLE', {
        status: this.$t(`QUOTES.STATUSES.${this.status}`).toLowerCase(),
      });
    },
  },
  async mounted() {
    const date = new Date();
    date.setDate(date.getDate() + 14);
    this.until = date.toISOString().slice(0, 10);
    try {
      const { data } = await CaseOutcomeReasonsAPI.get();
      this.reasons = data.case_outcome_reasons || [];
    } catch {
      this.reasons = [];
    }
  },
  methods: {
    submit() {
      this.$emit('confirm', {
        reason_id: this.reasonId || undefined,
        note: this.note.trim() || undefined,
        postponed_until: this.status === 'postponed' ? this.until : undefined,
      });
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="small">
    <woot-modal-header :header-title="title" />
    <form
      class="flex flex-col self-stretch w-full gap-2"
      @submit.prevent="submit"
    >
      <label v-if="reasonsForStatus.length">
        {{ $t('QUOTES.OUTCOME.REASON') }}
        <select v-model="reasonId">
          <option value="">{{ $t('QUOTES.OUTCOME.NO_REASON') }}</option>
          <option
            v-for="reason in reasonsForStatus"
            :key="reason.id"
            :value="reason.id"
          >
            {{ reason.label }}
          </option>
        </select>
      </label>
      <label v-if="status === 'postponed'">
        {{ $t('QUOTES.OUTCOME.UNTIL') }}
        <input v-model="until" type="date" />
      </label>
      <label>
        {{ $t('QUOTES.OUTCOME.NOTE') }}
        <textarea v-model="note" rows="3" />
      </label>
      <div class="flex justify-end gap-2">
        <button type="button" class="button clear" @click="$emit('close')">
          {{ $t('QUOTES.OUTCOME.CANCEL') }}
        </button>
        <woot-submit-button
          :loading="isSaving"
          :button-text="$t('QUOTES.OUTCOME.CONFIRM')"
        />
      </div>
    </form>
  </woot-modal>
</template>
