<script>
// feat/ficha_agente_ia — LAS PREGUNTAS QUE EL AGENTE HACE, UNA A LA VEZ
// ============================================================================
// Pedido del usuario (10/11/2026): «el agente envía preguntas y al responder envía la
// siguiente (por eso existe Datos fijos › pregunta)… asistir para eso y para Variables».
//   1. ¿Qué sistema usas hoy?   guarda en [SISTEMA]   respuestas: CONTPAQi, Aspel, Otro
//   2. ¿Cuántos usuarios son?    guarda en [USUARIOS]  (libre)
//   ¿Cuándo pregunta?  (•) Al inicio   ( ) En la ruta [Cotizar ▾]
// El servidor (Ficha::Questions) escribe [VARIABLES], [DATOS FIJOS] y la regla de uso.
// v-model: { questions: [{ text, var, options: [] }], when: 'start' | ruta }
// ============================================================================
import { useAlert } from 'dashboard/composables';
import FichaAPI from 'dashboard/api/fichaAgente';

const MAX = 10;
// La palabra con más sentido de la pregunta: la más larga que no sea de relleno.
const FILLER = ['cuantos', 'cuantas', 'tienes', 'estas', 'quieres', 'puedes'];
const varFromText = (texto, indice) => {
  const palabras = (texto || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^A-Za-z0-9\s]/g, ' ')
    .toLowerCase()
    .split(/\s+/)
    .filter(p => p.length > 3 && !FILLER.includes(p));
  const mejor = palabras.sort((a, b) => b.length - a.length)[0];
  return mejor ? mejor.toUpperCase() : `RESPUESTA_${indice + 1}`;
};

export default {
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Object, default: () => ({ questions: [], when: 'start' }) },
    // [{ value, label }]: rutas donde pueden ir las preguntas.
    routeOptions: { type: Array, default: () => [] },
    // Lo capturado (para ✨): { name, items, objective }.
    suggestContext: { type: Object, default: () => ({}) },
    disabled: { type: Boolean, default: false },
  },
  emits: ['input'],
  data() {
    return { suggesting: false };
  },
  computed: {
    questions() {
      return this.value.questions || [];
    },
    when() {
      return this.value.when || 'start';
    },
  },
  methods: {
    t(key, args) {
      return this.$t(`TRACKING_TEMPLATES.FICHA.${key}`, args);
    },
    emit(cambios) {
      this.$emit('input', {
        questions: this.questions,
        when: this.when,
        ...cambios,
      });
    },
    setQuestion(indice, campo, valor) {
      const lista = this.questions.map((q, i) =>
        i === indice ? { ...q, [campo]: valor } : q
      );
      this.emit({ questions: lista });
    },
    setOptions(indice, texto) {
      const opciones = texto
        .split(',')
        .map(o => o.trim())
        .filter(Boolean);
      this.setQuestion(indice, 'options', opciones);
    },
    autoVar(indice) {
      const q = this.questions[indice];
      if (!q.var && q.text)
        this.setQuestion(indice, 'var', varFromText(q.text, indice));
    },
    add() {
      if (this.questions.length >= MAX) return;
      this.emit({
        questions: [...this.questions, { text: '', var: '', options: [] }],
      });
    },
    remove(indice) {
      this.emit({ questions: this.questions.filter((_, i) => i !== indice) });
    },
    move(indice, paso) {
      const destino = indice + paso;
      if (destino < 0 || destino >= this.questions.length) return;
      const lista = [...this.questions];
      [lista[indice], lista[destino]] = [lista[destino], lista[indice]];
      this.emit({ questions: lista });
    },
    async suggest() {
      this.suggesting = true;
      try {
        const { data } = await FichaAPI.questionsSuggest(this.suggestContext);
        const nuevas = (data.questions || []).map(q => ({
          text: q.text,
          var: q.var,
          options: q.options || [],
        }));
        if (nuevas.length) this.emit({ questions: nuevas });
      } catch (error) {
        const datos = error && error.response && error.response.data;
        useAlert((datos && datos.error) || this.t('SUGGEST_ERROR'));
      } finally {
        this.suggesting = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="flex items-center justify-between gap-2">
      <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
        {{ t('QUESTIONS_HINT') }}
      </p>
      <woot-button
        size="small"
        variant="smooth"
        icon="wand"
        :is-loading="suggesting"
        :is-disabled="disabled || suggesting"
        @click="suggest"
      >
        {{ t('SUGGEST') }}
      </woot-button>
    </div>

    <ol class="!m-0 !p-0 list-none flex flex-col gap-2">
      <li
        v-for="(q, indice) in questions"
        :key="indice"
        class="flex flex-col gap-2 p-3 border rounded-lg border-slate-200 dark:border-slate-700"
      >
        <div class="flex items-center gap-2">
          <span
            class="flex items-center justify-center w-6 h-6 text-xs font-semibold text-white rounded-full shrink-0 bg-woot-500"
          >
            {{ indice + 1 }}
          </span>
          <input
            type="text"
            maxlength="200"
            class="flex-1 !mb-0"
            :value="q.text"
            :placeholder="t('QUESTION_PLACEHOLDER')"
            :disabled="disabled"
            @input="setQuestion(indice, 'text', $event.target.value)"
            @blur="autoVar(indice)"
          />
          <woot-button
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            icon="chevron-up"
            :is-disabled="disabled || indice === 0"
            @click="move(indice, -1)"
          />
          <woot-button
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            icon="chevron-down"
            :is-disabled="disabled || indice === questions.length - 1"
            @click="move(indice, 1)"
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
        <div class="grid gap-2 pl-8 sm:grid-cols-[12rem_minmax(0,1fr)]">
          <label class="!m-0 text-xs">
            {{ t('QUESTION_VAR') }}
            <input
              type="text"
              class="!mb-0 !h-8 text-sm uppercase"
              :value="q.var"
              :disabled="disabled"
              @input="setQuestion(indice, 'var', $event.target.value)"
            />
          </label>
          <label class="!m-0 text-xs">
            {{ t('QUESTION_OPTIONS') }}
            <input
              type="text"
              class="!mb-0 !h-8 text-sm"
              :value="(q.options || []).join(', ')"
              :placeholder="t('QUESTION_OPTIONS_PLACEHOLDER')"
              :disabled="disabled"
              @change="setOptions(indice, $event.target.value)"
            />
          </label>
        </div>
      </li>
    </ol>
    <woot-button
      v-if="questions.length < 10"
      size="small"
      variant="clear"
      icon="add"
      class="self-start"
      :is-disabled="disabled"
      @click="add"
    >
      {{ t('QUESTION_ADD') }}
    </woot-button>

    <div
      v-if="questions.length"
      class="flex flex-wrap items-center gap-2 text-sm"
    >
      <span>{{ t('QUESTIONS_WHEN') }}</span>
      <select
        class="!mb-0 !h-8 !py-0 !w-auto text-sm"
        :value="when"
        :disabled="disabled"
        @change="emit({ when: $event.target.value })"
      >
        <option value="start">{{ t('QUESTIONS_AT_START') }}</option>
        <option
          v-for="ruta in routeOptions"
          :key="ruta.value"
          :value="ruta.value"
        >
          {{ t('QUESTIONS_IN_ROUTE', { route: ruta.label }) }}
        </option>
      </select>
    </div>
  </div>
</template>
