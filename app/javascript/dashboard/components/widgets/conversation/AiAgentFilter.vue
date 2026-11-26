<!--
  «Agente IA» en la lista de conversaciones (Plan-Agente-IA-en-Conversaciones): Todos · Sin agente IA · Con agente IA ·
  un agente (con cuántas tiene en curso). Se combina con Mías / Sin asignar / Todas. Si no está en «Todos», el botón se
  marca de color (para que no parezca que faltan conversaciones). v-model: '' (Ambos) | 'with' (Solo agente IA: sin responsable) | 'without' (Atendidos por personas: con responsable) | función.
-->
<script>
import { mapGetters } from 'vuex';

// Las funciones de los agentes de IA, en el orden en que salen.
export const AI_AGENT_FUNCTIONS = [
  'customers',
  'prospects',
  'campaign_seller',
  'follow_up',
  'collections',
  'custom',
];

export default {
  name: 'AiAgentFilter',
  model: { prop: 'value', event: 'change' },
  props: {
    value: { type: String, default: '' },
  },
  emits: ['change'],
  computed: {
    ...mapGetters({ stats: 'conversationStats/getStats' }),
    counts() {
      return this.stats.aiAgents || {};
    },
    // Los agentes que tienen algo en curso, más el elegido (aunque ya no tenga).
    agents() {
      const keys = Object.keys(this.counts);
      const known = AI_AGENT_FUNCTIONS.filter(
        k => keys.includes(k) || k === this.value
      );
      return [...known, ...keys.filter(k => !AI_AGENT_FUNCTIONS.includes(k))];
    },
    active() {
      return !!this.value;
    },
    // El combo es angosto: al pasar el mouse dice la opción completa.
    selectedText() {
      if (!this.value) return this.t('ALL');
      if (this.value === 'with') return this.t('WITH');
      if (this.value === 'without') return this.t('WITHOUT');
      return this.label(this.value);
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`CONVERSATION.AI_AGENT_FILTER.${key}`, params);
    },
    label(key) {
      return this.$te(`CONVERSATION.AI_AGENT_FUNCTIONS.${key}`)
        ? this.$t(`CONVERSATION.AI_AGENT_FUNCTIONS.${key}`)
        : key;
    },
  },
};
</script>

<template>
  <div class="flex justify-end w-full min-w-0" data-test="ai-agent-filter">
    <select
      :value="value"
      class="!mb-0 !h-7 !py-0 !pl-2 !pr-6 !w-full max-w-[8.5rem] min-w-0 truncate text-xs rounded-md"
      :class="
        active
          ? '!border-violet-400 !bg-violet-50 text-violet-800 dark:!bg-violet-900/30 dark:text-violet-200'
          : ''
      "
      :aria-label="t('LABEL')"
      :title="`${t('LABEL')}: ${selectedText}`"
      @change="$emit('change', $event.target.value)"
    >
      <option value="">{{ t('ALL') }}</option>
      <option value="with">{{ t('WITH') }}</option>
      <option value="without">{{ t('WITHOUT') }}</option>
      <option v-for="key in agents" :key="key" :value="key">
        {{ label(key) }}
        <template v-if="counts[key]">({{ counts[key] }})</template>
      </option>
    </select>
  </div>
</template>
