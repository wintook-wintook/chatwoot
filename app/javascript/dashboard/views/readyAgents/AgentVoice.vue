<!--
  «Cómo habla tu empresa» dentro de cada agente listo: un botón abre lo que tiene la empresa y, campo por
  campo, se elige «Como la empresa» (si cambia allá, cambia aquí) o «Solo para este agente» (se edita aquí y
  queda solo para él; Motor2::Config#voice). v-model: solo los campos que este agente cambió.
-->
<script>
import AiVoiceAPI from 'dashboard/api/aiVoice';
import { VOICE_FIELDS } from './CompanyVoice.vue';

export default {
  name: 'AgentVoice',
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Object, default: () => ({}) },
  },
  emits: ['input'],
  data() {
    return { open: false, company: {}, loaded: false };
  },
  computed: {
    fields() {
      return VOICE_FIELDS;
    },
    ownCount() {
      return Object.keys(this.value || {}).filter(k => this.isOwn(k)).length;
    },
    companyCount() {
      return VOICE_FIELDS.filter(k => (this.company[k] || '').trim()).length;
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`READY_AGENTS.AGENT_VOICE.${key}`, params);
    },
    label(key) {
      return this.$t(`AI_VOICE.FIELDS.${key.toUpperCase()}.LABEL`);
    },
    async toggle() {
      this.open = !this.open;
      if (this.open && !this.loaded) {
        try {
          const { data } = await AiVoiceAPI.get();
          this.company = data.voice || {};
        } finally {
          this.loaded = true;
        }
      }
    },
    isOwn(key) {
      return Object.prototype.hasOwnProperty.call(this.value || {}, key);
    },
    // «Solo para este agente» arranca con lo de la empresa, para cambiarlo.
    useOwn(key, own) {
      const next = { ...(this.value || {}) };
      if (own) next[key] = next[key] ?? this.company[key] ?? '';
      else delete next[key];
      this.$emit('input', next);
    },
    setOwn(key, text) {
      this.$emit('input', { ...(this.value || {}), [key]: text });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <div class="flex flex-wrap items-center gap-2">
      <woot-button
        size="small"
        variant="smooth"
        color-scheme="secondary"
        icon="chat"
        @click="toggle"
      >
        {{ t('BUTTON') }}
      </woot-button>
      <span class="text-xs text-slate-500">
        {{ ownCount ? t('OWN', { n: ownCount }) : t('ALL_COMPANY') }}
      </span>
    </div>
    <div
      v-if="open"
      class="flex flex-col gap-3 p-3 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <p class="m-0 text-xs text-slate-500">{{ t('HINT') }}</p>
      <p v-if="loaded && !companyCount" class="m-0 text-xs text-amber-700">
        {{ t('EMPTY') }}
      </p>
      <div v-for="key in fields" :key="key" class="flex flex-col gap-1">
        <div class="flex flex-wrap items-center gap-3 text-sm">
          <span class="font-medium">{{ label(key) }}</span>
          <label class="flex items-center gap-1 text-xs">
            <input
              type="radio"
              class="!m-0"
              :checked="!isOwn(key)"
              @change="useOwn(key, false)"
            />
            {{ t('COMPANY') }}
          </label>
          <label class="flex items-center gap-1 text-xs">
            <input
              type="radio"
              class="!m-0"
              :checked="isOwn(key)"
              @change="useOwn(key, true)"
            />
            {{ t('ONLY_HERE') }}
          </label>
        </div>
        <textarea
          v-if="isOwn(key)"
          rows="2"
          maxlength="600"
          :value="value[key]"
          @input="setOwn(key, $event.target.value)"
        />
        <p v-else class="m-0 text-xs text-slate-600 dark:text-slate-300">
          {{ (company[key] || '').trim() || t('NOT_SET') }}
        </p>
      </div>
    </div>
  </div>
</template>
