<script>
// feat/ficha_agente_ia — DATOS DEL AGENTE (en Recursos › Agente y canal)
// ============================================================================
// Pedido del usuario (10/11/2026): «en canal y seguimiento falta el Nombre que verá el
// cliente, Nombre del agente IA *, Objetivo * (más amplio, dos rows) y el contexto»; con
// eso la pestaña «Ficha de Agente IA» ya no hace falta para el administrador.
//
//   Nombre del agente IA *        Nombre que verá el cliente
//   Tono (solo al crear)
//   Objetivo *                                   [✨ Proponer]
//   Contexto IA                                  [✨ Proponer]
//   Te conviene agregar: + horario  + dirección
//
// v-model: { name, displayName, tone, objective, business }. ✨ lo resuelve quien lo usa
// (evento 'suggest' con 'objective' | 'context'); los datos que faltan llegan en `missing`.
// ============================================================================
const TONES = ['cercano', 'profesional'];

export default {
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Object, required: true },
    showTone: { type: Boolean, default: false },
    // 'objective' | 'context' mientras la IA trabaja; false si no.
    suggesting: { type: [String, Boolean], default: false },
    canSuggest: { type: Boolean, default: false },
    missing: { type: Array, default: () => [] },
    maxContext: { type: Number, default: 800 },
    disabled: { type: Boolean, default: false },
  },
  emits: ['input', 'suggest', 'update:missing'],
  data() {
    return { tones: TONES };
  },
  computed: {
    nameError() {
      const nombre = (this.value.name || '').trim();
      return nombre.length > 0 && nombre.length < 2;
    },
    contextLength() {
      return (this.value.business || '').length;
    },
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_TEMPLATES.FICHA.${key}`, args);
    },
    set(campo, valor) {
      this.$emit('input', { ...this.value, [campo]: valor });
    },
    // Agrega el dato que falta como una línea para llenarla.
    addMissing(dato) {
      const texto = (this.value.business || '').trim();
      this.set('business', `${texto}${texto ? '\n' : ''}${dato}: `);
      this.$emit(
        'update:missing',
        this.missing.filter(item => item !== dato)
      );
      this.$nextTick(() => {
        const caja = this.$refs.context;
        if (caja) caja.focus();
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
      {{ t('IDENTITY_HINT') }}
    </p>
    <div class="grid gap-3 sm:grid-cols-2">
      <label class="!m-0" :class="{ error: nameError }">
        {{ t('NAME') }}
        <span class="text-red-500">{{ t('REQUIRED_MARK') }}</span>
        <input
          type="text"
          maxlength="100"
          class="!mb-0"
          :value="value.name"
          :disabled="disabled"
          :placeholder="t('NAME_PLACEHOLDER')"
          @input="set('name', $event.target.value)"
        />
      </label>
      <label class="!m-0">
        {{ t('DISPLAY_NAME') }}
        <input
          type="text"
          maxlength="30"
          class="!mb-0"
          :value="value.displayName"
          :disabled="disabled"
          :placeholder="t('DISPLAY_NAME_PLACEHOLDER')"
          @input="set('displayName', $event.target.value)"
        />
      </label>
    </div>

    <div v-if="showTone" class="flex flex-wrap items-center gap-2">
      <span class="text-sm text-slate-800 dark:text-slate-100">
        {{ t('TONE') }}
      </span>
      <label
        v-for="item in tones"
        :key="item"
        class="flex items-center gap-2 !m-0 px-3 py-1.5 text-sm border rounded-lg cursor-pointer"
        :class="
          value.tone === item
            ? 'border-woot-500 bg-woot-25 dark:bg-woot-900/20'
            : 'border-slate-200 dark:border-slate-700'
        "
      >
        <input
          type="radio"
          class="!m-0"
          :value="item"
          :checked="value.tone === item"
          :disabled="disabled"
          @change="set('tone', item)"
        />
        {{ t(`TONE_${item.toUpperCase()}`) }}
      </label>
    </div>

    <div class="flex flex-col gap-1">
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm text-slate-800 dark:text-slate-100">
          {{ t('OBJECTIVE') }}
          <span class="text-red-500">{{ t('REQUIRED_MARK') }}</span>
        </span>
        <woot-button
          size="tiny"
          variant="smooth"
          icon="wand"
          :is-loading="suggesting === 'objective'"
          :is-disabled="!!suggesting || !canSuggest || disabled"
          :title="canSuggest ? '' : t('SUGGEST_NEEDS_SOURCES')"
          @click="$emit('suggest', 'objective')"
        >
          {{ t('SUGGEST') }}
        </woot-button>
      </div>
      <textarea
        rows="2"
        maxlength="500"
        class="!mb-0"
        :value="value.objective"
        :disabled="disabled"
        :placeholder="t('OBJECTIVE_PLACEHOLDER')"
        @input="set('objective', $event.target.value)"
      />
    </div>

    <div class="flex flex-col gap-1">
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm text-slate-800 dark:text-slate-100">
          {{ t('CONTEXT') }}
        </span>
        <woot-button
          size="tiny"
          variant="smooth"
          icon="wand"
          :is-loading="suggesting === 'context'"
          :is-disabled="!!suggesting || !canSuggest || disabled"
          :title="canSuggest ? '' : t('SUGGEST_NEEDS_SOURCES')"
          @click="$emit('suggest', 'context')"
        >
          {{ t('SUGGEST') }}
        </woot-button>
      </div>
      <textarea
        ref="context"
        rows="5"
        :maxlength="maxContext"
        class="!mb-0"
        :value="value.business"
        :disabled="disabled"
        :placeholder="t('BUSINESS_PLACEHOLDER')"
        @input="set('business', $event.target.value)"
      />
      <div class="flex items-center justify-between gap-2 text-xs">
        <span class="text-slate-500">{{ t('CONTEXT_HINT') }}</span>
        <span class="text-slate-400 shrink-0">
          {{ contextLength }}/{{ maxContext }}
        </span>
      </div>
      <div
        v-if="missing.length"
        class="flex flex-wrap items-center gap-1 text-xs"
      >
        <span class="text-amber-800">{{ t('MISSING') }}</span>
        <button
          v-for="dato in missing"
          :key="dato"
          type="button"
          class="px-2 py-0.5 border rounded-full border-amber-300 text-amber-800 hover:bg-amber-50"
          @click="addMissing(dato)"
        >
          + {{ dato }}
        </button>
      </div>
      <p class="!m-0 text-xs text-slate-400">
        {{ canSuggest ? t('SUGGEST_COST') : t('SUGGEST_NEEDS_SOURCES') }}
      </p>
    </div>
  </div>
</template>
