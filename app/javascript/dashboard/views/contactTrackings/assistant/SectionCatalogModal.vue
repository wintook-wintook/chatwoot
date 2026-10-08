<script>
// proyecto@asistente_agentes_ia — BUSCAR UNA SECCIÓN QUE YA EXISTE
// ============================================================================
// Hermano de RouteCatalogModal, para el otro lado del árbol: las secciones enteras
// que la cuenta ya escribió, con su contenido, para copiar una de un agente que
// funciona en vez de escribirla de cero.
//
// Muestra el texto completo de cada una, no un resumen: el nombre es lo fácil de
// acertar —para eso ya está la lista de "Agregar sección"—, lo que cuesta es lo que
// va escrito adentro, y eso solo se juzga leyéndolo.
//
// El mismo nombre aparece varias veces cuando está escrito distinto en distintos
// agentes: comparar esas versiones es justamente para qué sirve la pantalla. Las
// que el agente YA tiene no se listan: dos rótulos iguales lo confunden —no sabe
// cuál de los dos aplica—, así que no hay nada que hacer con ellas.
// ============================================================================
export default {
  props: {
    show: { type: Boolean, default: false },
    // [{ title, body, style, lines, agents: [...] }] — TrainingSectionCatalog.
    sections: { type: Array, default: () => [] },
    isLoading: { type: Boolean, default: false },
    // Los nombres que el agente ya tiene: dos rótulos iguales lo confunden.
    takenTitles: { type: Array, default: () => [] },
  },
  emits: ['close', 'pick'],
  data() {
    return {
      query: '',
    };
  },
  computed: {
    upperTaken() {
      return this.takenTitles.map(t => (t || '').toUpperCase());
    },
    // Sin las que el agente ya tiene: dos rótulos iguales lo confunden, así que no
    // hay nada que hacer con ellas.
    available() {
      return this.sections.filter(s => !this.taken(s));
    },
    // Tres motivos distintos para una lista vacía, y se dicen distinto.
    emptyMessage() {
      const clave = !this.sections.length
        ? 'SECTION_FIND_EMPTY'
        : this.available.length
        ? 'ROUTE_FIND_NO_MATCH'
        : 'SECTION_FIND_ALL_TAKEN';
      return this.$t(`TRACKING_TEMPLATES.FORM.TRAINING.${clave}`);
    },
    filtered() {
      const q = this.query.trim().toLowerCase();
      if (!q) return this.available;
      return this.available.filter(s =>
        [s.title, s.body, (s.agents || []).join(' ')]
          .join(' ')
          .toLowerCase()
          .includes(q)
      );
    },
  },
  watch: {
    show(abierto) {
      if (abierto) this.query = '';
    },
  },
  methods: {
    taken(section) {
      return this.upperTaken.includes((section.title || '').toUpperCase());
    },
    pick(section) {
      if (this.taken(section)) return;
      this.$emit('pick', { title: section.title, body: section.body });
    },
  },
};
</script>

<template>
  <woot-modal :show="show" size="medium" :on-close="() => $emit('close')">
    <div class="flex flex-col gap-4 p-8 text-sm max-h-[85vh]">
      <div class="shrink-0">
        <h2 class="!m-0 text-lg font-medium text-slate-800 dark:text-slate-100">
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.SECTION_FIND_TITLE') }}
        </h2>
        <p class="!mt-1 !mb-0 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.SECTION_FIND_HINT') }}
        </p>
      </div>

      <input
        id="section-catalog-search"
        v-model="query"
        type="text"
        class="w-full !mb-0 shrink-0"
        :placeholder="
          $t('TRACKING_TEMPLATES.FORM.TRAINING.SECTION_FIND_SEARCH')
        "
      />

      <p
        v-if="isLoading"
        class="!m-0 text-xs text-slate-500 dark:text-slate-400"
      >
        {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.SECTION_FIND_LOADING') }}
      </p>
      <p
        v-else-if="!filtered.length"
        class="!m-0 py-6 text-xs text-center text-slate-500 dark:text-slate-400"
      >
        {{ emptyMessage }}
      </p>

      <div class="flex flex-col flex-1 min-h-0 gap-2 overflow-y-auto">
        <div
          v-for="(seccion, i) in filtered"
          :key="`${seccion.title}-${i}`"
          class="p-3 border rounded-md border-slate-200 dark:border-slate-600"
        >
          <div class="flex items-start gap-2">
            <div class="flex-1 min-w-0">
              <p
                class="!m-0 text-xs font-semibold tracking-wide uppercase text-slate-800 dark:text-slate-100"
              >
                {{ seccion.title }}
                <span class="font-normal normal-case text-slate-400">
                  {{
                    $t('TRACKING_TEMPLATES.FORM.TRAINING.LINES', {
                      count: seccion.lines,
                    })
                  }}
                </span>
              </p>
              <p
                class="!mt-0.5 !mb-0 text-xs text-slate-500 dark:text-slate-400"
              >
                {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_FIND_AGENTS') }}:
                {{ (seccion.agents || []).join(' · ') }}
              </p>
            </div>
            <woot-button
              size="tiny"
              variant="smooth"
              color-scheme="success"
              icon="add"
              @click="pick(seccion)"
            >
              {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_FIND_USE') }}
            </woot-button>
          </div>

          <!-- El texto completo, en su forma: una sección se juzga leyéndola. -->
          <pre
            class="!m-0 mt-2 p-2 text-xs whitespace-pre-wrap rounded bg-slate-50 dark:bg-slate-900 text-slate-700 dark:text-slate-300 max-h-48 overflow-y-auto"
            >{{ seccion.body }}</pre
          >
        </div>
      </div>

      <div class="flex items-center justify-end shrink-0">
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click="$emit('close')"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_MODAL_CANCEL') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
