<!--
  ================================================================================
  proyecto@tracking_templates
  ================================================================================
  Componente: Index.vue
  Descripción: Página principal de gestión de plantillas de seguimiento en Settings.
               Vista inline lista/formulario con filtros por nombre y canal.
  ================================================================================
-->

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import TemplateForm from './EditTemplate.vue';
import ImportModal from './ImportModal.vue'; // proyecto@import_seguimiento
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';

export default {
  components: {
    TemplateForm,
    ImportModal,
    TableFooter,
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
      currentPage: 1,
      perPage: 10,
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'trackingTemplates/getUIFlags',
      templates: 'trackingTemplates/getTemplates',
      allInboxIds: 'trackingTemplates/getAllInboxIds',
      inboxes: 'inboxes/getInboxes',
    }),
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
  mounted() {
    this.$store.dispatch('trackingTemplates/get');
    if (!this.inboxes || this.inboxes.length === 0) {
      this.$store.dispatch('inboxes/get');
    }
  },
  methods: {
    onPageChange(page) {
      this.currentPage = page;
    },
    goToCreateForm() {
      this.formMode = 'create';
      this.selectedTemplate = null;
      this.currentView = 'form';
    },
    goToEditForm(template) {
      this.formMode = 'edit';
      this.selectedTemplate = { ...template };
      this.currentView = 'form';
    },
    // proyecto@ai_agent_assistant (F4): restaurar cambió el agente en la base; lo que
    // muestra el formulario ya no es lo guardado. Se recarga y se reabre en el mismo sitio.
    async onFormRestored(templateId) {
      await this.$store.dispatch('trackingTemplates/get');
      const fresh = this.templates.find(t => t.id === templateId);
      if (fresh) this.selectedTemplate = { ...fresh };
    },
    goBackToList() {
      this.currentView = 'list';
      this.selectedTemplate = null;
      this.formMode = 'create';
    },
    async onFormSave(payload) {
      try {
        if (this.formMode === 'create') {
          await this.$store.dispatch('trackingTemplates/create', payload);
          useAlert(this.$t('TRACKING_TEMPLATES.CREATE.API.SUCCESS_MESSAGE'));
        } else {
          await this.$store.dispatch('trackingTemplates/update', payload);
          useAlert(this.$t('TRACKING_TEMPLATES.EDIT.API.SUCCESS_MESSAGE'));
        }
        this.goBackToList();
      } catch (error) {
        const msg = this.formMode === 'create'
          ? this.$t('TRACKING_TEMPLATES.CREATE.API.ERROR_MESSAGE')
          : this.$t('TRACKING_TEMPLATES.EDIT.API.ERROR_MESSAGE');
        useAlert(msg);
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
        <woot-button
          v-if="isListView"
          icon="add"
          color-scheme="success"
          @click="goToCreateForm"
        >
          {{ $t('TRACKING_TEMPLATES.HEADER_BTN_TXT') }}
        </woot-button>
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
        @restored="onFormRestored"
      />
    </div>

    <!-- VISTA: LISTA -->
    <div v-else class="flex flex-col flex-1 min-h-0">

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
      <div v-if="uiFlags.fetchingList" class="flex items-center justify-center py-12">
        <span class="text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_TEMPLATES.LOADING') }}
        </span>
      </div>

      <!-- Empty state -->
      <div
        v-else-if="!hasTemplates"
        class="flex flex-col items-center justify-center py-16 text-center"
      >
        <fluent-icon icon="document-outline" size="48" class="text-slate-300 dark:text-slate-600 mb-4" />
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
            <tr class="text-left text-slate-500 dark:text-slate-400 border-b border-slate-100 dark:border-slate-700">
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
              class="border-b border-slate-50 dark:border-slate-700/50 hover:bg-slate-50 dark:hover:bg-slate-700/30 transition-colors"
            >
              <td class="p-3">
                <span class="text-sm font-medium text-slate-800 dark:text-slate-200">
                  {{ template.name }}
                </span>
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
                <div class="flex items-center justify-end gap-2">
                  <woot-button
                    variant="smooth"
                    size="small"
                    color-scheme="secondary"
                    icon="edit"
                    @click="goToEditForm(template)"
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
      <ImportModal
        :show="showImportModal"
        @close="showImportModal = false"
      />

      <!-- Delete Confirmation -->
      <woot-delete-modal
        :show.sync="showDeleteConfirmation"
        :on-close="closeDeleteConfirm"
        :on-confirm="confirmDelete"
        :title="$t('TRACKING_TEMPLATES.DELETE.TITLE')"
        :message="templateToDelete ? $t('TRACKING_TEMPLATES.DELETE.CONFIRM_MESSAGE', { name: templateToDelete.name }) : ''"
        :confirm-text="$t('TRACKING_TEMPLATES.DELETE.CONFIRM_YES')"
        :reject-text="$t('TRACKING_TEMPLATES.DELETE.CONFIRM_NO')"
      />
    </div>
  </div>
</template>
