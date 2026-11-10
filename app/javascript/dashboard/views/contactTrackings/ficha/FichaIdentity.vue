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
// 10/11/2026: un tono base (siempre de tú) + ajustes que se suman; dos tonos base juntos se
// contradicen. Mismos valores que Ficha::Generator::TONES / TONE_DEFAULTS.
export const TONES = [
  'cercano',
  'profesional',
  'entusiasta',
  'empatico',
  'directo',
];
const ADJUSTS = ['emojis', 'short', 'question'];
export const toneDefaults = tono => ({
  emojis: ['cercano', 'entusiasta'].includes(tono),
  short: tono === 'directo',
  question: tono === 'entusiasta',
});
// Cómo contestaría con cada tono (ejemplo fijo, sin IA).
const EXAMPLES = {
  cercano: '¡Claro! La renta de la grúa de 30 t cuesta $1,800 por día.',
  profesional:
    'Con gusto. La renta de la grúa de 30 toneladas tiene un costo de $1,800 por día.',
  entusiasta:
    '¡Excelente elección! La grúa de 30 t sale en $1,800 por día y la tenemos lista para ti.',
  empatico:
    'Entiendo que necesitas resolverlo pronto. La grúa de 30 t cuesta $1,800 por día y te ayudo a apartarla.',
  directo: 'Grúa de 30 t: $1,800 por día.',
};
export const toneExample = (tono, ajustes) => {
  const base = EXAMPLES[tono] || EXAMPLES.cercano;
  let texto = ajustes.short ? base.split('. ')[0].replace(/\.?$/, '.') : base;
  if (ajustes.question) texto += ' ¿Para qué fecha la necesitas?';
  if (ajustes.emojis) texto += ' 🚚';
  return texto;
};

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
    // Agente nuevo: el objetivo puede quedar vacío (se arma solo con lo marcado, sin IA).
    objectiveRequired: { type: Boolean, default: false },
    objectivePlaceholder: { type: String, default: '' },
    disabled: { type: Boolean, default: false },
  },
  emits: ['input', 'suggest', 'update:missing'],
  data() {
    return { tones: TONES, adjusts: ADJUSTS };
  },
  computed: {
    nameError() {
      const nombre = (this.value.name || '').trim();
      return nombre.length > 0 && nombre.length < 2;
    },
    adjust() {
      return this.value.toneAdjust || toneDefaults(this.value.tone);
    },
    example() {
      return toneExample(this.value.tone, this.adjust);
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
    // Al cambiar de tono, sus ajustes arrancan como los de ese tono.
    setTone(tono) {
      this.$emit('input', {
        ...this.value,
        tone: tono,
        toneAdjust: toneDefaults(tono),
      });
    },
    setAdjust(clave, valor) {
      this.set('toneAdjust', { ...this.adjust, [clave]: valor });
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

    <div v-if="showTone" class="flex flex-col gap-2">
      <span class="text-sm text-slate-800 dark:text-slate-100">
        {{ t('TONE') }}
      </span>
      <div class="flex flex-wrap gap-2">
        <label
          v-for="item in tones"
          :key="item"
          class="flex items-center gap-2 !m-0 px-3 py-1.5 text-sm border rounded-lg cursor-pointer"
          :class="
            value.tone === item
              ? 'border-woot-500 bg-woot-25 dark:bg-woot-900/20'
              : 'border-slate-200 dark:border-slate-700'
          "
          :title="t(`TONE_${item.toUpperCase()}_HINT`)"
        >
          <input
            type="radio"
            class="!m-0"
            :value="item"
            :checked="value.tone === item"
            :disabled="disabled"
            @change="setTone(item)"
          />
          {{ t(`TONE_${item.toUpperCase()}`) }}
        </label>
      </div>
      <p class="!m-0 text-xs text-slate-500">
        {{ t(`TONE_${(value.tone || 'cercano').toUpperCase()}_HINT`) }}
      </p>
      <div class="flex flex-wrap items-center gap-x-4 gap-y-1 text-sm">
        <span class="text-xs text-slate-500">{{ t('TONE_ADJUST') }}</span>
        <label
          v-for="clave in adjusts"
          :key="clave"
          class="flex items-center gap-1.5 !m-0 text-sm cursor-pointer"
        >
          <input
            type="checkbox"
            class="!m-0"
            :checked="adjust[clave]"
            :disabled="disabled"
            @change="setAdjust(clave, $event.target.checked)"
          />
          {{ t(`TONE_ADJUST_${clave.toUpperCase()}`) }}
        </label>
      </div>
      <div
        class="flex flex-col gap-1 p-3 rounded-lg bg-slate-50 dark:bg-slate-800/60"
      >
        <span class="text-xs text-slate-500">{{ t('TONE_EXAMPLE') }}</span>
        <span
          class="self-start max-w-full px-3 py-2 text-sm bg-white rounded-lg rounded-tl-none shadow-sm dark:bg-slate-800 text-slate-700 dark:text-slate-200"
        >
          {{ example }}
        </span>
      </div>
    </div>

    <div class="flex flex-col gap-1">
      <div class="flex items-center justify-between gap-2">
        <span class="text-sm text-slate-800 dark:text-slate-100">
          {{ t('OBJECTIVE') }}
          <span v-if="objectiveRequired" class="text-red-500">
            {{ t('REQUIRED_MARK') }}
          </span>
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
        :placeholder="objectivePlaceholder || t('OBJECTIVE_PLACEHOLDER')"
        @input="set('objective', $event.target.value)"
      />
      <p
        v-if="!objectiveRequired && !(value.objective || '').trim()"
        class="!m-0 text-xs text-slate-500"
      >
        {{ t('OBJECTIVE_AUTO_HINT') }}
      </p>
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
