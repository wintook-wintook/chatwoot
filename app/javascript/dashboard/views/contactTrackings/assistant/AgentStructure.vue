<script>
// proyecto@asistente_agentes_ia — LA COLUMNA DE LA ESTRUCTURA
// ============================================================================
// Plan: docs/estructura_agente_arbol_plan.md. Junta el árbol con sus tres modales y
// aplica los cambios sobre los bloques. Existe para que Assistant.vue no cargue con
// esto: ahí solo se pone el componente y se escucha qué cambió.
//
// Lo que entra: la estructura del backend ({ blocks }) y la definición del agente.
// Lo que sale: `input` con la estructura nueva —el texto lo arma Ruby— y
// `updateDefinition` con el objetivo y el contexto, que NO son parte del texto.
// ============================================================================
import TrainingTree from './TrainingTree.vue';
import RouteModal from './RouteModal.vue';
import SectionModal from './SectionModal.vue';
import DefinitionModal from './DefinitionModal.vue';
import VariablesModal from './VariablesModal.vue';
import ConstantsModal from './ConstantsModal.vue';
import RouteCatalogModal from './RouteCatalogModal.vue';
import SectionCatalogModal from './SectionCatalogModal.vue';
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';
import {
  addRoute,
  addSection,
  defaultRouteName,
  reorderRoute,
  reorderSection,
  removeBlock,
  removeRoute,
  replaceRoute,
  routeLines,
  routeNames,
  scopeTextFor,
  scopeTitleFrom,
  setDefaultRoute,
  setScopeLine,
  updateBlock,
  withGaps,
  withUids,
} from './trainingBlocks';
import {
  moveStrayVariables,
  readVariables,
  strayVariables,
  writeVariables,
} from './agentVariables';
import { constantUsage, readConstants, writeConstants } from './agentConstants';

