<!--
  ================================================================================
  proyecto@tracking_templates
  ================================================================================
  Componente: Index.vue
  Descripción: La lista de Agentes IA (la única: Ajustes › Agentes IA redirige aquí).
               feat/agentes_ia_unificado (21/10/2026):
                 · pestañas Agentes · En construcción · Recursos (las dos últimas
                   salieron del Asistente, solo admin)
                 · «+ Nuevo agente ▾»: con el Asistente, desde la Galería o con el
                   formulario en blanco (este último sigue siendo inline)
                 · columna «Revisión» con el comprobador (antes otra tabla en el
                   Asistente)
                 · abrir un agente lleva a su espacio (AgentWorkspace): Entrenamiento,
                   Ficha y Versiones en una sola pantalla
  ================================================================================
-->

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import TemplateForm from './EditTemplate.vue';
import ImportModal from './ImportModal.vue'; // proyecto@import_seguimiento
import PublishPromptModal from './PublishPromptModal.vue'; // proyecto@publicar_prompts
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import AssistantAPI from 'dashboard/api/assistant';
import {
  sortRows,
  nextOrder,
  NUMBER,
  DATE,
  TEXT,
} from 'dashboard/views/contactTrackings/assistant/tableSort';
import SessionsPanel from 'dashboard/views/contactTrackings/agents/SessionsPanel.vue';
import InventoryPanel from 'dashboard/views/contactTrackings/agents/InventoryPanel.vue';

// Explícito y no armado por concatenación (igual que en el Asistente): un estado nuevo
// del backend se ve como «Sin Entrenamiento» antes que como un cartel en blanco.
// Columnas ordenables de la tabla de Agentes (el mismo ordenador que «En
// construcción»). inbox_label y review_rank se calculan por fila (sortableTemplates).
const AGENT_COLUMNS = {
  name: TEXT,
  objective: TEXT,
  inbox_label: TEXT,
  review_rank: NUMBER,
  updated_at: DATE,
};
// Para ordenar por Revisión: lo que no ejecuta arriba (y con más errores primero).
const REVIEW_RANK = { broken: 3, empty: 2, conversational: 1, routed: 0 };

const AUDIT_STATUS_LABEL = {
  broken: 'TRACKING_ASSISTANT_VIEW.AUDIT_BROKEN',
  routed: 'TRACKING_ASSISTANT_VIEW.AUDIT_ROUTED',
  conversational: 'TRACKING_ASSISTANT_VIEW.AUDIT_CONVERSATIONAL',
  empty: 'TRACKING_ASSISTANT_VIEW.AUDIT_EMPTY',
};

