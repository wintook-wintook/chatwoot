<!--
  «Cómo habla tu empresa» dentro de cada agente listo (los tres), con un selector:
    - «Usar el de la empresa»: se ven sus campos (solo lectura); si la empresa lo cambia, el agente también;
    - «Personalizar para este agente»: los campos ya llenos con lo de la empresa, para cambiar lo que quiera; queda solo
      para él (Motor2::Config#voice). Al personalizar, el Tono del agente pasa a «El de Cómo habla tu empresa».
  v-model: los settings del agente (usa voice, voice_mode y tone).
-->
<script>
import AiVoiceAPI from 'dashboard/api/aiVoice';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { VOICE_FIELDS } from './CompanyVoice.vue';

export default {
  name: 'AgentVoice',
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Object, required: true },
  },
  emits: ['input'],
  data() {
    return { company: {}, loaded: false };
  },
  computed: {
    fields() {
      return VOICE_FIELDS;
    },
    voice() {
      return this.value.voice || {};
    },
    // Los de antes (con algo propio y sin modo) también cuentan como personalizados.
    mode() {
      if (this.value.voice_mode) return this.value.voice_mode;
      return Object.values(this.voice).some(v => (v || '').trim())
        ? 'own'
        : 'company';
    },
    companyEmpty() {
      return !VOICE_FIELDS.some(k => (this.company[k] || '').trim());
    },
    companyUrl() {
      return frontendURL(
        `accounts/${this.$route.params.accountId}/tracking-dashboard/company-voice`
      );
    },
  },
  async mounted() {
    try {
      const { data } = await AiVoiceAPI.get();
      this.company = data.voice || {};
    } finally {
      this.loaded = true;
    }
  },
  methods: {
    t(key, params) {
      return this.$t(`READY_AGENTS.AGENT_VOICE.${key}`, params);
    },
    label(key) {
      return this.$t(`AI_VOICE.FIELDS.${key.toUpperCase()}.LABEL`);
    },
    setMode(mode) {
      if (mode === 'own') {
        // Arranca con lo de la empresa (lo que ya tenía personalizado gana) y el tono pasa a ser el de aquí.
        const voice = Object.fromEntries(
          VOICE_FIELDS.map(k => [k, this.voice[k] || this.company[k] || ''])
        );
        this.$emit('input', {
          ...this.value,
          voice_mode: 'own',
          voice,
          tone: 'empresa',
        });
      } else {
        this.$emit('input', {
          ...this.value,
          voice_mode: 'company',
          voice: {},
        });
      }
    },
    setField(key, text) {
      this.$emit('input', {
        ...this.value,
        voice_mode: 'own',
        voice: { ...this.voice, [key]: text },
      });
    },
  },
};
</script>

<template>
  <section
    class="flex flex-col gap-2 p-3 border rounded-md border-slate-100 dark:border-slate-700"
  >
    <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
      {{ t('TITLE') }}
    </span>
    <select class="!mb-0" :value="mode" @change="setMode($event.target.value)">
      <option value="company">{{ t('MODE_COMPANY') }}</option>
      <option value="own">{{ t('MODE_OWN') }}</option>
    </select>
    <p class="m-0 text-xs text-slate-500">
      {{ mode === 'own' ? t('HINT_OWN') : t('HINT_COMPANY') }}
    </p>

    <template v-if="mode === 'company'">
      <p v-if="loaded && companyEmpty" class="m-0 text-xs text-amber-700">
        {{ t('EMPTY') }}
      </p>
      <dl v-else class="m-0 text-xs">
        <template v-for="key in fields">
          <dt
            v-if="(company[key] || '').trim()"
            :key="`${key}-l`"
            class="mt-1 font-medium text-slate-600 dark:text-slate-300"
          >
            {{ label(key) }}
          </dt>
          <dd
            v-if="(company[key] || '').trim()"
            :key="`${key}-v`"
            class="m-0 text-slate-600 dark:text-slate-300"
          >
            {{ company[key] }}
          </dd>
        </template>
      </dl>
      <a
        :href="companyUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="text-xs text-woot-600 hover:underline"
      >
        {{ t('EDIT_COMPANY') }}
      </a>
    </template>

    <template v-else>
      <label v-for="key in fields" :key="key" class="block">
        <span class="field-label">{{ label(key) }}</span>
        <textarea
          rows="2"
          maxlength="600"
          :value="voice[key]"
          @input="setField(key, $event.target.value)"
        />
      </label>
    </template>
  </section>
</template>
