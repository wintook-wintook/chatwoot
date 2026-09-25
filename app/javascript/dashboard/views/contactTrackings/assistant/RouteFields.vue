<script>
// proyecto@asistente_agentes_ia — LOS CAMPOS DE UNA RAMA
// ============================================================================
// Una rama es una línea con gramática exacta:
//
//   @ruta(comercial #precios: cuanto cuesta, precios): {{hoja:Precios}} -> @crear_ticket(tipo=Comercial)
//    │       │        │              │                        │                     │
//    │     nombre  etiqueta      frases del cliente         fuente             escalamiento
//
// Acá se edita campo por campo, y fuente, etiqueta, tipo de caso y acción salen de
// LISTAS del inventario de la cuenta: así no se puede elegir algo que no exista —de
// ahí salieron los dos defectos que se vieron en vivo, el "cuesta 15" con la hoja
// equivocada y el calendario borrado que dejó al agente sin disponibilidad.
//
// Solo edita campos: la línea la arma Ruby (ContactTrackings::TrainingRoutes). Lo usa
// RouteModal, que es por donde se agregan y se editan las ramas.
// ============================================================================

// Las prioridades que entiende @crear_ticket(prioridad=…), en las palabras que acepta
// el motor (Cases::TicketCreatorService::PRIORITY_ALIASES).
const PRIORITIES = ['baja', 'media', 'alta', 'urgente'];
const CREATE_TICKET = '@crear_ticket';

import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { emitter } from 'shared/helpers/mitt';
import KnowledgeBaseAPI from 'dashboard/routes/dashboard/settings/knowledgeSources/api';
import AddSourceModal from 'dashboard/routes/dashboard/settings/knowledgeSources/AddSourceModal.vue';
import ProofreadBar from './ProofreadBar.vue';
import {
  sourceFromDirective,
  integrationFromDirective,
  ASSISTANT_SOURCES_CHANGED,
} from './sourceDirective';

export default {
  components: { ProofreadBar, AddSourceModal },
  props: {
    // La rama: { name, tag, description, source, action, case_type, priority, … }
    route: { type: Object, default: () => ({}) },
    // { sources: [...], labels: [...], caseTypes: [...], actions: [...] }
    options: { type: Object, default: () => ({}) },
    // Prefijo de los `id` de los campos: dos formularios en la misma página no
    // pueden repetirlos, o quien busca uno se lleva el otro.
    idPrefix: { type: String, default: 'route' },
    // "Mejorar la redacción" en las frases (endpoint del Asistente, solo admins).
    canProofread: { type: Boolean, default: false },
    inboxId: { type: Number, default: null },
  },
  emits: ['input'],
  data() {
    return { showAddSource: false, savingSource: false };
  },
  computed: {
    ...mapGetters({ accountId: 'getCurrentAccountId' }),
    // La fuente escrita no está entre las de la cuenta (pedido del usuario, 25/09/2026:
    // poder crearla sin salir del Asistente).
    missingSource() {
      return Boolean(this.extraOption(this.route.source, this.sourceOptions));
    },
    // { source_type, name } si se puede crear en la Base de Conocimiento; null si no
    // (una directiva de predefinidas o de artículos).
    addableSource() {
      return this.missingSource ? sourceFromDirective(this.route.source) : null;
    },
    // @discourse: la integración de Discourse del canal, que se conecta en
    // Integraciones (no se crea como fuente).
    missingIntegration() {
      return this.missingSource
        ? integrationFromDirective(this.route.source)
        : null;
    },
    integrationUrl() {
      if (!this.missingIntegration) return '';
      return this.$router.resolve({
        name: 'settings_applications_integration',
        params: {
          accountId: this.accountId,
          integration_id: this.missingIntegration,
        },
      }).href;
    },
    sourceOptions() {
      return this.options.sources || [];
    },
    labelOptions() {
      return this.options.labels || [];
    },
    caseTypeOptions() {
      return this.options.caseTypes || [];
    },
    priorityOptions() {
      return PRIORITIES;
    },
    // Lo que una rama puede hacer cuando la fuente no resolvió el turno: abrir un
    // caso —y ahí el tipo y la prioridad se eligen aparte, porque son tres decisiones
    // distintas— o una de las acciones del inventario.
    escalationOptions() {
      return [CREATE_TICKET, ...(this.options.actions || [])];
    },
    opensCase() {
      return this.route.action === CREATE_TICKET;
    },
    // Ni fuente ni «si no resuelve»: contesta solo con el Entrenamiento. Es el mismo
    // aviso ámbar del comprobador (ValidatorService#check_routes_doing_nothing), acá
    // a la vista mientras se edita. No impide guardar: a veces es a propósito.
    doesNothing() {
      return (
        !(this.route.source || '').trim() && !(this.route.action || '').trim()
      );
    },
    // Las listas llegan del inventario DESPUÉS del primer pintado. Un <select> con
    // :value (no v-model) no vuelve a aplicar el valor cuando aparecen sus opciones,
    // y el campo se veía vacío aunque la rama tuviera el tipo de caso escrito. Esto
    // lo vuelve a crear cuando las listas cambian, que pasa una vez al abrir.
    optionsKey() {
      return [
        this.sourceOptions.length,
        this.labelOptions.length,
        this.caseTypeOptions.length,
        this.escalationOptions.length,
      ].join('-');
    },
  },
  methods: {
    update(changes) {
      this.$emit('input', { ...this.route, ...changes });
    },
    // Elegir otra acción se lleva el tipo y la prioridad, que son solo de abrir caso.
    setAction(accion) {
      this.update(
        accion === CREATE_TICKET
          ? { action: accion }
          : { action: accion, case_type: '', priority: '' }
      );
    },
    // Un valor guardado que no está en la lista se ofrece igual, marcado: puede ser
    // una fuente que se borró de la cuenta, y hacerlo desaparecer del selector lo
    // cambiaría sin avisar.
    extraOption(valor, lista) {
      return valor && !lista.includes(valor) ? valor : null;
    },
    // Crea la fuente con el mismo modal y la misma API de la Base de Conocimiento, y
    // avisa al Asistente para que recargue sus fuentes y vuelva a comprobar.
    async createSource(payload) {
      this.savingSource = true;
      try {
        await KnowledgeBaseAPI.createSource(this.accountId, payload);
        this.showAddSource = false;
        useAlert(
          this.$t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SOURCE_ADDED')
        );
        emitter.emit(ASSISTANT_SOURCES_CHANGED);
      } catch (error) {
        const detalle =
          error?.response?.data?.errors?.[0] || error?.response?.data?.error;
        useAlert(
          detalle ||
            this.$t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SOURCE_ADD_ERROR')
        );
      } finally {
        this.savingSource = false;
      }
    },
    marca(valor) {
      return this.$t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_UNKNOWN', {
        value: valor,
      });
    },
  },
};
</script>