export default {
  components: {
    TemplateForm,
    ImportModal,
    PublishPromptModal,
    TableFooter,
    BaseSettingsHeader,
    SessionsPanel,
    InventoryPanel,
  },
  data() {
    return {
      currentView: 'list',
      formMode: 'create',
      selectedTemplate: null,
      searchQuery: '',
      selectedInboxFilter: '',
      showDeleteConfirmation: false,
      templateToDelete: null,
      showImportModal: false, // proyecto@import_seguimiento
      templateToPublish: null, // proyecto@publicar_prompts
      currentPage: 1,
      perPage: 10,
      // feat/agentes_ia_unificado
      listTab: 'agents',
      // Del más actual al menos actual por fecha de actualización (pedido del usuario).
      agentsSort: { key: 'updated_at', order: 'desc' },
      showNewMenu: false,
      openSessionsCount: null,
      // Lo que dijo el comprobador de cada agente, por id.
      auditById: {},
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'trackingTemplates/getUIFlags',
      templates: 'trackingTemplates/getTemplates',
      allInboxIds: 'trackingTemplates/getAllInboxIds',
      inboxes: 'inboxes/getInboxes',
      currentUser: 'getCurrentUser',
      currentRole: 'getCurrentRole',
    }),
    isAdmin() {
      return this.currentRole === 'administrator';
    },
    listTabs() {
      return [
        { id: 'agents', label: 'TRACKING_TEMPLATES.LIST_TABS.AGENTS' },
        this.isAdmin && {
          id: 'sessions',
          label: 'TRACKING_TEMPLATES.LIST_TABS.SESSIONS',
          count: this.openSessionsCount,
        },
        this.isAdmin && {
          id: 'resources',
          label: 'TRACKING_TEMPLATES.LIST_TABS.RESOURCES',
        },
      ].filter(Boolean);
    },
    // woot-tabs numera por POSICIÓN: dos de las tres pestañas son solo de admin, así
    // que se traduce posición ↔ pestaña (igual que en el Asistente y en la ficha).
    listTabPosition() {
      return Math.max(
        0,
        this.listTabs.findIndex(tab => tab.id === this.listTab)
      );
    },
    // proyecto@publicar_prompts — lo marca el super admin; sin él no se ve nada de publicar.
    canPublishPrompts() {
      return !!this.currentUser.can_publish_prompts;
    },
    isListView() {
      return this.currentView === 'list';
    },
    isFormView() {
      return this.currentView === 'form';
    },
    // Inboxes que están asignados a al menos una plantilla
    usedInboxes() {
      return this.allInboxIds
        .map(id => {
          const inbox = this.inboxes.find(ib => ib.id === Number(id));
          return inbox
            ? { id: inbox.id, name: inbox.name }
            : { id, name: `Inbox #${id}` };
        })
        .sort((a, b) => a.name.localeCompare(b.name));
    },
    filteredTemplates() {
      let result = this.templates;
      if (this.searchQuery) {
        const query = this.searchQuery.toLowerCase();
        result = result.filter(t => t.name.toLowerCase().includes(query));
      }
      if (this.selectedInboxFilter) {
        const inboxId = Number(this.selectedInboxFilter);
        result = result.filter(t => Number(t.inbox_id) === inboxId);
      }
      return result;
    },
    // Página actual de la lista filtrada (paginado en cliente).
    sortableTemplates() {
      return this.filteredTemplates.map(template => {
        const audit = this.auditById[template.id];
        return {
          ...template,
          inbox_label: template.inbox_id ? this.getInboxName(template) : '',
          review_rank: audit
            ? (REVIEW_RANK[audit.status] || 0) * 1000 + (audit.defects || 0)
            : -1,
        };
      });
    },
    sortedTemplates() {
      return sortRows(this.sortableTemplates, this.agentsSort, AGENT_COLUMNS);
    },
    pagedTemplates() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.sortedTemplates.slice(start, start + this.perPage);
    },
    totalPages() {
      return Math.max(
        1,
        Math.ceil(this.filteredTemplates.length / this.perPage)
      );
    },
    hasTemplates() {
      return this.templates.length > 0;
    },
    hasResults() {
      return this.filteredTemplates.length > 0;
    },
  },
  watch: {
    // Volver a la primera página al cambiar el filtro.
    searchQuery() {
      this.currentPage = 1;
    },
    selectedInboxFilter() {
      this.currentPage = 1;
    },
    // Si la lista se encoge (borrado/refetch), no quedar en página vacía.
    totalPages(pages) {
      if (this.currentPage > pages) this.currentPage = pages;
    },
  },
  async mounted() {
    if (!this.inboxes || this.inboxes.length === 0) {
      this.$store.dispatch('inboxes/get');
    }
    await this.$store.dispatch('trackingTemplates/get');
    this.openFromQuery();
    if (this.isAdmin) this.fetchAudit();
  },
  methods: {
    // proyecto@adaptar_prompts_publicados (D7) — ?edit=<id> abre la ficha de ese agente:
    // es a donde lleva «Configurar» del Asistente para la bandeja y el calendario.
    // feat/agentes_ia_unificado: también ?template_id (lo que mandaban el Asistente y
    // Ajustes). Ambos abren la ficha del agente en su espacio.
    openFromQuery() {
      const id = Number(
        this.$route.query.edit || this.$route.query.template_id
      );
      const template = id && this.templates.find(t => t.id === id);
      if (template) this.openAgent(template, 'profile');
    },
    // El espacio del agente. Sin sección, abre la primera que le toque al rol.
    openAgent(template, seccion = null) {
      this.$router.push({
        name: 'contact_trackings_agent',
        params: { templateId: String(template.id) },
        query: seccion ? { seccion } : {},
      });
    },
    newAgent(query = {}) {
      this.showNewMenu = false;
      this.$router.push({
        name: 'contact_trackings_agent',
        params: { templateId: 'new' },
        query: { seccion: 'training', ...query },
      });
    },
    // Una conversación de «En construcción»: en el espacio de su agente, o en el de
    // agente nuevo si todavía no se guardó.
    openSession(row) {
      this.$router.push({
        name: 'contact_trackings_agent',
        params: {
          templateId: row.tracking_template_id
            ? String(row.tracking_template_id)
            : 'new',
        },
        query: { seccion: 'training', session: String(row.id) },
      });
    },
    async fetchAudit() {
      try {
        const { data } = await AssistantAPI.audit();
        this.auditById = Object.fromEntries(
          (data || []).map(row => [row.id, row])
        );
      } catch (error) {
        this.auditById = {};
      }
    },
    auditFor(template) {
      return this.auditById[template.id] || null;
    },
    auditLabel(row) {
      return AUDIT_STATUS_LABEL[row.status] || AUDIT_STATUS_LABEL.empty;
    },
    // El color del woot-label: roto en rojo, con rutas en verde, el resto neutro.
    auditScheme(row) {
      if (row.status === 'broken') return 'alert';
      if (row.status === 'routed') return 'success';
      return 'secondary';
    },
    // Qué significa el estado y, si no ejecuta, el primer error.
    auditTooltip(row) {
      const estado = String(row.status || 'empty').toUpperCase();
      const significado = this.$t(`TRACKING_TEMPLATES.REVIEW.${estado}`);
      if (!row.headline) return significado;
      return `${significado} ${this.$t(
        'TRACKING_TEMPLATES.REVIEW.FIRST_ERROR',
        {
          message: row.headline,
        }
      )}`;
    },
    auditTitle(row) {
      const etiqueta = this.$t(this.auditLabel(row));
      return row.defects ? `${etiqueta} · ${row.defects}` : etiqueta;
    },
    onPageChange(page) {
      this.currentPage = page;
    },
    goToCreateForm() {
      this.showNewMenu = false;
      this.formMode = 'create';
      this.selectedTemplate = null;
      this.currentView = 'form';
    },
    goBackToList() {
      this.currentView = 'list';
      this.selectedTemplate = null;
      this.formMode = 'create';
    },
    async onFormSave(payload) {
      try {
        if (this.formMode === 'create') {
          const creado = await this.$store.dispatch(
            'trackingTemplates/create',
            payload
          );
          useAlert(this.$t('TRACKING_TEMPLATES.CREATE.API.SUCCESS_MESSAGE'));
          if (creado && creado.id) {
            this.openAgent(creado);
            return;
          }
        } else {
          await this.$store.dispatch('trackingTemplates/update', payload);
          useAlert(this.$t('TRACKING_TEMPLATES.EDIT.API.SUCCESS_MESSAGE'));
        }
        this.goBackToList();
      } catch (error) {
        const msg =
          this.formMode === 'create'
            ? this.$t('TRACKING_TEMPLATES.CREATE.API.ERROR_MESSAGE')
            : this.$t('TRACKING_TEMPLATES.EDIT.API.ERROR_MESSAGE');
        // proyecto@adaptar_prompts_publicados (F5): el motivo del servidor (p. ej. «tiene
        // datos por configurar») dice qué hacer; el genérico no.
        const servidor = error && error.response && error.response.data;
        useAlert((servidor && servidor.message) || msg);
      }
    },
    openDeleteConfirm(template) {
      this.templateToDelete = template;
      this.showDeleteConfirmation = true;
    },
    closeDeleteConfirm() {
      this.showDeleteConfirmation = false;
      this.templateToDelete = null;
    },
    async confirmDelete() {
      if (!this.templateToDelete) return;
      try {
        await this.$store.dispatch(
          'trackingTemplates/delete',
          this.templateToDelete.id
        );
        useAlert(this.$t('TRACKING_TEMPLATES.DELETE.API.SUCCESS_MESSAGE'));
      } catch (error) {
        const respuesta =
          (error && error.response && error.response.data) || {};
        useAlert(
          respuesta.error === 'in_use'
            ? this.inUseMessage(this.templateToDelete, respuesta.usage || {})
            : this.$t('TRACKING_TEMPLATES.DELETE.API.ERROR_MESSAGE')
        );
      } finally {
        this.closeDeleteConfirm();
      }
    },
    // feat/agentes_ia_unificado: un agente en uso no se borra; se dice en qué se usa.
    inUseMessage(template, uso) {
      const t = (key, args) =>
        this.$t(`TRACKING_TEMPLATES.DELETE.IN_USE.${key}`, args);
      const motivos = [];
      if (uso.active_trackings)
        motivos.push(t('TRACKINGS', { count: uso.active_trackings }));
      if (uso.campaigns) motivos.push(t('CAMPAIGNS', { count: uso.campaigns }));
      if (uso.automations && uso.automations.length)
        motivos.push(t('AUTOMATIONS', { names: uso.automations.join(', ') }));
      return t('MESSAGE', {
        name: (template && template.name) || '',
        reasons: motivos.join(' · '),
      });
    },
    // proyecto@publicar_prompts
    isPublished(template) {
      return (
        !!template.publication && template.publication.status === 'published'
      );
    },
    publishedLabel(template) {
      return this.$t('TRACKING_TEMPLATES.PUBLISH.BADGE', {
        version: template.publication.version,
      });
    },
    updateLabel(template) {
      return this.$t('TRACKING_TEMPLATES.PUBLISH.UPDATE_BADGE', {
        version: template.published_prompt_update.version,
      });
    },
    refreshTemplates() {
      this.$store.dispatch('trackingTemplates/get');
    },
    getInboxName(template) {
      return template.inbox_name || '-';
    },
    getCreatorName(template) {
      if (template.creator) {
        return template.creator.name || '-';
      }
      return '-';
    },
    sortAgentsBy(key) {
      this.agentsSort = nextOrder(this.agentsSort, key);
      this.currentPage = 1;
    },
    // Flecha del encabezado ordenado, como en Respuestas predefinidas.
    sortIcon(key) {
      if (this.agentsSort.key !== key) return '';
      return this.agentsSort.order === 'desc' ? 'chevron-up' : 'chevron-down';
    },
    // dd/mm/aaaa hh:mm (pedido del usuario, 21/10/2026).
    formatDate(dateString) {
      if (!dateString) return '-';
      const fecha = new Date(dateString);
      const dos = n => String(n).padStart(2, '0');
      return `${dos(fecha.getDate())}/${dos(
        fecha.getMonth() + 1
      )}/${fecha.getFullYear()} ${dos(fecha.getHours())}:${dos(
        fecha.getMinutes()
      )}`;
    },
    creatorHint(template) {
      return this.$t('TRACKING_TEMPLATES.TABLE.CREATED_BY_HINT', {
        date: this.formatDate(template.created_at),
        name: this.getCreatorName(template),
      });
    },
  },
};
</script>

