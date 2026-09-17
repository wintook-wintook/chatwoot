<script>
// proyecto@asistente_agentes_ia — UNA SECCIÓN DEL ENTRENAMIENTO
// ============================================================================
// Plan: docs/estructura_agente_arbol_plan.md. El nombre de la sección y su contenido
// en una caja amplia: medido sobre 28 agentes, hay secciones de decenas de líneas, y
// escribirlas en una caja de tres renglones era el defecto de la pantalla anterior.
//
// El "texto inicial" (lo que va antes de la primera sección) usa el mismo modal sin
// el campo de nombre: es un bloque sin rótulo, y ponerle nombre lo convertiría en
// una sección.
// ============================================================================
export default {
  props: {
    show: { type: Boolean, default: false },
    // El bloque que se edita, o null para una sección nueva.
    block: { type: Object, default: null },
    // { suggested: [...], from_account: [...] } — nombres que ofrece el backend.
    titles: {
      type: Object,
      default: () => ({ suggested: [], from_account: [] }),
    },
    // Los nombres ya usados: dos secciones con el mismo rótulo confunden al modelo.
    takenTitles: { type: Array, default: () => [] },
    // Se puede explicar (endpoint del Asistente, solo administradores).
    canExplain: { type: Boolean, default: false },
  },
  emits: ['close', 'save', 'delete', 'explain'],
  data() {
    return {
      title: '',
      body: '',
      confirmDelete: false,
    };
  },
  computed: {
    editing() {
      return Boolean(this.block);
    },
    // El texto inicial no lleva rótulo: es lo que lo hace texto inicial.
    isPreamble() {
      return this.block?.type === 'preamble';
    },
    cleanTitle() {
      return (this.title || '').replace(/[[\]\n\r]/g, ' ').trim();
    },
    titleTaken() {
      const propio = (this.block?.title || '').toUpperCase();
      const nombre = this.cleanTitle.toUpperCase();
      return (
        nombre !== propio &&
        this.takenTitles.some(t => (t || '').toUpperCase() === nombre)
      );
    },
    canSave() {
      return (this.isPreamble || Boolean(this.cleanTitle)) && !this.titleTaken;
    },
    // Las que el agente todavía no usa, para ofrecerlas con un clic.
    suggestions() {
      const usados = new Set(
        this.takenTitles.map(t => (t || '').toUpperCase())
      );
      const libres = lista =>
        (lista || []).filter(t => !usados.has(t.toUpperCase()));
      return [
        ...libres(this.titles.suggested),
        ...libres(this.titles.from_account),
      ].slice(0, 12);
    },
  },
  watch: {
    show(abierto) {
      if (!abierto) return;
      this.title = this.block?.title || '';
      this.body = this.isPreamble
        ? this.block?.text || ''
        : this.block?.body || '';
      this.confirmDelete = false;
    },
  },
  methods: {
    save() {
      if (!this.canSave) return;
      this.$emit('save', { title: this.cleanTitle, body: this.body });
    },
    remove() {
      if (!this.confirmDelete) {
        this.confirmDelete = true;
        return;
      }
      this.$emit('delete');
    },
    explain() {
      const rotulo = this.block?.header || `[${this.cleanTitle}]`;
      const fragmento = [this.isPreamble ? '' : rotulo, this.body]
        .filter(Boolean)
        .join('\n')
        .trim();
      if (fragmento) this.$emit('explain', fragmento);
    },
  },
};
</script>

<template>
  <woot-modal :show="show" size="medium" :on-close="() => $emit('close')">
    <div class="flex flex-col gap-4 p-8 text-sm max-h-[85vh] overflow-y-auto">
      <div>
        <h2 class="!m-0 text-lg font-medium text-slate-800 dark:text-slate-100">
          {{
            editing
              ? $t('TRACKING_TEMPLATES.FORM.TRAINING.SECTION_MODAL_EDIT')
              : $t('TRACKING_TEMPLATES.FORM.TRAINING.SECTION_MODAL_TITLE')
          }}
        </h2>
        <p class="!mt-1 !mb-0 text-xs text-slate-500 dark:text-slate-400">
          {{
            isPreamble
              ? $t('TRACKING_TEMPLATES.FORM.TRAINING.SECTION_MODAL_PREAMBLE')
              : $t('TRACKING_TEMPLATES.FORM.TRAINING.SECTION_MODAL_HINT')
          }}
        </p>
      </div>

      <div v-if="!isPreamble">
        <label
          for="section-modal-title"
          class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.SECTION_NAME') }}
        </label>
        <input
          id="section-modal-title"
          v-model="title"
          type="text"
          class="w-full !mb-1 !py-1 font-mono text-xs font-semibold uppercase"
          :placeholder="$t('TRACKING_TEMPLATES.FORM.TRAINING.CUSTOM')"
        />
        <p
          v-if="titleTaken"
          class="!m-0 text-xs text-red-600 dark:text-red-400"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.SECTION_NAME_TAKEN') }}
        </p>
        <div v-if="!editing" class="flex flex-wrap gap-1 mt-1">
          <button
            v-for="sugerido in suggestions"
            :key="sugerido"
            type="button"
            class="px-2 py-0.5 text-xs font-mono border rounded border-slate-200 dark:border-slate-600 hover:border-woot-400"
            @click="title = sugerido"
          >
            {{ sugerido }}
          </button>
        </div>
      </div>

      <div>
        <label
          for="section-modal-body"
          class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.SECTION_MODAL_BODY') }}
        </label>
        <textarea
          id="section-modal-body"
          v-model="body"
          rows="18"
          class="w-full !mb-0 min-h-[24rem] text-sm bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2"
          :placeholder="$t('TRACKING_TEMPLATES.FORM.TRAINING.BODY_PLACEHOLDER')"
        />
      </div>

      <div class="flex items-center justify-end gap-2">
        <woot-button
          v-if="editing"
          class="mr-auto"
          :variant="confirmDelete ? 'smooth' : 'clear'"
          color-scheme="alert"
          icon="delete"
          @click="remove"
        >
          {{
            confirmDelete
              ? $t('TRACKING_TEMPLATES.FORM.TRAINING.CONFIRM_DELETE')
              : $t('TRACKING_TEMPLATES.FORM.TRAINING.DELETE')
          }}
        </woot-button>
        <woot-button
          v-if="canExplain && editing"
          variant="clear"
          color-scheme="secondary"
          icon="info"
          @click="explain"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.EXPLAIN') }}
        </woot-button>
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click="$emit('close')"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_MODAL_CANCEL') }}
        </woot-button>
        <woot-button :is-disabled="!canSave" @click="save">
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.SECTION_MODAL_SAVE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
