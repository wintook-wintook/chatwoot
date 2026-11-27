<!--
  Cotizar (los tres agentes listos; Motor2::Skills::Quote): no cotiza, arma un borrador para el vendedor o se la
  manda con precios del Catálogo, y a los N días le pregunta si pudo revisarla (en borrador, desde que el vendedor la
  manda), con su PROPIA plantilla si ya pasaron 24 h (no la del Seguimiento).
  v-model: { mode, follow, follow_days, template, cart }. cart: ir armando «su cuenta» en el chat (Motor2::Skills::QuoteCart).
-->
<script>
export default {
  name: 'QuoteMode',
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Object, required: true },
    // Sin productos en el Catálogo no puede cotizar.
    hasCatalog: { type: Boolean, default: false },
    // Plantillas aprobadas de su bandeja de WhatsApp.
    templates: { type: Array, default: () => [] },
    // Campaña de Ofrecer: solo borrador o mandarla, con sus textos (precio de promoción); los agentes listos, todo.
    modes: { type: Array, default: () => ['off', 'draft', 'send'] },
    labels: { type: Object, default: null },
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
      v-for="mode in modes"
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
        {{ (labels && labels[mode]) || t(`MODES.${mode}`) }}
        <span v-if="mode === 'draft'" class="text-xs text-woot-600">{{
          t('RECOMMENDED')
        }}</span>
      </span>
    </label>
    <template v-if="value.mode !== 'off'">
      <label class="flex items-start gap-2 mt-2 text-sm">
        <input
          type="checkbox"
          class="!m-0 mt-1"
          :checked="value.cart === true"
          @change="set('cart', $event.target.checked)"
        />
        <span>
          {{ t('CART') }}
          <span class="block text-xs text-slate-500">{{ t('CART_HINT') }}</span>
        </span>
      </label>
      <label class="flex flex-wrap items-center gap-2 mt-2 text-sm">
        <input
          type="checkbox"
          class="!m-0"
          :checked="value.follow !== false"
          @change="set('follow', $event.target.checked)"
        />
        {{ t('FOLLOW') }}
        <select
          class="!mb-0 !w-20"
          :value="value.follow_days || 3"
          :disabled="value.follow === false"
          @change="set('follow_days', Number($event.target.value))"
        >
          <option v-for="d in [1, 2, 3, 5, 7]" :key="d" :value="d">
            {{ d }}
          </option>
        </select>
        {{ t(value.mode === 'draft' ? 'DAYS_DRAFT' : 'DAYS') }}
      </label>
      <template v-if="value.follow !== false">
        <label class="block">
          <span class="field-label">{{ t('TEMPLATE') }}</span>
          <select
            class="!mb-0"
            :value="value.template || ''"
            @change="set('template', $event.target.value)"
          >
            <option value="">{{ t('NO_TEMPLATE_OPTION') }}</option>
            <option v-for="name in templates" :key="name" :value="name">
              {{ name }}
            </option>
          </select>
        </label>
        <p v-if="!value.template" class="m-0 text-xs text-amber-700">
          {{ templates.length ? t('TEMPLATE_WARN') : t('TEMPLATE_NONE') }}
        </p>
        <p v-else class="m-0 text-xs text-slate-500">
          {{ t('TEMPLATE_HINT') }}
        </p>
      </template>
    </template>
  </fieldset>
</template>
