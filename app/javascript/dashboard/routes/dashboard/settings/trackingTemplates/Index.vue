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
    // El color del woot-label: roto en rojo, con rutas en verde, el resto neutro.
    auditScheme(row) {
      if (row.status === 'broken') return 'alert';
      if (row.status === 'routed') return 'success';
      return 'secondary';
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
  },
};
</script>

<template>
  <!-- feat/agentes_ia_unificado (fase A): mismo contenedor, encabezado, pestañas,
       tabla y paginado que las pantallas nativas de Ajustes (SettingsWrapper,
       BaseSettingsHeader, Respuestas predefinidas, Registros de auditoría). -->
  <div
    class="flex flex-col w-full h-full p-6 overflow-auto bg-white sm:py-8 lg:px-16 dark:bg-slate-900 font-inter"
  >
    <div class="flex flex-col w-full mx-auto max-w-8xl">
      <BaseSettingsHeader
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
      <div v-if="isFormView" class="mt-6">
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
          class="mt-4"
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
          class="mt-6"
          @open="openSession"
          @count="openSessionsCount = $event"
        />
        <InventoryPanel v-if="listTab === 'resources'" class="mt-6" />

        <!-- VISTA: LISTA -->
        <div
          v-else-if="listTab === 'agents'"
          class="mt-6 text-slate-700 dark:text-slate-300"
        >
          <div
            v-if="hasTemplates"
            class="flex flex-wrap items-center gap-3 mb-2"
          >
            <div class="relative flex-1 min-w-[12rem] max-w-md">
              <fluent-icon
                icon="search"
                size="16"
                class="absolute -translate-y-1/2 left-3 top-1/2 text-slate-400"
              />
              <input
                type="search"
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

          <div v-else class="min-w-full overflow-x-auto">
            <table
              class="min-w-full divide-y divide-slate-75 dark:divide-slate-700"
            >
              <thead>
                <th
                  v-if="isAdmin"
                  class="py-4 pr-4 font-semibold text-left text-slate-700 dark:text-slate-300"
                >
                  {{ $t('TRACKING_TEMPLATES.TABLE.REVIEW') }}
                </th>
                <th
                  class="py-4 pr-4 font-semibold text-left text-slate-700 dark:text-slate-300"
                >
                  {{ $t('TRACKING_TEMPLATES.TABLE.NAME') }}
                </th>
                <th
                  class="py-4 pr-4 font-semibold text-left text-slate-700 dark:text-slate-300"
                >
                  {{ $t('TRACKING_TEMPLATES.TABLE.OBJECTIVE') }}
                </th>
                <th
                  class="py-4 pr-4 font-semibold text-left text-slate-700 dark:text-slate-300"
                >
                  {{ $t('TRACKING_TEMPLATES.TABLE.CHANNEL') }}
                </th>
                <th
                  class="py-4 pr-4 font-semibold text-left text-slate-700 dark:text-slate-300"
                >
                  {{ $t('TRACKING_TEMPLATES.TABLE.CREATED_BY') }}
                </th>
                <th
                  class="py-4 pr-4 font-semibold text-left whitespace-nowrap text-slate-700 dark:text-slate-300"
                >
                  {{ $t('TRACKING_TEMPLATES.TABLE.CREATED_AT') }}
                </th>
                <th class="py-4" />
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
                  <!-- El comprobador (antes otra tabla en el Asistente); el primer
                       defecto sale al pasar el mouse. -->
                  <td v-if="isAdmin" class="py-4 pr-4">
                    <woot-label
                      v-if="auditFor(template)"
                      v-tooltip.top="auditFor(template).headline || ''"
                      small
                      :title="auditTitle(auditFor(template))"
                      :color-scheme="auditScheme(auditFor(template))"
                      class="!mb-0"
                    />
                  </td>
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
                  <td class="py-4 pr-4">
                    {{ getCreatorName(template) }}
                  </td>
                  <td class="py-4 pr-4 whitespace-nowrap">
                    {{ formatDate(template.created_at) }}
                  </td>
                  <!-- «Mejorar con el Asistente» ya no es un botón: abrir el agente
                       lleva a su espacio, con el Asistente en «Entrenamiento». -->
                  <td class="py-4">
                    <div class="flex justify-end gap-1" @click.stop>
                      <!-- proyecto@publicar_prompts — solo el usuario autorizado -->
                      <woot-button
                        v-if="canPublishPrompts"
                        v-tooltip.top="$t('TRACKING_TEMPLATES.PUBLISH.BUTTON')"
                        variant="smooth"
                        size="tiny"
                        color-scheme="secondary"
                        icon="share"
                        @click="templateToPublish = template"
                      />
                      <woot-button
                        v-tooltip.top="$t('TRACKING_TEMPLATES.OPEN_PROFILE')"
                        variant="smooth"
                        size="tiny"
                        color-scheme="secondary"
                        icon="edit"
                        @click="openAgent(template, 'profile')"
                      />
                      <woot-button
                        v-tooltip.top="$t('TRACKING_TEMPLATES.DELETE.TITLE')"
                        variant="smooth"
                        size="tiny"
                        color-scheme="alert"
                        icon="dismiss-circle"
                        @click="openDeleteConfirm(template)"
                      />
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
            <TableFooter
              :current-page="currentPage"
              :total-count="filteredTemplates.length"
              :page-size="perPage"
              class="border-t border-slate-50 dark:border-slate-800 !px-0 py-4"
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
