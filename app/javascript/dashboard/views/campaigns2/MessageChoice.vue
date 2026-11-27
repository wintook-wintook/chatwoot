<!--
  Campaña con Vendedor IA — un mensaje que sale con la ventana abierta (o en correo), con dos opciones:
    «La IA lo escribe al momento» (recomendado): para cada contacto, con lo que sabe de él y lo último que platicó.
    «Mensaje fijo»: igual para todos; lo escribes tú o lo redacta Dali (DaliWriter).
  Se usa en los toques (WhatsappFlow), los recordatorios del evento (EventReminders) y lo que venga en otros tipos.
    value / ai        el texto fijo y si lo escribe la IA (.sync)
    chooseMode        false: solo el fijo (la apertura)
    dali              { target, number, extra } para «Redactar con Dali»; sin él, no sale
    placeholder, legend, aiHint, fixedHint  textos propios (si no, los de siempre)
-->
<script>
import DaliWriter from './DaliWriter.vue';

export default {
  name: 'MessageChoice',
  components: { DaliWriter },
  props: {
    value: { type: String, default: '' },
    ai: { type: Boolean, default: true },
    chooseMode: { type: Boolean, default: true },
    dali: { type: Object, default: null },
    campaignId: { type: Number, default: null },
    save: { type: Function, default: null },
    placeholder: { type: String, default: '' },
    legend: { type: String, default: '' },
    aiHint: { type: String, default: '' },
    fixedHint: { type: String, default: '' },
    maxlength: { type: Number, default: 1500 },
  },
  emits: ['update:value', 'update:ai'],
  computed: {
    fixed() {
      return !this.chooseMode || !this.ai;
    },
  },
  methods: {
    t(key) {
      return this.$t(`CAMPAIGNS2.MESSAGE_CHOICE.${key}`);
    },
    setAi(ai) {
      this.$emit('update:ai', ai);
      if (ai) this.$emit('update:value', '');
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-1">
    <fieldset v-if="chooseMode" class="flex flex-wrap gap-x-4 gap-y-1 text-sm">
      <legend class="field-label">{{ legend || t('LEGEND') }}</legend>
      <label class="flex items-center gap-1">
        <input
          type="radio"
          class="!m-0"
          :checked="!fixed"
          @change="setAi(true)"
        />
        {{ t('AI') }}
      </label>
      <label class="flex items-center gap-1">
        <input
          type="radio"
          class="!m-0"
          :checked="fixed"
          @change="setAi(false)"
        />
        {{ t('FIXED') }}
      </label>
    </fieldset>
    <p v-if="!fixed" class="m-0 text-[11px] text-slate-500">
      {{ aiHint || t('AI_HINT') }}
    </p>
    <template v-else>
      <label class="block">
        <span v-if="!chooseMode && legend" class="field-label">
          {{ legend }}
        </span>
        <textarea
          rows="2"
          class="!mb-0 text-sm"
          :maxlength="maxlength"
          :value="value"
          :placeholder="placeholder"
          @input="$emit('update:value', $event.target.value)"
        />
        <span class="block text-[11px] text-slate-500">
          {{ fixedHint || t('FIXED_HINT') }}
        </span>
      </label>
      <DaliWriter
        v-if="dali && save"
        compact
        :target="dali.target"
        :number="dali.number || 1"
        :extra="dali.extra || {}"
        :current="value"
        :campaign-id="campaignId"
        :save="save"
        @use="$emit('update:value', $event.text)"
      />
    </template>
  </div>
</template>
