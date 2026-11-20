<!--
  Cotizar (los tres agentes listos; Motor2::Skills::Quote): no cotiza, arma un borrador para el vendedor o se la
  manda con precios del Catálogo, y a los N días le pregunta si pudo revisarla. v-model: { mode, follow_days }.
-->
<script>
export default {
  name: 'QuoteMode',
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Object, required: true },
    // Sin productos en el Catálogo no puede cotizar.
    hasCatalog: { type: Boolean, default: false },
  },
  emits: ['input'],
  methods: {
    t(key, params) {
      return this.$t(`READY_AGENTS.QUOTE.${key}`, params);
    },
    set(field, val) {
      this.$emit('input', { ...this.value, [field]: val });
    },
  },
};
</script>

<template>
  <fieldset class="flex flex-col gap-1">
    <legend class="field-label">{{ t('TITLE') }}</legend>
    <p v-if="!hasCatalog" class="m-0 text-xs text-amber-700">
      {{ t('NO_CATALOG') }}
    </p>
    <label
      v-for="mode in ['off', 'draft', 'send']"
      :key="mode"
      class="flex items-start gap-2 text-sm cursor-pointer"
    >
      <input
        type="radio"
        class="!m-0 mt-1 shrink-0"
        :checked="value.mode === mode"
        :disabled="!hasCatalog && mode !== 'off'"
        @change="set('mode', mode)"
      />
      <span>
        {{ t(`MODES.${mode}`) }}
        <span v-if="mode === 'draft'" class="text-xs text-woot-600">{{
          t('RECOMMENDED')
        }}</span>
      </span>
    </label>
    <label v-if="value.mode === 'send'" class="flex items-center gap-2 text-sm">
      {{ t('FOLLOW') }}
      <select
        class="!mb-0 !w-20"
        :value="value.follow_days"
        @change="set('follow_days', Number($event.target.value))"
      >
        <option v-for="d in [1, 2, 3, 5, 7]" :key="d" :value="d">
          {{ d }}
        </option>
      </select>
      {{ t('DAYS') }}
    </label>
  </fieldset>
</template>
