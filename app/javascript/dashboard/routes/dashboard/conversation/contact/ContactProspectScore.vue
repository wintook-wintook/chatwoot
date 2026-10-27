<!--
  prospeccion P4 (D19) — la puntuación del contacto en su campaña de Prospección más
  reciente, solo lectura. Sin puntuación no se muestra nada.
-->
<script>
import ContactProspectScoreAPI from 'dashboard/api/contactProspectScore';

export default {
  name: 'ContactProspectScore',
  props: {
    contactId: { type: Number, required: true },
  },
  data() {
    return { result: null };
  },
  computed: {
    hasScore() {
      return !!this.result && this.result.score !== undefined;
    },
    breakdown() {
      const parts = (this.result && this.result.parts) || {};
      return Object.keys(parts)
        .map(key => {
          const points = parts[key] > 0 ? `+${parts[key]}` : parts[key];
          const label = this.$t(
            `TRACKING_CAMPAIGN_DETAIL.SCORING.CRITERIA.${key}`
          );
          return `${label} ${points}`;
        })
        .join(' · ');
    },
    scoreClass() {
      const score = this.hasScore ? this.result.score : 0;
      if (score >= 60) return 'text-red-500 dark:text-red-400';
      if (score >= 30) return 'text-amber-700 dark:text-amber-500';
      return 'text-slate-600 dark:text-slate-300';
    },
  },
  watch: {
    contactId: { immediate: true, handler: 'load' },
  },
  methods: {
    async load() {
      try {
        const { data } = await ContactProspectScoreAPI.show(this.contactId);
        this.result = data;
      } catch {
        this.result = null;
      }
    },
  },
};
</script>

<template>
  <div class="w-full">
    <div
      v-if="hasScore"
      v-tooltip.left="breakdown"
      class="flex items-center w-full gap-2 mt-2 text-sm cursor-help"
    >
      <span class="text-slate-600 dark:text-slate-300">
        {{ $t('TRACKING_CAMPAIGN_DETAIL.SCORING.TITLE') }}
      </span>
      <span class="font-semibold" :class="scoreClass">{{ result.score }}</span>
      <span class="text-xs truncate text-slate-500 dark:text-slate-400">
        {{ result.campaign_name }}
      </span>
    </div>
  </div>
</template>
