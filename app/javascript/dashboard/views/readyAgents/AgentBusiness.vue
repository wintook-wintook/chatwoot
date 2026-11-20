<!--
  «Datos del negocio» dentro de cada agente listo (los tres), con un selector como el de la voz:
    - «Usar los de la empresa»: los de «Cómo habla tu empresa» › Tu negocio, en solo lectura;
    - «Personalizar para este agente»: los 5 campos, arrancando con los de la empresa; quedan solo para él.
  Los agentes de antes con sus datos llenos quedan en «Personalizar» (Functions::Extras#own_business?).
  v-model: los settings del agente (usa business_mode y business_what … business_practical).
-->
<script>
import AiVoiceAPI from 'dashboard/api/aiVoice';
import { frontendURL } from 'dashboard/helper/URLHelper';

const FIELDS = ['what', 'who', 'coverage', 'why', 'practical'];

export default {
  name: 'AgentBusiness',
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
      return FIELDS;
    },
    mode() {
      if (this.value.business_mode) return this.value.business_mode;
      return FIELDS.some(f => (this.value[`business_${f}`] || '').trim())
        ? 'own'
        : 'company';
    },
    companyEmpty() {
      return !FIELDS.some(f => (this.company[f] || '').trim());
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
      this.company = data.business?.fixed || {};
    } finally {
      this.loaded = true;
    }
  },
  methods: {
    t(key, params) {
      return this.$t(`READY_AGENTS.${key}`, params);
    },
    setMode(mode) {
      const next = { ...this.value, business_mode: mode };
      FIELDS.forEach(f => {
        const key = `business_${f}`;
        // Personalizar arranca con lo de la empresa; usar el de la empresa borra lo propio.
        next[key] =
          mode === 'own' ? this.value[key] || this.company[f] || '' : '';
      });
      this.$emit('input', next);
    },
    setField(field, text) {
      this.$emit('input', {
        ...this.value,
        business_mode: 'own',
        [`business_${field}`]: text,
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
      {{ t('AGENT_BUSINESS.TITLE') }}
    </span>
    <select class="!mb-0" :value="mode" @change="setMode($event.target.value)">
      <option value="company">{{ t('AGENT_BUSINESS.MODE_COMPANY') }}</option>
      <option value="own">{{ t('AGENT_BUSINESS.MODE_OWN') }}</option>
    </select>
    <p class="m-0 text-xs text-slate-500">
      {{
        mode === 'own'
          ? t('AGENT_BUSINESS.HINT_OWN')
          : t('AGENT_BUSINESS.HINT_COMPANY')
      }}
    </p>

    <template v-if="mode === 'company'">
      <p v-if="loaded && companyEmpty" class="m-0 text-xs text-amber-700">
        {{ t('AGENT_BUSINESS.EMPTY') }}
      </p>
      <dl v-else class="m-0 text-xs">
        <template v-for="field in fields">
          <dt
            v-if="(company[field] || '').trim()"
            :key="`${field}-l`"
            class="mt-1 font-medium text-slate-600 dark:text-slate-300"
          >
            {{ t(`BUSINESS.${field.toUpperCase()}`) }}
          </dt>
          <dd
            v-if="(company[field] || '').trim()"
            :key="`${field}-v`"
            class="m-0 text-slate-600 dark:text-slate-300"
          >
            {{ company[field] }}
          </dd>
        </template>
      </dl>
      <a
        :href="companyUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="text-xs text-woot-600 hover:underline"
      >
        {{ t('AGENT_BUSINESS.EDIT_COMPANY') }}
      </a>
    </template>

    <template v-else>
      <label v-for="field in fields" :key="field" class="block">
        <span class="field-label">{{
          t(`BUSINESS.${field.toUpperCase()}`)
        }}</span>
        <textarea
          rows="2"
          :value="value[`business_${field}`]"
          :placeholder="t(`BUSINESS.${field.toUpperCase()}_PLACEHOLDER`)"
          @input="setField(field, $event.target.value)"
        />
      </label>
    </template>
  </section>
</template>