export default {
  components: {
    TrainingTree,
    RouteModal,
    SectionModal,
    DefinitionModal,
    VariablesModal,
    ConstantsModal,
    RouteCatalogModal,
    SectionCatalogModal,
  },
  props: {
    value: { type: Object, default: () => ({ blocks: [] }) },
    definition: { type: Object, default: null },
    titles: {
      type: Object,
      default: () => ({ suggested: [], from_account: [] }),
    },
    routeOptions: { type: Object, default: () => ({}) },
    // El canal elegido: con qué modelo se corrige la redacción de la definición.
    inboxId: { type: Number, default: null },
    issues: { type: Object, default: () => ({}) },
    canExplain: { type: Boolean, default: false },
  },
  emits: ['input', 'updateDefinition', 'explain'],
  data() {
    return {
      // Qué modal está abierto y sobre qué: la posición de la rama entre las ramas,
      // o el lugar del bloque en la lista.
      routeModal: { show: false, position: null },
      sectionModal: { show: false, index: null },
      definitionModal: { show: false, field: 'objective' },
      variablesModal: { show: false },
      constantsModal: { show: false },
      // El catálogo de ramas de la cuenta se pide una vez, al abrir el buscador.
      catalogModal: { show: false, loading: false },
      catalog: null,
      sectionCatalogModal: { show: false, loading: false },
      sectionCatalog: null,
    };
  },
  computed: {
    blocks() {
      return withUids(this.value?.blocks);
    },
    scopeTitle() {
      return scopeTitleFrom(this.titles.suggested);
    },
    editingRoute() {
      const { position } = this.routeModal;
      if (position === null) return null;
      return routeLines(this.blocks)[position] || null;
    },
    // Los nombres de las ramas que el agente tiene ahora.
    currentRouteNames() {
      return routeNames(this.blocks);
    },
    // Al editar, su propio nombre no cuenta como "ya en uso".
    takenRouteNames() {
      const nombres = this.currentRouteNames;
      if (!this.editingRoute) return nombres;
      return nombres.filter(n => n !== this.editingRoute.name);
    },
    editingRouteScope() {
      return this.editingRoute
        ? scopeTextFor(this.blocks, this.editingRoute.name)
        : '';
    },
    editingRouteIsDefault() {
      return Boolean(
        this.editingRoute &&
          this.editingRoute.name === defaultRouteName(this.blocks)
      );
    },
    editingSection() {
      const { index } = this.sectionModal;
      return index === null ? null : this.blocks[index] || null;
    },
    // F1: la sección [VARIABLES] leída como lista, y las que están escritas fuera (V5).
    currentVariables() {
      return readVariables(this.blocks);
    },
    // F2: [DATOS FIJOS] como lista, dónde se usa cada uno y a qué variables puede
    // guardar una pregunta.
    currentConstants() {
      return readConstants(this.blocks);
    },
    constantsUsage() {
      return constantUsage(this.blocks, this.currentConstants.constants);
    },
    constantNames() {
      return this.currentConstants.constants.map(c => c.name);
    },
    variableNames() {
      return this.currentVariables.variables.map(v => v.name);
    },
    strayVariablesCount() {
      return strayVariables(this.blocks).length;
    },
    takenTitles() {
      return this.blocks.filter(b => b.type === 'section').map(b => b.title);
    },
  },
  methods: {
    emitBlocks(blocks) {
      this.$emit('input', { ...this.value, blocks });
    },
    // ── ramas ────────────────────────────────────────────────────────────────
    openAddRoute() {
      this.routeModal = { show: true, position: null };
    },
    openEditRoute(position) {
      this.routeModal = { show: true, position };
    },
    closeRouteModal() {
      this.routeModal = { show: false, position: null };
    },
    saveRoute({ route, previousName, scope, isDefault }) {
      const { position } = this.routeModal;
      let blocks =
        position === null
          ? addRoute(this.blocks, route, scope, this.scopeTitle)
          : replaceRoute(this.blocks, position, route);
      // Al editar, la línea de alcance se reescribe (y se renombra si cambió el
      // nombre); al agregar, addRoute ya la dejó escrita.
      if (position !== null) {
        blocks = setScopeLine(
          blocks,
          { previousName, name: route.name, scope },
          this.scopeTitle
        );
      }
      // La rama por defecto: se apunta a esta, o se saca si era esta y se destildó.
      const actual = defaultRouteName(blocks);
      if (isDefault) blocks = setDefaultRoute(blocks, route.name);
      else if (actual === route.name || actual === previousName)
        blocks = setDefaultRoute(blocks, '');
      this.closeRouteModal();
      this.emitBlocks(withGaps(blocks));
    },
    // Cambiar de lugar una rama, arrastrándola.
    reorderRoute({ from, to }) {
      const blocks = reorderRoute(this.blocks, from, to);
      if (blocks !== this.blocks) this.emitBlocks(blocks);
    },
    deleteRoute() {
      const { position } = this.routeModal;
      if (position === null) return;
      const blocks = removeRoute(this.blocks, position);
      this.closeRouteModal();
      this.emitBlocks(withGaps(blocks));
    },
    // Copiar una rama que la cuenta ya escribió.
    async openRouteCatalog() {
      this.catalogModal = { show: true, loading: this.catalog === null };
      if (this.catalog !== null) return;
      try {
        const { data } = await TrackingTemplatesAPI.getRouteCatalog();
        this.catalog = data;
      } catch (error) {
        this.catalog = [];
      } finally {
        this.catalogModal = { show: true, loading: false };
      }
    },
    // Llega con sus dos mitades: la rama y su línea de alcance (ver RouteCatalogModal).
    pickFromCatalog({ route, scope }) {
      this.catalogModal = { show: false, loading: false };
      this.emitBlocks(
        withGaps(addRoute(this.blocks, route, scope, this.scopeTitle))
      );
    },
    // ── secciones ────────────────────────────────────────────────────────────
    openAddSection() {
      this.sectionModal = { show: true, index: null };
    },
    openEditSection(index) {
      this.sectionModal = { show: true, index };
    },
    closeSectionModal() {
      this.sectionModal = { show: false, index: null };
    },
    saveSection({ title, body }) {
      const { index } = this.sectionModal;
      let blocks;
      if (index === null) {
        blocks = addSection(this.blocks, title);
        blocks = updateBlock(blocks, blocks.length - 1, { body });
      } else if (this.blocks[index].type === 'preamble') {
        blocks = updateBlock(this.blocks, index, { text: body });
      } else if (this.blocks[index].broken) {
        // Rótulo mal escrito («[ESTILO»): guardarla desde el formulario lo escribe de
        // nuevo, bien. Sin el rótulo original, el backend lo arma con el título.
        blocks = updateBlock(this.blocks, index, {
          title,
          body,
          header: '',
          broken: false,
        });
      } else {
        blocks = updateBlock(this.blocks, index, { title, body });
      }
      this.closeSectionModal();
      this.emitBlocks(blocks);
    },
    // Cambiar de lugar una sección, arrastrándola: el agente las lee en el orden en
    // que están.
    reorderSection({ from, to }) {
      const blocks = reorderSection(this.blocks, from, to);
      if (blocks !== this.blocks) this.emitBlocks(blocks);
    },
    deleteSection() {
      const { index } = this.sectionModal;
      if (index === null) return;
      const blocks = removeBlock(this.blocks, index);
      this.closeSectionModal();
      this.emitBlocks(blocks);
    },
    // Copiar una sección entera que la cuenta ya escribió.
    async openSectionCatalog() {
      this.sectionCatalogModal = {
        show: true,
        loading: this.sectionCatalog === null,
      };
      if (this.sectionCatalog !== null) return;
      try {
        const { data } = await TrackingTemplatesAPI.getSectionCatalog();
        this.sectionCatalog = data;
      } catch (error) {
        this.sectionCatalog = [];
      } finally {
        this.sectionCatalogModal = { show: true, loading: false };
      }
    },
    pickSectionFromCatalog({ title, body }) {
      this.sectionCatalogModal = { show: false, loading: false };
      const blocks = addSection(this.blocks, title);
      this.emitBlocks(updateBlock(blocks, blocks.length - 1, { body }));
    },
    // ── variables (F1) ───────────────────────────────────────────────────────
    // focus: null (la lista), un índice (una) o 'new' (agregar), desde el árbol.
    openVariables(focus = null) {
      this.variablesModal = { show: true, focus };
    },
    removeVariable(index) {
      const actuales = this.currentVariables;
      this.emitBlocks(
        writeVariables(this.blocks, {
          ...actuales,
          variables: actuales.variables.filter((_, i) => i !== index),
        })
      );
    },
    saveVariables(data) {
      this.variablesModal = { show: false };
      this.emitBlocks(writeVariables(this.blocks, data));
    },
    // Con el modal abierto: la lista se recarga sola cuando vuelven los bloques.
    moveStray() {
      this.emitBlocks(moveStrayVariables(this.blocks));
    },
    // ── datos fijos (F2) ─────────────────────────────────────────────────────
    openConstants(focus = null) {
      this.constantsModal = { show: true, focus };
    },
    // Las citas %NOMBRE% que queden en el texto las marca el comprobador (C1).
    removeConstant(index) {
      const actuales = this.currentConstants;
      this.emitBlocks(
        writeConstants(this.blocks, {
          ...actuales,
          constants: actuales.constants.filter((_, i) => i !== index),
        })
      );
    },
    saveConstants(data) {
      this.constantsModal = { show: false };
      this.emitBlocks(writeConstants(this.blocks, data));
    },
    // ── definición ───────────────────────────────────────────────────────────
    openDefinition(field) {
      this.definitionModal = { show: true, field };
    },
    saveDefinition(valores) {
      this.definitionModal = { show: false, field: 'objective' };
      this.$emit('updateDefinition', valores);
    },
  },
};
</script>

