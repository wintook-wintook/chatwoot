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
import AssistantAPI from 'dashboard/api/assistant';
import SessionsPanel from 'dashboard/views/contactTrackings/agents/SessionsPanel.vue';
import InventoryPanel from 'dashboard/views/contactTrackings/agents/InventoryPanel.vue';

// Explícito y no armado por concatenación (igual que en el Asistente): un estado nuevo
// del backend se ve como «Sin Entrenamiento» antes que como un cartel en blanco.
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
    pagedTemplates() {
      const start = (this.currentPage - 1) * this.perPage;
      return this.filteredTemplates.slice(start, start + this.perPage);
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
    auditClass(row) {
      if (row.status === 'broken')
        return 'text-red-700 bg-red-100 dark:bg-red-900/30 dark:text-red-300';
      if (row.status === 'routed')
        return 'text-green-700 bg-green-100 dark:bg-green-900/30 dark:text-green-300';
      return 'text-slate-600 bg-slate-100 dark:bg-slate-700 dark:text-slate-300';
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
        useAlert(this.$t('TRACKING_TEMPLATES.DELETE.API.ERROR_MESSAGE'));
      } finally {
        this.closeDeleteConfirm();
      }
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
    formatDate(dateString) {
      if (!dateString) return '-';
      return new Date(dateString).toLocaleDateString(undefined, {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
      });
    },
    truncateText(text, maxLength = 60) {
      if (!text) return '-';
      return text.length > maxLength
        ? text.substring(0, maxLength) + '...'
        : text;
    },
  },
};
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 overflow-hidden p-4">
    <!-- Header (siempre visible) -->
    <div class="flex items-center justify-between mb-4 shrink-0">
      <div class="flex items-center gap-2">
        <woot-sidemenu-icon />
        <div>
          <h1 class="text-2xl font-bold text-slate-800 dark:text-slate-100">
            {{ $t('TRACKING_TEMPLATES.HEADER') }}
          </h1>
          <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
            {{ $t('TRACKING_TEMPLATES.DESCRIPTION') }}
          </p>
        </div>
      </div>
      <div v-if="isListView" class="flex items-center gap-2">
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
        <!-- feat/agentes_ia_unificado — una sola puerta para un agente nuevo, con
             las formas de empezarlo. El Asistente y la Galería abren el espacio del
             agente nuevo; el formulario en blanco sigue siendo esta misma vista. -->
        <div class="relative">
          <woot-button
            icon="add"
            color-scheme="success"
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
      </div>
      <woot-button
        v-else
        variant="smooth"
        color-scheme="secondary"
        icon="chevron-left"
        @click="goBackToList"
      >
        {{ $t('TRACKING_TEMPLATES.BACK_TO_LIST') }}
      </woot-button>
    </div>

    <!-- VISTA: FORMULARIO -->
    <div v-if="isFormView" class="flex-1 min-h-0 overflow-auto">
      <TemplateForm
        :mode="formMode"
        :template-data="selectedTemplate || {}"
        @save="onFormSave"
        @cancel="goBackToList"
      />
    </div>

    <!-- feat/agentes_ia_unificado — pestañas de la lista (botones y no woot-tabs:
         woot-tabs renumera por posición y aquí dos de tres son solo de admin). -->
    <div
      v-if="isListView && listTabs.length > 1"
      class="flex flex-wrap items-center gap-1 mb-3 shrink-0"
      role="tablist"
    >
      <woot-button
        v-for="tab in listTabs"
        :key="tab.id"
        size="small"
        :variant="listTab === tab.id ? 'smooth' : 'clear'"
        :color-scheme="listTab === tab.id ? 'primary' : 'secondary'"
        role="tab"
        :aria-selected="listTab === tab.id"
        @click="listTab = tab.id"
      >
        {{ $t(tab.label) }}
        <span v-if="tab.count" class="ml-1 text-xs opacity-70">
          ({{ tab.count }})
        </span>
      </woot-button>
    </div>

    <SessionsPanel
      v-if="isListView && isAdmin"
      v-show="listTab === 'sessions'"
      @open="openSession"
      @count="openSessionsCount = $event"
    />
    <InventoryPanel v-if="isListView && listTab === 'resources'" />

    <!-- VISTA: LISTA -->
    <div
      v-else-if="isListView && listTab === 'agents'"
      class="flex flex-col flex-1 min-h-0"
    >
      <!-- Filtros (estilo unificado con el listado de Seguimientos) -->
      <div
        v-if="hasTemplates"
        class="flex items-center gap-3 mb-4 shrink-0 p-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
      >
        <div class="relative flex-1 min-w-[120px]">
          <fluent-icon
            icon="search"
            size="16"
            class="absolute -translate-y-1/2 left-2 top-1/2 text-slate-400"
          />
          <input
            type="text"
            :value="searchQuery"
            :placeholder="$t('TRACKING_TEMPLATES.SEARCH_PLACEHOLDER')"
            class="box-border w-full h-9 m-0 text-sm rounded-md border border-solid border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 pl-8 pr-2 outline-none focus:border-woot-500 dark:focus:border-woot-600"
            @input="searchQuery = $event.target.value"
          />
        </div>
        <select
          :value="selectedInboxFilter"
          class="box-border shrink-0 w-44 h-9 text-sm rounded-md border border-solid border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 px-2 outline-none focus:border-woot-500 dark:focus:border-woot-600"
          @change="selectedInboxFilter = $event.target.value"
        >
          <option value="">{{ $t('TRACKING_TEMPLATES.ALL_CHANNELS') }}</option>
          <option
            v-for="inbox in usedInboxes"
            :key="inbox.id"
            :value="inbox.id"
          >
            {{ inbox.name }}
          </option>
        </select>
      </div>

      <!-- Loading -->
      <div
        v-if="uiFlags.fetchingList"
        class="flex items-center justify-center py-12"
      >
        <span class="text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_TEMPLATES.LOADING') }}
        </span>
      </div>

      <!-- Empty state -->
      <div
        v-else-if="!hasTemplates"
        class="flex flex-col items-center justify-center py-16 text-center"
      >
        <fluent-icon
          icon="document-outline"
          size="48"
          class="text-slate-300 dark:text-slate-600 mb-4"
        />
        <p class="text-slate-500 dark:text-slate-400 max-w-md">
          {{ $t('TRACKING_TEMPLATES.NO_TEMPLATES') }}
        </p>
      </div>

      <!-- No results -->
      <div
        v-else-if="!hasResults"
        class="flex flex-col items-center justify-center py-12 text-center"
      >
        <p class="text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_TEMPLATES.NO_RESULTS') }}
        </p>
      </div>

      <!-- Table -->
      <div
        v-else
        class="flex-1 min-h-0 overflow-auto rounded-lg bg-white dark:bg-slate-800 border border-slate-100 dark:border-slate-700"
      >
        <table class="w-full text-sm">
          <thead class="sticky top-0 z-10 bg-white dark:bg-slate-800">
            <tr
              class="text-left text-slate-500 dark:text-slate-400 border-b border-slate-100 dark:border-slate-700"
            >
              <th v-if="isAdmin" class="p-3">
                {{ $t('TRACKING_TEMPLATES.TABLE.REVIEW') }}
              </th>
              <th class="p-3">
                {{ $t('TRACKING_TEMPLATES.TABLE.NAME') }}
              </th>
              <th class="p-3">
                {{ $t('TRACKING_TEMPLATES.TABLE.OBJECTIVE') }}
              </th>
              <th class="p-3">
                {{ $t('TRACKING_TEMPLATES.TABLE.CHANNEL') }}
              </th>
              <th class="p-3">
                {{ $t('TRACKING_TEMPLATES.TABLE.CREATED_BY') }}
              </th>
              <th class="p-3 whitespace-nowrap">
                {{ $t('TRACKING_TEMPLATES.TABLE.CREATED_AT') }}
              </th>
              <th class="p-3 text-right whitespace-nowrap">
                {{ $t('TRACKING_TEMPLATES.TABLE.ACTIONS') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="template in pagedTemplates"
              :key="template.id"
              class="border-b cursor-pointer border-slate-50 dark:border-slate-700/50 hover:bg-slate-50 dark:hover:bg-slate-700/30 transition-colors"
              @click="openAgent(template)"
            >
              <!-- feat/agentes_ia_unificado — lo que antes era la tabla «Agentes IA»
                   del Asistente: el comprobador, con el primer defecto a la mano. -->
              <td v-if="isAdmin" class="p-3">
                <span
                  v-if="auditFor(template)"
                  v-tooltip="auditFor(template).headline || ''"
                  class="text-xs font-medium px-2 py-0.5 rounded whitespace-nowrap"
                  :class="auditClass(auditFor(template))"
                >
                  {{ $t(auditLabel(auditFor(template))) }}
                  <template v-if="auditFor(template).defects">
                    · {{ auditFor(template).defects }}
                  </template>
                </span>
              </td>
              <td class="p-3">
                <span
                  class="text-sm font-medium text-slate-800 dark:text-slate-200"
                >
                  {{ template.name }}
                </span>
                <!-- proyecto@publicar_prompts (F7): el autor publicó una versión nueva -->
                <woot-label
                  v-if="template.published_prompt_update"
                  v-tooltip="$t('TRACKING_TEMPLATES.PUBLISH.UPDATE_HINT')"
                  small
                  :title="updateLabel(template)"
                  color-scheme="warning"
                  class="ltr:ml-2 rtl:mr-2 text-xs"
                />
                <!-- proyecto@publicar_prompts -->
                <woot-label
                  v-if="canPublishPrompts && isPublished(template)"
                  small
                  :title="publishedLabel(template)"
                  color-scheme="success"
                  class="ltr:ml-2 rtl:mr-2 text-xs"
                />
              </td>
              <td class="p-3">
                <span class="text-sm text-slate-600 dark:text-slate-400">
                  {{ truncateText(template.objective) }}
                </span>
              </td>
              <td class="p-3">
                <span
                  v-if="template.inbox_id"
                  class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-woot-50 text-woot-700 dark:bg-woot-800/30 dark:text-woot-300"
                >
                  {{ getInboxName(template) }}
                </span>
                <span v-else class="text-xs text-slate-400">-</span>
              </td>
              <td class="p-3">
                <span class="text-xs text-slate-600 dark:text-slate-400">
                  {{ getCreatorName(template) }}
                </span>
              </td>
              <td class="p-3 whitespace-nowrap">
                <span class="text-xs text-slate-500 dark:text-slate-400">
                  {{ formatDate(template.created_at) }}
                </span>
              </td>
              <td class="p-3 text-right">
                <!-- «Mejorar con el Asistente» ya no es un botón: abrir el agente
                     lleva a su espacio, con el Asistente en «Entrenamiento». -->
                <div class="flex items-center justify-end gap-2" @click.stop>
                  <!-- proyecto@publicar_prompts — solo el usuario autorizado -->
                  <woot-button
                    v-if="canPublishPrompts"
                    v-tooltip="$t('TRACKING_TEMPLATES.PUBLISH.BUTTON')"
                    variant="smooth"
                    size="small"
                    color-scheme="secondary"
                    icon="share"
                    @click="templateToPublish = template"
                  />
                  <woot-button
                    v-tooltip="$t('TRACKING_TEMPLATES.OPEN_PROFILE')"
                    variant="smooth"
                    size="small"
                    color-scheme="secondary"
                    icon="edit"
                    @click="openAgent(template, 'profile')"
                  />
                  <woot-button
                    variant="smooth"
                    size="small"
                    color-scheme="alert"
                    icon="delete"
                    @click="openDeleteConfirm(template)"
                  />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Paginado nativo (uniforme con Campañas y el listado de Seguimientos) -->
      <TableFooter
        v-if="hasResults"
        class="mt-3 shrink-0 border-t border-slate-75 dark:border-slate-700/50"
        :current-page="currentPage"
        :total-count="filteredTemplates.length"
        :page-size="perPage"
        @pageChange="onPageChange"
      />

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
