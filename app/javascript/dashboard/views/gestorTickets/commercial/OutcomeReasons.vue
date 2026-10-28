<!--
  @tickets_cases — Plan-Clase-Comercial F4
  Catálogo de motivos de cierre (ganada, perdida, pospuesta, cancelada). Antes era
  una sección de CommercialSettings.vue; ahora es la página Catálogos › Motivos de
  cierre (OutcomeReasonsConfig.vue).
-->
<script>
import CaseOutcomeReasonsAPI from 'dashboard/api/caseOutcomeReasons';

// Mismo orden que los resultados de la Lista: Ganadas · Perdidas · Pospuestas · Canceladas.
const REASON_OUTCOMES = ['won', 'lost', 'postponed', 'cancelled'];

export default {
  name: 'OutcomeReasons',
  data() {
    return {
      reasons: [],
      newLabels: { won: '', lost: '', postponed: '', cancelled: '' },
      isLoadingReasons: false,
    };
  },
  computed: {
    reasonOutcomes() {
      return REASON_OUTCOMES;
    },
  },
  mounted() {
    this.fetchReasons();
  },
  methods: {
    reasonsFor(outcome) {
      return this.reasons.filter(r => r.outcome === outcome);
    },
    toast(key, type) {
      this.$emitter.emit('newToastMessage', {
        message: this.$t(`CASE_TICKETS.COMMERCIAL.SETTINGS.${key}`),
        ...(type ? { type } : {}),
      });
    },
    async fetchReasons() {
      this.isLoadingReasons = true;
      try {
        const { data } = await CaseOutcomeReasonsAPI.get();
        this.reasons = data.case_outcome_reasons || [];
      } finally {
        this.isLoadingReasons = false;
      }
    },
    async addReason(outcome) {
      const label = this.newLabels[outcome].trim();
      if (!label) return;
      try {
        await CaseOutcomeReasonsAPI.create({
          case_outcome_reason: { outcome, label },
        });
        this.newLabels[outcome] = '';
        await this.fetchReasons();
        this.toast('SAVED');
      } catch (_e) {
        this.toast('ERROR', 'error');
      }
    },
    async updateReason(reason, changes) {
      try {
        await CaseOutcomeReasonsAPI.update(reason.id, {
          case_outcome_reason: changes,
        });
        await this.fetchReasons();
        this.toast('SAVED');
      } catch (_e) {
        this.toast('ERROR', 'error');
      }
    },
    renameReason(reason, event) {
      const label = event.target.value.trim();
      if (!label || label === reason.label) {
        event.target.value = reason.label;
        return;
      }
      this.updateReason(reason, { label });
    },
    async deleteReason(reason) {
      try {
        await CaseOutcomeReasonsAPI.delete(reason.id);
        await this.fetchReasons();
        this.toast('DELETED');
      } catch (_e) {
        this.toast('ERROR', 'error');
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col gap-3 p-4 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
  >
    <p class="m-0 text-sm text-slate-500 dark:text-slate-400">
      {{ $t('CASE_TICKETS.COMMERCIAL.SETTINGS.REASONS_DESC') }}
    </p>

    <div class="grid gap-4 md:grid-cols-2">
      <div
        v-for="outcome in reasonOutcomes"
        :key="outcome"
        class="flex flex-col gap-2"
      >
        <span
          class="text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
        >
          {{ $t(`CASE_TICKETS.COMMERCIAL.SETTINGS.GROUPS.${outcome}`) }}
        </span>
        <p
          v-if="!isLoadingReasons && !reasonsFor(outcome).length"
          class="m-0 text-sm text-slate-400 dark:text-slate-500"
        >
          {{ $t('CASE_TICKETS.COMMERCIAL.SETTINGS.EMPTY') }}
        </p>
        <div
          v-for="reason in reasonsFor(outcome)"
          :key="reason.id"
          class="flex items-center gap-2"
        >
          <input
            type="text"
            class="flex-1 h-8 !mb-0 text-sm"
            :class="reason.active ? '' : 'opacity-50'"
            :value="reason.label"
            maxlength="100"
            @change="renameReason(reason, $event)"
          />
          <label
            class="flex items-center gap-1 text-xs text-slate-500 dark:text-slate-400"
          >
            <input
              type="checkbox"
              class="!mb-0"
              :checked="reason.active"
              @change="updateReason(reason, { active: !reason.active })"
            />
            {{ $t('CASE_TICKETS.COMMERCIAL.SETTINGS.ACTIVE') }}
          </label>
          <woot-button
            size="tiny"
            variant="clear"
            color-scheme="alert"
            icon="delete"
            :title="$t('CASE_TICKETS.COMMERCIAL.SETTINGS.DELETE')"
            @click="deleteReason(reason)"
          />
        </div>
        <form class="flex gap-2" @submit.prevent="addReason(outcome)">
          <input
            v-model="newLabels[outcome]"
            type="text"
            maxlength="100"
            class="flex-1 h-8 !mb-0 text-sm"
            :placeholder="
              $t('CASE_TICKETS.COMMERCIAL.SETTINGS.LABEL_PLACEHOLDER')
            "
          />
          <woot-button
            size="small"
            variant="smooth"
            icon="add"
            type="submit"
            :disabled="!newLabels[outcome].trim()"
          >
            {{ $t('CASE_TICKETS.COMMERCIAL.SETTINGS.ADD') }}
          </woot-button>
        </form>
      </div>
    </div>
  </div>
</template>
