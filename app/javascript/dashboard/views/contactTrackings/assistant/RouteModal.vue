<script>
// proyecto@asistente_agentes_ia — AGREGAR UNA RAMA
// ============================================================================
// Agregar una rama abre este modal en vez de dejar una tarjeta vacía en la lista.
// La razón no es estética: una rama NO es solo su línea `@ruta`. La sección
// [ALCANCE POR RAMA] lleva una línea por rama —qué atiende cada una— y es lo que
// lee el modelo del agente para saber de qué habla en cada tema. Dos lugares que
// hay que escribir juntos: dejarlos separados es como quedaron los agentes reales,
// con ramas que el motor rutea y de las que la prosa no dice nada.
//
// Los campos de la rama son LOS MISMOS de la tarjeta (RouteCards en modo compacto):
// un solo lugar donde viven, para que no se desincronicen.
// ============================================================================
import RouteCards from './RouteCards.vue';

// Lo que se guarda en el bloque de ramas (ver ContactTrackings::TrainingRoutes).
const ramaVacia = () => ({
  kind: 'route',
  name: '',
  tag: '',
  description: '',
  source: '',
  escalation: '',
  action: '',
  case_type: '',
  priority: '',
  raw: '',
});

export default {
  components: { RouteCards },
  props: {
    show: { type: Boolean, default: false },
    // { sources, labels, caseTypes, actions } — ver RouteCards.
    options: { type: Object, default: () => ({}) },
    // Los nombres que ya están en uso: dos ramas con el mismo nombre no existen
    // para el motor, se queda con la primera.
    takenNames: { type: Array, default: () => [] },
  },
  emits: ['close', 'save'],
  data() {
    return {
      route: ramaVacia(),
      scope: '',
    };
  },
  computed: {
    // El nombre tal como va a quedar escrito en la línea @ruta: minúsculas y sin
    // nada que la gramática no admita (el backend limpia igual; esto lo muestra).
    cleanName() {
      return (this.route.name || '')
        .toLowerCase()
        .replace(/\s+/g, '_')
        .replace(/[^a-z0-9_-]/g, '');
    },
    nameTaken() {
      return this.takenNames.includes(this.cleanName);
    },
    canSave() {
      return Boolean(this.cleanName) && !this.nameTaken;
    },
    // La descripción es LO ÚNICO que el motor usa para elegir la rama.
    missingPhrases() {
      return !(this.route.description || '').trim();
    },
  },
  watch: {
    show(abierto) {
      if (abierto) {
        this.route = ramaVacia();
        this.scope = '';
      }
    },
  },
  methods: {
    onFields(lineas) {
      this.route = { ...lineas[0] };
    },
    save() {
      if (!this.canSave) return;
      this.$emit('save', {
        route: { ...this.route, name: this.cleanName },
        scope: this.scope.trim(),
      });
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')">
    <div class="flex flex-col gap-4 p-8 text-sm max-h-[80vh] overflow-y-auto">
      <div>
        <h2 class="!m-0 text-lg font-medium text-slate-800 dark:text-slate-100">
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_MODAL_TITLE') }}
        </h2>
        <p class="!mt-1 !mb-0 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_MODAL_HINT') }}
        </p>
      </div>

      <RouteCards
        compact
        id-prefix="modal-route"
        :lines="[route]"
        :options="options"
        @input="onFields"
      />

      <p v-if="nameTaken" class="!m-0 text-xs text-red-600 dark:text-red-400">
        {{
          $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_NAME_TAKEN', {
            name: cleanName,
          })
        }}
      </p>
      <p
        v-else-if="missingPhrases"
        class="!m-0 text-xs text-amber-600 dark:text-amber-400"
      >
        {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_NO_PHRASES') }}
      </p>

      <!-- La otra mitad de una rama: su línea en [ALCANCE POR RAMA]. -->
      <div
        class="p-3 border rounded-md border-slate-200 dark:border-slate-600 bg-slate-25 dark:bg-slate-800"
      >
        <label
          for="route-scope"
          class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SCOPE') }}
        </label>
        <textarea
          id="route-scope"
          v-model="scope"
          rows="2"
          class="w-full !mb-1 text-sm bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2"
          :placeholder="
            $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SCOPE_PLACEHOLDER')
          "
        />
        <p class="!m-0 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SCOPE_HINT') }}
        </p>
      </div>

      <div class="flex items-center justify-end gap-2">
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click="$emit('close')"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_MODAL_CANCEL') }}
        </woot-button>
        <woot-button :is-disabled="!canSave" @click="save">
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_MODAL_SAVE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