<template>
  <div
    class="p-3 border rounded-md border-slate-200 dark:border-slate-600 bg-slate-25 dark:bg-slate-800"
  >
    <div class="flex flex-wrap items-end gap-2">
      <div class="flex-1 min-w-[10rem]">
        <label
          :for="`${idPrefix}-name`"
          class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_NAME') }}
        </label>
        <input
          :id="`${idPrefix}-name`"
          :value="route.name"
          type="text"
          class="w-full !mb-0 !py-1 font-mono text-xs"
          :placeholder="
            $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_NAME_PLACEHOLDER')
          "
          @input="update({ name: $event.target.value })"
        />
      </div>
      <div class="w-40">
        <label
          :for="`${idPrefix}-tag`"
          class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_TAG') }}
        </label>
        <select
          :id="`${idPrefix}-tag`"
          :key="`tag-${optionsKey}`"
          :value="route.tag"
          class="w-full !mb-0 !py-1 text-xs"
          @change="update({ tag: $event.target.value })"
        >
          <option value="">
            {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_TAG_NONE') }}
          </option>
          <option
            v-for="etiqueta in labelOptions"
            :key="`t-${etiqueta}`"
            :value="etiqueta"
          >
            #{{ etiqueta }}
          </option>
          <option
            v-if="extraOption(route.tag, labelOptions)"
            :value="route.tag"
          >
            {{ marca(`#${route.tag}`) }}
          </option>
        </select>
      </div>
    </div>

    <label
      :for="`${idPrefix}-desc`"
      class="!mb-1 mt-2 text-xs text-slate-500 dark:text-slate-400"
    >
      {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_PHRASES') }}
    </label>
    <textarea
      :id="`${idPrefix}-desc`"
      :value="route.description"
      rows="4"
      class="w-full !mb-0 min-h-[5rem] text-sm bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2"
      :placeholder="
        $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_PHRASES_PLACEHOLDER')
      "
      @input="update({ description: $event.target.value })"
    />
    <!-- Las frases NO se formalizan: el clasificador las compara con mensajes
         reales de clientes (ver Proofreader, kind route_phrases). -->
    <ProofreadBar
      v-if="canProofread"
      :text="route.description || ''"
      kind="route_phrases"
      :inbox-id="inboxId"
      @input="update({ description: $event })"
    />

    <div class="flex flex-wrap gap-2 mt-2">
      <div class="flex-1 min-w-[12rem]">
        <label
          :for="`${idPrefix}-source`"
          class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SOURCE') }}
        </label>
        <select
          :id="`${idPrefix}-source`"
          :key="`src-${optionsKey}`"
          :value="route.source"
          class="w-full !mb-0 !py-1 font-mono text-xs"
          @change="update({ source: $event.target.value })"
        >
          <option value="">
            {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SOURCE_NONE') }}
          </option>
          <option
            v-for="fuente in sourceOptions"
            :key="`s-${fuente}`"
            :value="fuente"
          >
            {{ fuente }}
          </option>
          <option
            v-if="extraOption(route.source, sourceOptions)"
            :value="route.source"
          >
            {{ marca(route.source) }}
          </option>
        </select>
        <p
          v-if="missingIntegration"
          class="flex flex-wrap items-center gap-2 !mt-1 !mb-0 text-xs text-amber-800 dark:text-amber-800"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_INTEGRATION_MISSING') }}
          <a
            :href="integrationUrl"
            target="_blank"
            rel="noopener noreferrer"
            class="font-medium underline"
          >
            {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_INTEGRATION_OPEN') }}
          </a>
        </p>
        <p
          v-else-if="missingSource"
          class="flex flex-wrap items-center gap-2 !mt-1 !mb-0 text-xs text-amber-800 dark:text-amber-800"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SOURCE_MISSING') }}
          <woot-button
            v-if="addableSource"
            size="tiny"
            variant="smooth"
            icon="add"
            @click="showAddSource = true"
          >
            {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SOURCE_ADD') }}
          </woot-button>
        </p>
        <AddSourceModal
          v-if="addableSource"
          :show="showAddSource"
          :saving="savingSource"
          :initial="addableSource"
          @close="showAddSource = false"
          @save="createSource"
        />
      </div>
      <div class="flex-1 min-w-[12rem]">
        <label
          :for="`${idPrefix}-esc`"
          class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_ESCALATION') }}
        </label>
        <select
          :id="`${idPrefix}-esc`"
          :key="`esc-${optionsKey}`"
          :value="route.action"
          class="w-full !mb-0 !py-1 font-mono text-xs"
          @change="setAction($event.target.value)"
        >
          <option value="">
            {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_ESCALATION_NONE') }}
          </option>
          <option
            v-for="accion in escalationOptions"
            :key="`e-${accion}`"
            :value="accion"
          >
            {{
              accion === '@crear_ticket'
                ? $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_OPEN_CASE')
                : accion
            }}
          </option>
          <option
            v-if="extraOption(route.action, escalationOptions)"
            :value="route.action"
          >
            {{ marca(route.action) }}
          </option>
        </select>
      </div>
    </div>

    <p
      v-if="doesNothing"
      class="flex items-start gap-1 !mt-2 !mb-0 text-xs text-amber-800 dark:text-amber-800"
    >
      <fluent-icon icon="warning" size="14" class="shrink-0 mt-px" />
      {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_DOES_NOTHING') }}
    </p>

    <!-- Solo para abrir caso: de qué tipo y con qué prioridad. -->
    <div v-if="opensCase" class="flex flex-wrap gap-2 mt-2">
      <div class="flex-1 min-w-[12rem]">
        <label
          :for="`${idPrefix}-case`"
          class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_CASE_TYPE') }}
        </label>
        <select
          :id="`${idPrefix}-case`"
          :key="`case-${optionsKey}`"
          :value="route.case_type"
          class="w-full !mb-0 !py-1 text-xs"
          @change="update({ case_type: $event.target.value })"
        >
          <option value="">
            {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_CASE_TYPE_NONE') }}
          </option>
          <option
            v-for="tipo in caseTypeOptions"
            :key="`c-${tipo}`"
            :value="tipo"
          >
            {{ tipo }}
          </option>
          <option
            v-if="extraOption(route.case_type, caseTypeOptions)"
            :value="route.case_type"
          >
            {{ marca(route.case_type) }}
          </option>
        </select>
      </div>
      <div class="w-44">
        <label
          :for="`${idPrefix}-prio`"
          class="!mb-1 text-xs text-slate-500 dark:text-slate-400"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_PRIORITY') }}
        </label>
        <select
          :id="`${idPrefix}-prio`"
          :value="route.priority"
          class="w-full !mb-0 !py-1 text-xs"
          @change="update({ priority: $event.target.value })"
        >
          <option value="">
            {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_PRIORITY_NONE') }}
          </option>
          <option
            v-for="prioridad in priorityOptions"
            :key="`p-${prioridad}`"
            :value="prioridad"
          >
            {{ prioridad }}
          </option>
          <option
            v-if="extraOption(route.priority, priorityOptions)"
            :value="route.priority"
          >
            {{ marca(route.priority) }}
          </option>
        </select>
      </div>
    </div>
  </div>
</template>
