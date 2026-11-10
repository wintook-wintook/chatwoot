<script>
// feat/ficha_agente_ia — DATOS DEL NEGOCIO (DATOS FIJOS)
// ============================================================================
// Pedido del usuario (10/11/2026): valores que no cambian en la conversación (empresa,
// nombre del agente, teléfono, liga para agendar…); si cambian, se cambian aquí.
//   Empresa            [Kontrolya                ] ✕
//   Liga para agendar  [https://…               ] ✕
//   [+ Teléfono] [+ Dirección] [+ Horario] … [+ Otro dato]
// v-model: [{ label, value }]  (Ficha::BusinessData: [DATOS FIJOS] + [DATOS DEL NEGOCIO])
// ============================================================================
const MAX = 15;
const PRESETS = [
  'COMPANY',
  'AGENT_NAME',
  'PHONE',
  'WHATSAPP',
  'EMAIL',
  'ADDRESS',
  'HOURS',
  'WEBSITE',
  'BOOKING_LINK',
];

export default {
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Array, default: () => [] },
    // «Nombre que verá el cliente»: así se llena solo «Nombre del agente».
    agentName: { type: String, default: '' },
    disabled: { type: Boolean, default: false },
  },
  emits: ['input'],
  computed: {
    presets() {
      const usadas = this.value.map(d => (d.label || '').toLowerCase());
      return PRESETS.map(key => ({
        key,
        label: this.t(`BUSINESS_${key}`),
      })).filter(p => !usadas.includes(p.label.toLowerCase()));
    },
    full() {
      return this.value.length >= MAX;
    },
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_TEMPLATES.FICHA.${key}`, args);
    },
    emitList(lista) {
      if (this.disabled) return;
      this.$emit('input', lista);
    },
    add(preset) {
      if (this.full) return;
      const valor =
        preset && preset.key === 'AGENT_NAME' ? this.agentName.trim() : '';
      this.emitList([
        ...this.value,
        { label: preset ? preset.label : '', value: valor },
      ]);
      this.$nextTick(() => {
        const cajas = this.$refs.values;
        const ultima = cajas && cajas[cajas.length - 1];
        if (ultima) ultima.focus();
      });
    },
    set(indice, campo, texto) {
      this.emitList(
        this.value.map((d, i) => (i === indice ? { ...d, [campo]: texto } : d))
      );
    },
    remove(indice) {
      this.emitList(this.value.filter((_, i) => i !== indice));
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-3">
    <p class="!m-0 text-sm text-slate-600 dark:text-slate-300 shrink-0">
      {{ t('BUSINESS_HINT') }}
    </p>
    <div class="flex flex-col flex-1 min-h-0 gap-2 pr-1 overflow-auto">
      <p
        v-if="!value.length"
        class="!m-0 px-3 py-4 text-sm text-center border border-dashed rounded-lg text-slate-500 border-slate-200 dark:border-slate-700"
      >
        {{ t('BUSINESS_EMPTY') }}
      </p>
      <div
        v-for="(dato, indice) in value"
        :key="indice"
        class="grid items-center gap-2 sm:grid-cols-[12rem_minmax(0,1fr)_auto]"
      >
        <input
          type="text"
          maxlength="40"
          class="!mb-0 !h-9 text-sm font-medium"
          :value="dato.label"
          :placeholder="t('BUSINESS_LABEL_PLACEHOLDER')"
          :disabled="disabled"
          @input="set(indice, 'label', $event.target.value)"
        />
        <input
          ref="values"
          type="text"
          maxlength="300"
          class="!mb-0 !h-9 text-sm"
          :value="dato.value"
          :placeholder="t('BUSINESS_VALUE_PLACEHOLDER')"
          :disabled="disabled"
          @input="set(indice, 'value', $event.target.value)"
        />
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="alert"
          icon="dismiss"
          :is-disabled="disabled"
          @click="remove(indice)"
        />
      </div>
    </div>
    <div v-if="!full" class="flex flex-wrap items-center gap-1.5 shrink-0">
      <button
        v-for="preset in presets"
        :key="preset.key"
        type="button"
        class="px-2.5 py-1 text-xs border rounded-full border-slate-200 text-slate-600 hover:border-woot-500 dark:border-slate-700 dark:text-slate-300"
        :disabled="disabled"
        @click="add(preset)"
      >
        + {{ preset.label }}
      </button>
      <button
        type="button"
        class="px-2.5 py-1 text-xs border border-dashed rounded-full border-slate-300 text-slate-600 hover:border-woot-500 dark:border-slate-600 dark:text-slate-300"
        :disabled="disabled"
        @click="add(null)"
      >
        + {{ t('BUSINESS_OTHER') }}
      </button>
    </div>
    <p class="!m-0 text-xs text-slate-500 shrink-0">
      {{ t('BUSINESS_FOOT') }}
    </p>
  </div>
</template>