<template>
  <!-- feat/agentes_ia_unificado (fase A): mismo contenedor, encabezado, pestañas,
       tabla y paginado que las pantallas nativas de Ajustes (SettingsWrapper,
       BaseSettingsHeader, Respuestas predefinidas, Registros de auditoría).
       La pantalla no se desplaza: encabezado, pestañas, filtros y paginado quedan
       fijos y solo la tabla hace scroll por dentro (pedido del usuario). -->
  <div
    class="flex flex-col flex-1 w-full h-full min-h-0 p-6 overflow-hidden bg-white sm:py-8 lg:px-16 dark:bg-slate-900 font-inter"
  >
    <div class="flex flex-col flex-1 w-full min-h-0 mx-auto max-w-8xl">
      <BaseSettingsHeader
        class="shrink-0"
        :title="$t('TRACKING_TEMPLATES.HEADER')"
        :description="$t('TRACKING_TEMPLATES.DESCRIPTION')"
      >
        <template #actions>
          <!-- El formulario en blanco no es una ruta: «Volver» regresa a la lista
               (BackButton haría router.go(-1) y sacaría de la pantalla). -->
          <woot-button
            v-if="isFormView"
            variant="smooth"
            color-scheme="secondary"
            icon="chevron-left"
            @click="goBackToList"
          >
            {{ $t('TRACKING_TEMPLATES.BACK_TO_LIST') }}
          </woot-button>
          <!-- proyecto@import_seguimiento: botón "Importar desde Excel" oculto
               (v-if="false"). Se conserva el código para reactivarlo si hace falta. -->
          <woot-button
            v-if="false"
            variant="smooth"
            color-scheme="secondary"
            icon="arrow-upload"
            @click="showImportModal = true"
          >
            {{ $t('TRACKING_IMPORT.BTN_OPEN') }}
          </woot-button>
          <!-- Una sola puerta para un agente nuevo, con las formas de empezarlo. -->
          <div v-if="isListView" class="relative">
            <woot-button
              class="rounded-md button nice"
              icon="add-circle"
              @click="showNewMenu = !showNewMenu"
            >
              {{ $t('TRACKING_TEMPLATES.NEW_AGENT.BUTTON') }}
            </woot-button>
            <div
              v-if="showNewMenu"
              v-on-clickaway="() => (showNewMenu = false)"
              class="dropdown-pane dropdown-pane--open !right-0 !left-auto !top-10 w-72"
            >
              <woot-dropdown-menu>
                <woot-dropdown-item v-if="isAdmin">
                  <woot-button
                    variant="clear"
                    color-scheme="secondary"
                    size="small"
                    icon="wand"
                    @click="newAgent()"
                  >
                    {{ $t('TRACKING_TEMPLATES.NEW_AGENT.ASSISTANT') }}
                  </woot-button>
                </woot-dropdown-item>
                <woot-dropdown-item v-if="isAdmin">
                  <woot-button
                    variant="clear"
                    color-scheme="secondary"
                    size="small"
                    icon="globe"
                    @click="newAgent({ galeria: '1' })"
                  >
                    {{ $t('TRACKING_TEMPLATES.NEW_AGENT.GALLERY') }}
                  </woot-button>
                </woot-dropdown-item>
                <woot-dropdown-item>
                  <woot-button
                    variant="clear"
                    color-scheme="secondary"
                    size="small"
                    icon="document"
                    @click="goToCreateForm"
                  >
                    {{ $t('TRACKING_TEMPLATES.NEW_AGENT.FORM') }}
                  </woot-button>
                </woot-dropdown-item>
              </woot-dropdown-menu>
            </div>
          </div>
        </template>
      </BaseSettingsHeader>

      <!-- VISTA: FORMULARIO (agente nuevo en blanco) -->
      <div v-if="isFormView" class="flex-1 min-h-0 mt-6 overflow-auto">
        <TemplateForm
          :mode="formMode"
          :template-data="selectedTemplate || {}"
          @save="onFormSave"
          @cancel="goBackToList"
        />
      </div>

      <template v-else>
        <woot-tabs
          v-if="listTabs.length > 1"
          class="mt-4 shrink-0"
          :index="listTabPosition"
          :border="false"
          @change="listTab = listTabs[$event].id"
        >
          <woot-tabs-item
            v-for="(tab, position) in listTabs"
            :key="tab.id"
            :index="position"
            :name="$t(tab.label)"
            :count="tab.count || 0"
            :show-badge="!!tab.count"
          />
        </woot-tabs>

        <SessionsPanel
          v-if="isAdmin"
          v-show="listTab === 'sessions'"
          class="flex-1 min-h-0 mt-6"
          @open="openSession"
          @count="openSessionsCount = $event"
        />
        <InventoryPanel
          v-if="listTab === 'resources'"
          class="flex-1 min-h-0 mt-6"
        />

        <!-- VISTA: LISTA -->
        <div
          v-else-if="listTab === 'agents'"
          class="flex flex-col flex-1 min-h-0 mt-6 text-slate-700 dark:text-slate-300"
        >
          <div
            v-if="hasTemplates"
            class="flex flex-wrap items-center gap-3 mb-2 shrink-0"
          >
            <div class="relative flex-1 min-w-[12rem] max-w-md">
              <fluent-icon
                icon="search"
                size="16"
                class="absolute -translate-y-1/2 left-3 top-1/2 text-slate-400"
              />
              <input
                type="text"
                class="!mb-0 !pl-9"
                :value="searchQuery"
                :placeholder="$t('TRACKING_TEMPLATES.SEARCH_PLACEHOLDER')"
                @input="searchQuery = $event.target.value"
              />
            </div>
            <select
              class="!mb-0 !w-56"
              :value="selectedInboxFilter"
              @change="selectedInboxFilter = $event.target.value"
            >
              <option value="">
                {{ $t('TRACKING_TEMPLATES.ALL_CHANNELS') }}
              </option>
              <option
                v-for="inbox in usedInboxes"
                :key="inbox.id"
                :value="inbox.id"
              >
                {{ inbox.name }}
              </option>
            </select>
          </div>

          <woot-loading-state
            v-if="uiFlags.fetchingList"
            :message="$t('TRACKING_TEMPLATES.LOADING')"
          />
          <p
            v-else-if="!hasTemplates"
            class="flex flex-col items-center justify-center h-full py-8 text-base text-slate-600 dark:text-slate-300"
          >
            {{ $t('TRACKING_TEMPLATES.NO_TEMPLATES') }}
          </p>
          <p
            v-else-if="!hasResults"
            class="flex flex-col items-center justify-center h-full py-8 text-base text-slate-600 dark:text-slate-300"
          >
            {{ $t('TRACKING_TEMPLATES.NO_RESULTS') }}
          </p>

          <div v-else class="flex flex-col flex-1 min-h-0">
            <div class="flex-1 min-h-0 overflow-auto">
              <table
                class="min-w-full divide-y divide-slate-75 dark:divide-slate-700"
              >
                <!-- Orden pedido por el usuario (21/10/2026): Nombre · Objetivo · Canal ·
                     Revisión · Acciones · Fecha. «Creado por» va en el tooltip de la fecha. -->
                <thead class="sticky top-0 z-10 bg-white dark:bg-slate-900">
                  <th
                    class="py-4 pr-4 font-semibold text-left whitespace-nowrap text-slate-700 dark:text-slate-300"
                  >
                    <button
                      class="flex items-center p-0 cursor-pointer"
                      @click="sortAgentsBy('name')"
                    >
                      <span class="mb-0">{{
                        $t('TRACKING_TEMPLATES.TABLE.NAME')
                      }}</span>
                      <fluent-icon
                        v-if="sortIcon('name')"
                        class="ml-2"
                        :icon="sortIcon('name')"
                      />
                    </button>
                  </th>
                  <th
                    class="py-4 pr-4 font-semibold text-left whitespace-nowrap text-slate-700 dark:text-slate-300"
                  >
                    <button
                      class="flex items-center p-0 cursor-pointer"
                      @click="sortAgentsBy('objective')"
                    >
                      <span class="mb-0">{{
                        $t('TRACKING_TEMPLATES.TABLE.OBJECTIVE')
                      }}</span>
                      <fluent-icon
                        v-if="sortIcon('objective')"
                        class="ml-2"
                        :icon="sortIcon('objective')"
                      />
                    </button>
                  </th>
                  <th
                    class="py-4 pr-4 font-semibold text-left whitespace-nowrap text-slate-700 dark:text-slate-300"
                  >
                    <button
                      class="flex items-center p-0 cursor-pointer"
                      @click="sortAgentsBy('inbox_label')"
                    >
                      <span class="mb-0">{{
                        $t('TRACKING_TEMPLATES.TABLE.CHANNEL')
                      }}</span>
                      <fluent-icon
                        v-if="sortIcon('inbox_label')"
                        class="ml-2"
                        :icon="sortIcon('inbox_label')"
                      />
                    </button>
                  </th>
                  <th
                    v-if="isAdmin"
                    class="py-4 pr-4 font-semibold text-left whitespace-nowrap text-slate-700 dark:text-slate-300"
                  >
                    <span class="inline-flex items-center gap-1">
                      <button
                        class="flex items-center p-0 cursor-pointer"
                        @click="sortAgentsBy('review_rank')"
                      >
                        <span class="mb-0">{{
                          $t('TRACKING_TEMPLATES.TABLE.REVIEW')
                        }}</span>
                        <fluent-icon
                          v-if="sortIcon('review_rank')"
                          class="ml-2"
                          :icon="sortIcon('review_rank')"
                        />
                      </button>
                      <fluent-icon
                        v-tooltip.top="$t('TRACKING_TEMPLATES.REVIEW.HINT')"
                        icon="info"
                        size="14"
                        class="cursor-help text-slate-500 dark:text-slate-400"
                      />
                    </span>
                  </th>
                  <th
                    class="py-4 pr-4 font-semibold text-left whitespace-nowrap text-slate-700 dark:text-slate-300"
                  >
                    {{ $t('TRACKING_TEMPLATES.TABLE.ACTIONS') }}
                  </th>
                  <th
                    class="py-4 pr-4 font-semibold text-left whitespace-nowrap text-slate-700 dark:text-slate-300"
                  >
                    <button
                      class="flex items-center p-0 cursor-pointer"
                      @click="sortAgentsBy('updated_at')"
                    >
                      <span class="mb-0">{{
                        $t('TRACKING_TEMPLATES.TABLE.UPDATED_AT')
                      }}</span>
                      <fluent-icon
                        v-if="sortIcon('updated_at')"
                        class="ml-2"
                        :icon="sortIcon('updated_at')"
                      />
                    </button>
                  </th>
                </thead>
                <tbody
                  class="divide-y divide-slate-50 dark:divide-slate-800 text-slate-700 dark:text-slate-300"
                >
                  <tr
                    v-for="template in pagedTemplates"
                    :key="template.id"
                    class="cursor-pointer hover:bg-slate-25 dark:hover:bg-slate-800"
                    @click="openAgent(template)"
                  >
                    <td class="py-4 pr-4 font-medium">
                      {{ template.name }}
                      <!-- proyecto@publicar_prompts (F7): el autor publicó una versión nueva -->
                      <woot-label
                        v-if="template.published_prompt_update"
                        v-tooltip.top="
                          $t('TRACKING_TEMPLATES.PUBLISH.UPDATE_HINT')
                        "
                        small
                        :title="updateLabel(template)"
                        color-scheme="warning"
                        class="!mb-0 ltr:ml-2 rtl:mr-2"
                      />
                      <!-- proyecto@publicar_prompts -->
                      <woot-label
                        v-if="canPublishPrompts && isPublished(template)"
                        small
                        :title="publishedLabel(template)"
                        color-scheme="success"
                        class="!mb-0 ltr:ml-2 rtl:mr-2"
                      />
                    </td>
                    <td class="max-w-xs py-4 pr-4">
                      <div class="line-clamp-2" :title="template.objective">
                        {{ template.objective || '-' }}
                      </div>
                    </td>
                    <td class="py-4 pr-4">
                      <woot-label
                        v-if="template.inbox_id"
                        small
                        :title="getInboxName(template)"
                        color-scheme="primary"
                        class="!mb-0"
                      />
                      <span v-else>-</span>
                    </td>
                    <!-- El comprobador sobre el Entrenamiento publicado. El tooltip dice
                         qué significa el estado y, si no ejecuta, el primer error. -->
                    <td v-if="isAdmin" class="py-4 pr-4">
                      <woot-label
                        v-if="auditFor(template)"
                        v-tooltip.top="auditTooltip(auditFor(template))"
                        small
                        :title="auditTitle(auditFor(template))"
                        :color-scheme="auditScheme(auditFor(template))"
                        class="!mb-0 cursor-help"
                      />
                    </td>
                    <td class="py-4 pr-4">
                      <!-- Abrir o editar = clic en la fila: aquí solo lo que no es abrir. -->
                      <div class="flex items-center gap-2" @click.stop>
                        <!-- proyecto@publicar_prompts — solo el usuario autorizado -->
                        <woot-button
                          v-if="canPublishPrompts"
                          v-tooltip.top="
                            $t('TRACKING_TEMPLATES.PUBLISH.BUTTON')
                          "
                          variant="smooth"
                          size="small"
                          color-scheme="primary"
                          icon="globe"
                          @click="templateToPublish = template"
                        />
                        <woot-button
                          v-tooltip.top="$t('TRACKING_TEMPLATES.DELETE.TITLE')"
                          variant="smooth"
                          size="small"
                          color-scheme="alert"
                          icon="delete"
                          @click="openDeleteConfirm(template)"
                        />
                      </div>
                    </td>
                    <td
                      v-tooltip.top="creatorHint(template)"
                      class="py-4 pr-4 whitespace-nowrap"
                    >
                      {{ formatDate(template.updated_at) }}
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <TableFooter
              :current-page="currentPage"
              :total-count="filteredTemplates.length"
              :page-size="perPage"
              class="border-t shrink-0 border-slate-50 dark:border-slate-800 !px-0 py-4"
              @pageChange="onPageChange"
            />
          </div>
        </div>
      </template>

      <!-- Import Modal - proyecto@import_seguimiento -->
      <ImportModal :show="showImportModal" @close="showImportModal = false" />

      <!-- proyecto@publicar_prompts -->
      <PublishPromptModal
        v-if="canPublishPrompts"
        :show="!!templateToPublish"
        :template="templateToPublish"
        @close="templateToPublish = null"
        @changed="refreshTemplates"
      />

      <!-- Delete Confirmation -->
      <woot-delete-modal
        :show.sync="showDeleteConfirmation"
        :on-close="closeDeleteConfirm"
        :on-confirm="confirmDelete"
        :title="$t('TRACKING_TEMPLATES.DELETE.TITLE')"
        :message="
          templateToDelete
            ? $t('TRACKING_TEMPLATES.DELETE.CONFIRM_MESSAGE', {
                name: templateToDelete.name,
              })
            : ''
        "
        :confirm-text="$t('TRACKING_TEMPLATES.DELETE.CONFIRM_YES')"
        :reject-text="$t('TRACKING_TEMPLATES.DELETE.CONFIRM_NO')"
      />
    </div>
  </div>
</template>
