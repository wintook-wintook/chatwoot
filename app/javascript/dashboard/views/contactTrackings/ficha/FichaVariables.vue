<script>
// feat/ficha_agente_ia — VARIABLES: LO QUE EL AGENTE RECUERDA Y VA CAMBIANDO
// ============================================================================
// Pedido del usuario (10/11/2026). Tres orígenes, todos en un solo lugar:
//   · por condición (se editan aquí): LIGA_ENTREGADA  [NO] [SÍ]  empieza en NO
//                                     Pasa a SÍ cuando: [le mande la liga para agendar]
//   · de una hoja (solo se ven): CARRERA — viene de la hoja «Precios» (casilla en la hoja)
//   · de una pregunta (solo se ven): CIUDAD — viene de la pregunta 2
// «Lo que diga el cliente» = texto libre (VACÍO | valor): «Se guarda cuando: …».
// v-model: [{ name, values: [], free, initial, rules: [{ to, when }] }] (Ficha::Memory)
// ============================================================================
import { useAlert } from 'dashboard/composables';
import FichaAPI from 'dashboard/api/fichaAgente';

const MAX = 10;
const ANY = '*';
const EMPTY = 'VACÍO';

// Nombre de variable: MAYÚSCULAS, sin acentos, con guion bajo.
export const varName = texto =>
  (texto || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toUpperCase()
    .replace(/[^A-Z0-9_]+/g, '_')
    .replace(/^[_0-9]+|_+$/g, '');

export default {
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Array, default: () => [] },
    // [{ name, column, sheet }]: las que recuerdan una columna (casilla en la hoja).
    sheetVars: { type: Array, default: () => [] },
    // [{ name, n }]: las que guardan la respuesta de una pregunta.
    questionVars: { type: Array, default: () => [] },
    suggestContext: { type: Object, default: () => ({}) },
    disabled: { type: Boolean, default: false },
  },
  emits: ['input'],
  data() {
    return { suggesting: false, any: ANY };
  },
  computed: {
    derived() {
      return [
        ...this.sheetVars.map(v => ({
          name: v.name,
          from: this.t('VARIABLES_FROM_SHEET', {
            sheet: v.sheet,
            column: v.column,
          }),
        })),
        ...this.questionVars.map(v => ({
          name: v.name,
          from: this.t('VARIABLES_FROM_QUESTION', { n: v.n }),
        })),
      ];
    },
    isEmpty() {
      return !this.value.length && !this.derived.length;
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
    update(indice, cambios) {
      this.emitList(
        this.value.map((v, i) => (i === indice ? { ...v, ...cambios } : v))
      );
    },
    add() {
      if (this.value.length >= MAX) return;
      this.emitList([
        ...this.value,
        {
          name: '',
          values: ['NO', 'SÍ'],
          free: false,
          initial: 'NO',
          rules: [],
        },
      ]);
    },
    remove(indice) {
      this.emitList(this.value.filter((_, i) => i !== indice));
    },
    setName(indice, texto) {
      this.update(indice, { name: varName(texto) });
    },
    // «NO, SÍ» → valores; el inicial y las reglas se quedan solo si siguen en la lista.
    setValues(indice, texto) {
      const valores = [
        ...new Set(
          texto
            .split(',')
            .map(v => v.replace(/[|;=%]/g, ' ').trim())
            .filter(Boolean)
        ),
      ];
      const variable = this.value[indice];
      this.update(indice, {
        values: valores,
        initial: valores.includes(variable.initial)
          ? variable.initial
          : valores[0] || '',
        rules: (variable.rules || []).filter(
          r => r.to === ANY || valores.includes(r.to)
        ),
      });
    },
    setFree(indice, libre) {
      const variable = this.value[indice];
      this.update(
        indice,
        libre
          ? { free: true, values: [EMPTY], initial: EMPTY, rules: [] }
          : {
              free: false,
              values: ['NO', 'SÍ'],
              initial: 'NO',
              rules: (variable.rules || []).filter(r => r.to !== ANY),
            }
      );
    },
    // Los valores a los que puede pasar (todos menos con el que empieza); libre: «*».
    targets(variable) {
      if (variable.free) return [ANY];
      return (variable.values || []).filter(v => v !== variable.initial);
    },
    ruleText(variable, destino) {
      const regla = (variable.rules || []).find(r => r.to === destino);
      return regla ? regla.when : '';
    },
    setRule(indice, destino, texto) {
      const variable = this.value[indice];
      const otras = (variable.rules || []).filter(r => r.to !== destino);
      const cuando = texto.trim();
      this.update(indice, {
        rules: cuando ? [...otras, { to: destino, when: cuando }] : otras,
      });
    },
    // ✨ La IA propone variables «por condición» con lo marcado.
    async suggest() {
      this.suggesting = true;
      try {
        const { data } = await FichaAPI.variablesSuggest(this.suggestContext);
        const usados = this.value.map(v => v.name);
        const nuevas = (data.variables || []).filter(
          v => !usados.includes(v.name)
        );
        this.emitList([...this.value, ...nuevas].slice(0, MAX));
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
  <div class="flex flex-col flex-1 min-h-0 gap-3">
    <div class="flex items-center justify-between gap-2 shrink-0">
      <p class="!m-0 text-sm text-slate-600 dark:text-slate-300">
        {{ t('VARIABLES_HINT') }}
      </p>
      <woot-button
        v-if="!isEmpty"
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

    <!-- Sin variables: qué son y cómo empezar. -->
    <div
      v-if="isEmpty"
      class="flex flex-col items-center gap-3 px-6 py-8 text-center border border-dashed rounded-lg shrink-0 border-woot-200 bg-woot-25/50 dark:border-woot-800 dark:bg-woot-900/10"
    >
      <fluent-icon icon="tag" size="28" class="text-woot-500" />
      <p class="!m-0 text-sm font-medium text-slate-800 dark:text-slate-100">
        {{ t('VARIABLES_EMPTY_TITLE') }}
      </p>
      <p class="!m-0 max-w-lg text-sm text-slate-600 dark:text-slate-300">
        {{ t('VARIABLES_EMPTY_HINT') }}
      </p>
      <div class="flex flex-wrap justify-center gap-2">
        <woot-button
          icon="wand"
          :is-loading="suggesting"
          :is-disabled="disabled || suggesting"
          @click="suggest"
        >
          {{ t('VARIABLES_EMPTY_SUGGEST') }}
        </woot-button>
        <woot-button
          variant="smooth"
          color-scheme="secondary"
          icon="add"
          :is-disabled="disabled || suggesting"
          @click="add"
        >
          {{ t('VARIABLES_ADD') }}
        </woot-button>
      </div>
      <p class="!m-0 text-xs text-slate-500">
        {{ t('VARIABLES_EMPTY_SHEET') }}
      </p>
    </div>

    <div v-else class="flex flex-col flex-1 min-h-0 gap-2 pr-1 overflow-auto">
      <!-- Las que vienen de una hoja o de una pregunta: solo se ven. -->
      <div
        v-for="variable in derived"
        :key="`d-${variable.name}`"
        class="flex items-center gap-2 px-3 py-2 text-sm rounded-lg bg-slate-50 dark:bg-slate-800/60"
      >
        <span
          class="px-1.5 py-0.5 font-mono text-xs rounded bg-slate-200 text-slate-700 dark:bg-slate-700 dark:text-slate-200"
        >
          {{ variable.name }}
        </span>
        <span class="text-xs text-slate-500">{{ variable.from }}</span>
      </div>

      <div
        v-for="(variable, indice) in value"
        :key="indice"
        class="flex flex-col gap-2 p-3 border rounded-lg border-slate-200 dark:border-slate-700"
      >
        <div class="flex items-center gap-2">
          <input
            type="text"
            class="flex-1 !mb-0 !h-8 font-mono text-sm uppercase"
            :value="variable.name"
            :placeholder="t('VARIABLE_NAME_PLACEHOLDER')"
            :disabled="disabled"
            @change="setName(indice, $event.target.value)"
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
        <div class="grid gap-2 sm:grid-cols-[minmax(0,1fr)_12rem]">
          <label class="!m-0 text-xs">
            {{ t('VARIABLE_VALUES') }}
            <input
              type="text"
              class="!mb-0 !h-8 text-sm"
              :value="variable.free ? '' : (variable.values || []).join(', ')"
              :placeholder="
                variable.free
                  ? t('VARIABLE_FREE_PLACEHOLDER')
                  : t('VARIABLE_VALUES_PLACEHOLDER')
              "
              :disabled="disabled || variable.free"
              @change="setValues(indice, $event.target.value)"
            />
            <span class="flex items-center gap-1.5 mt-1 text-slate-600">
              <input
                type="checkbox"
                class="!m-0"
                :checked="variable.free"
                :disabled="disabled"
                @change="setFree(indice, $event.target.checked)"
              />
              {{ t('VARIABLE_FREE') }}
            </span>
          </label>
          <label v-if="!variable.free" class="!m-0 text-xs">
            {{ t('VARIABLE_INITIAL') }}
            <select
              class="!mb-0 !h-8 !py-0 text-sm"
              :value="variable.initial"
              :disabled="disabled"
              @change="update(indice, { initial: $event.target.value })"
            >
              <option v-for="v in variable.values" :key="v" :value="v">
                {{ v }}
              </option>
            </select>
          </label>
        </div>
        <!-- Cuándo cambia: una regla por cada valor al que puede pasar. -->
        <div class="flex flex-col gap-1.5">
          <label
            v-for="destino in targets(variable)"
            :key="destino"
            class="flex flex-wrap items-center gap-2 !m-0 text-xs"
          >
            <span class="shrink-0 text-slate-700 dark:text-slate-200">
              {{
                destino === any
                  ? t('VARIABLE_SAVE_WHEN')
                  : t('VARIABLE_TO_WHEN', { value: destino })
              }}
            </span>
            <input
              type="text"
              maxlength="200"
              class="flex-1 min-w-[12rem] !mb-0 !h-8 text-sm"
              :value="ruleText(variable, destino)"
              :placeholder="t('VARIABLE_WHEN_PLACEHOLDER')"
              :disabled="disabled"
              @change="setRule(indice, destino, $event.target.value)"
            />
          </label>
        </div>
      </div>
      <woot-button
        v-if="value.length < 10"
        size="small"
        variant="clear"
        icon="add"
        class="self-start"
        :is-disabled="disabled"
        @click="add"
      >
        {{ t('VARIABLES_ADD') }}
      </woot-button>
    </div>
  </div>
</template>
