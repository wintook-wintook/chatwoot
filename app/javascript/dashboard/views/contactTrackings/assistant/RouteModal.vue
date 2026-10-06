<script>
// proyecto@asistente_agentes_ia — AGREGAR UNA RAMA
// ============================================================================
// Agregar o editar una rama abre este modal (desde el árbol de Estructura del
// Agente, o desde las tarjetas).
// La razón no es estética: una rama NO es solo su línea `@ruta`. La sección
// [ALCANCE POR RAMA] lleva una línea por rama —qué atiende cada una— y es lo que
// lee el modelo del agente para saber de qué habla en cada tema. Dos lugares que
// hay que escribir juntos: dejarlos separados es como quedaron los agentes reales,
// con ramas que el motor rutea y de las que la prosa no dice nada.
//
// Los campos de la rama viven en RouteFields: un solo lugar, para que el modal y
// cualquier otra pantalla no se desincronicen.
// ============================================================================
import RouteFields from './RouteFields.vue';
import ProofreadBar from './ProofreadBar.vue';
import AssistantAPI from 'dashboard/api/assistant';
import { useAlert } from 'dashboard/composables';

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
  components: { RouteFields, ProofreadBar },
  props: {
    show: { type: Boolean, default: false },
    // { sources, labels, caseTypes, actions } — ver RouteFields.
    options: { type: Object, default: () => ({}) },
    // Los nombres que ya están en uso: dos ramas con el mismo nombre no existen
    // para el motor, se queda con la primera. Al editar, sin el de esta rama.
    takenNames: { type: Array, default: () => [] },
    // La rama que se está editando, o null para una nueva.
    value: { type: Object, default: null },
    // Su línea en [ALCANCE POR RAMA], sin el "nombre: " del principio.
    scopeText: { type: String, default: '' },
    // Si hoy es la rama por defecto (la línea @ruta_por_defecto apunta a ella).
    isDefault: { type: Boolean, default: false },
    // "Mejorar la redacción" (endpoint del Asistente, solo administradores).
    canProofread: { type: Boolean, default: false },
    inboxId: { type: Number, default: null },
  },
  emits: ['close', 'save', 'delete'],
  data() {
    return {
      route: ramaVacia(),
      scope: '',
      asDefault: false,
      confirmDelete: false,
      generatingScope: false,
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
    editing() {
      return Boolean(this.value);
    },
  },
  watch: {
    show(abierto) {
      if (!abierto) return;
      this.route = { ...ramaVacia(), ...(this.value || {}) };
      this.scope = this.scopeText || '';
      this.asDefault = this.isDefault;
      this.confirmDelete = false;
    },
  },
  methods: {
    onFields(rama) {
      this.route = { ...rama };
    },
    // Pedido del usuario (25/09/2026): la línea de alcance, redactada desde las frases
    // del cliente, la fuente y lo que hace si no resuelve (ScopeWriter). Reemplaza lo
    // escrito: para corregir, se edita a mano después.
    async generateScope() {
      if (this.missingPhrases || this.generatingScope) return;
      this.generatingScope = true;
      try {
        const { data } = await AssistantAPI.routeScope(
          {
            name: this.cleanName,
            phrases: this.route.description,
            source: this.route.source,
            action: this.route.action,
          },
          this.inboxId
        );
        this.scope = data.scope || this.scope;
      } catch (error) {
        useAlert(
          this.$t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SCOPE_GENERATE_ERROR')
        );
      } finally {
        this.generatingScope = false;
      }
    },
    save() {
      if (!this.canSave) return;
      this.$emit('save', {
        route: { ...this.route, name: this.cleanName },
        previousName: this.value ? this.value.name : '',
        scope: this.scope.trim(),
        isDefault: this.asDefault,
      });
    },
    remove() {
      if (!this.confirmDelete) {
        this.confirmDelete = true;
        return;
      }
      this.$emit('delete');
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
              ? $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_MODAL_EDIT')
              : $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_MODAL_TITLE')
          }}
        </h2>
        <p class="!mt-1 !mb-0 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_MODAL_HINT') }}
        </p>
      </div>

      <RouteFields
        id-prefix="modal-route"
        :route="route"
        :options="options"
        :can-proofread="canProofread"
        :inbox-id="inboxId"
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
        class="!m-0 text-xs text-amber-800 dark:text-amber-800"
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
        <div class="flex flex-wrap items-center gap-2 mb-1">
          <woot-button
            v-if="canProofread"
            size="tiny"
            variant="smooth"
            icon="wand"
            :is-loading="generatingScope"
            :is-disabled="missingPhrases || generatingScope"
            :title="
              missingPhrases
                ? $t(
                    'TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SCOPE_NEEDS_PHRASES'
                  )
                : ''
            "
            @click="generateScope"
          >
            {{
              scope.trim()
                ? $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SCOPE_REGENERATE')
                : $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SCOPE_GENERATE')
            }}
          </woot-button>
        </div>
        <ProofreadBar
          v-if="canProofread"
          :text="scope"
          kind="route_scope"
          :inbox-id="inboxId"
          @input="scope = $event"
        />
        <p class="!m-0 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SCOPE_HINT') }}
        </p>
      </div>

      <!-- La rama por defecto: a la que van los mensajes que no caen en ninguna. -->
      <label class="flex items-center gap-2 !mb-0 text-xs">
        <input v-model="asDefault" type="checkbox" class="!m-0" />
        <span class="text-slate-600 dark:text-slate-300">
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_AS_DEFAULT') }}
        </span>
      </label>

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
              ? $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_DELETE_CONFIRM')
              : $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_DELETE')
          }}
        </woot-button>
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click="$emit('close')"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_MODAL_CANCEL') }}
        </woot-button>
        <woot-button :is-disabled="!canSave" @click="save">
          {{
            editing
              ? $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_MODAL_APPLY')
              : $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_MODAL_SAVE')
          }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