<template>
  <div class="flex flex-col min-h-0">
    <div class="flex-1 min-h-0 pr-1 overflow-y-auto">
      <TrainingTree
        :value="value"
        :definition="definition"
        :issues="issues"
        @editDefinition="openDefinition"
        @editVariables="openVariables"
        @removeVariable="removeVariable"
        @editConstants="openConstants"
        @removeConstant="removeConstant"
        @addRoute="openAddRoute"
        @findRoute="openRouteCatalog"
        @editRoute="openEditRoute"
        @reorderRoute="reorderRoute"
        @addSection="openAddSection"
        @findSection="openSectionCatalog"
        @editSection="openEditSection"
        @reorderSection="reorderSection"
      />
    </div>

    <RouteModal
      :show="routeModal.show"
      :options="routeOptions"
      :taken-names="takenRouteNames"
      :value="editingRoute"
      :scope-text="editingRouteScope"
      :is-default="editingRouteIsDefault"
      :can-proofread="canExplain"
      :inbox-id="inboxId"
      :constant-names="constantNames"
      @close="closeRouteModal"
      @save="saveRoute"
      @delete="deleteRoute"
    />
    <RouteCatalogModal
      :show="catalogModal.show"
      :routes="catalog || []"
      :is-loading="catalogModal.loading"
      :taken-names="currentRouteNames"
      @close="catalogModal = { show: false, loading: false }"
      @pick="pickFromCatalog"
    />
    <SectionCatalogModal
      :show="sectionCatalogModal.show"
      :sections="sectionCatalog || []"
      :is-loading="sectionCatalogModal.loading"
      :taken-titles="takenTitles"
      @close="sectionCatalogModal = { show: false, loading: false }"
      @pick="pickSectionFromCatalog"
    />
    <SectionModal
      :show="sectionModal.show"
      :block="editingSection"
      :titles="titles"
      :taken-titles="takenTitles"
      :can-explain="canExplain"
      :inbox-id="inboxId"
      :constant-names="constantNames"
      @close="closeSectionModal"
      @save="saveSection"
      @delete="deleteSection"
      @explain="$emit('explain', $event)"
    />
    <VariablesModal
      :show="variablesModal.show"
      :value="currentVariables"
      :focus="variablesModal.focus"
      :stray-count="strayVariablesCount"
      @close="variablesModal = { show: false }"
      @save="saveVariables"
      @moveStray="moveStray"
    />
    <ConstantsModal
      :show="constantsModal.show"
      :value="currentConstants"
      :focus="constantsModal.focus"
      :variables="variableNames"
      :usage="constantsUsage"
      @close="constantsModal = { show: false }"
      @save="saveConstants"
    />
    <DefinitionModal
      :show="definitionModal.show"
      :definition="definition"
      :focus-field="definitionModal.field"
      :can-proofread="canExplain"
      :inbox-id="inboxId"
      @close="definitionModal = { show: false, field: 'objective' }"
      @save="saveDefinition"
    />
  </div>
</template>
