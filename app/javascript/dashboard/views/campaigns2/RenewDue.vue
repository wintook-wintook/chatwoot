<!--
  Campaña con IA · Recordar — paso «Qué recuerdas»: de qué contratos (todos o un tipo) y en qué días antes de que
  venzan salen los mensajes (hasta 4: de fábrica 7, 1 y el día). Cada contacto recibe los suyos según SU fecha
  (TrackingCampaigns::RenewEnroll + ContactTrackings::DueSchedule); la campaña queda prendida y cada mañana mete a
  los contratos que ya entran. Debajo: el canal y la muestra (quién y qué le vence).
  .sync: brief (renew_source { contract_type_id, offsets })
-->
<script>
const MAX = 4;

export default {
  name: 'RenewDue',
  props: {
    brief: { type: Object, required: true },
    contractTypes: { type: Array, default: () => [] },
  },
  emits: ['update:brief'],
  computed: {
    source() {
      return { offsets: [7, 1, 0], ...(this.brief.renew_source || {}) };
    },
    offsets() {
      return this.source.offsets || [];
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CAMPAIGNS2.RENEW_FLOW.${key}`, params);
    },
    set(field, value) {
      this.$emit('update:brief', {
        ...this.brief,
        renew_source: { ...this.source, [field]: value },
      });
    },
    setOffset(index, value) {
      const list = [...this.offsets];
      list[index] = Math.max(0, Math.min(60, Number(value) || 0));
      this.set(
        'offsets',
        [...new Set(list)].sort((a, b) => b - a)
      );
    },
    add() {
      if (this.offsets.length >= MAX) return;
      const next = Math.max(...this.offsets, 0) + 7;
      this.set(
        'offsets',
        [next, ...this.offsets].sort((a, b) => b - a)
      );
    },
    remove(index) {
      if (this.offsets.length <= 1) return;
      this.set(
        'offsets',
        this.offsets.filter((_d, i) => i !== index)
      );
    },
    label(days) {
      if (days === 0) return this.t('ON_DAY');
      return days === 1
        ? this.t('ONE_DAY')
        : this.t('DAYS_BEFORE', { n: days });
    },
  },
};
</script>

<template>
  <section
    class="flex flex-col gap-3 p-3 border rounded-md border-slate-100 dark:border-slate-700"
  >
    <label class="block">
      <span class="field-label">{{ t('TYPE') }}</span>
      <select
        :value="source.contract_type_id || ''"
        class="!mb-0"
        @change="set('contract_type_id', $event.target.value || null)"
      >
        <option value="">{{ t('ALL_TYPES') }}</option>
        <option v-for="type in contractTypes" :key="type.id" :value="type.id">
          {{ type.name }}
        </option>
      </select>
    </label>
    <div class="flex flex-col gap-1">
      <span class="field-label">{{ t('WHEN_TITLE') }}</span>
      <div class="flex flex-wrap items-center gap-2">
        <span
          v-for="(days, index) in offsets"
          :key="index"
          class="inline-flex items-center gap-1 px-2 py-1 text-sm rounded-md bg-slate-25 dark:bg-slate-800"
        >
          <input
            :value="days"
            type="number"
            min="0"
            max="60"
            class="!mb-0 !h-7 !py-0 !w-14 text-sm"
            @change="setOffset(index, $event.target.value)"
          />
          <span class="text-xs text-slate-600">{{ label(days) }}</span>
          <button
            v-if="offsets.length > 1"
            type="button"
            class="text-slate-400 hover:text-red-600"
            :aria-label="t('REMOVE')"
            @click="remove(index)"
          >
            <fluent-icon icon="dismiss" size="12" />
          </button>
        </span>
        <button
          v-if="offsets.length < 4"
          type="button"
          class="text-sm text-woot-600 hover:underline"
          @click="add"
        >
          {{ t('ADD') }}
        </button>
      </div>
      <p class="m-0 text-xs text-slate-500">{{ t('WHEN_HINT') }}</p>
    </div>
  </section>
</template>
