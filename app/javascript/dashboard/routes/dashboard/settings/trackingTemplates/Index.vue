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

export default {
  components: {
    TemplateForm,
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
    hasTemplates() {
      return this.templates.length > 0;
    },
    hasResults() {
      return this.filteredTemplates.length > 0;
    },
  },
  mounted() {
    this.$store.dispatch('trackingTemplates/get');
    if (!this.inboxes || this.inboxes.length === 0) {
      this.$store.dispatch('inboxes/get');
    }
  },
  methods: {
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
  <div class="flex-1 overflow-auto p-4">

    <!-- Header (siempre visible) -->
    <div class="flex items-center justify-between mb-4">
      <div>
        <h1 class="text-2xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('TRACKING_TEMPLATES.HEADER') }}
        </h1>
        <p class="text-sm text-slate-600 dark:text-slate-400 mt-1">
          {{ $t('TRACKING_TEMPLATES.DESCRIPTION') }}
        </p>
      </div>
      <woot-button
        v-if="isListView"
        icon="add"
        color-scheme="success"
        @click="goToCreateForm"
      >
        {{ $t('TRACKING_TEMPLATES.HEADER_BTN_TXT') }}
      </woot-button>
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
    <div v-if="isFormView">
      <TemplateForm
        :mode="formMode"
        :template-data="selectedTemplate || {}"
        @save="onFormSave"
        @cancel="goBackToList"
      />
    </div>

    <!-- VISTA: LISTA -->
    <div v-else>

      <!-- Filters -->
      <div
        v-if="hasTemplates"
        class="flex flex-wrap items-center gap-3 mb-4"
      >
        <div class="flex-1 min-w-[200px] max-w-sm">
          <input
            type="text"
            :value="searchQuery"
            :placeholder="$t('TRACKING_TEMPLATES.SEARCH_PLACEHOLDER')"
            class="w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 px-3 py-2 text-sm text-slate-700 dark:text-slate-200 placeholder-slate-400 focus:border-woot-500 focus:outline-none"
            @input="searchQuery = $event.target.value"
          />
        </div>
        <div class="min-w-[200px]">
          <select
            :value="selectedInboxFilter"
            class="w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800 px-3 py-2 text-sm text-slate-700 dark:text-slate-200 focus:border-woot-500 focus:outline-none"
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
        class="overflow-x-auto rounded-lg border border-slate-200 dark:border-slate-700"
      >
        <table class="min-w-full divide-y divide-slate-200 dark:divide-slate-700">
          <thead class="bg-slate-50 dark:bg-slate-800">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-600 dark:text-slate-300 uppercase tracking-wider">
                {{ $t('TRACKING_TEMPLATES.TABLE.NAME') }}
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-600 dark:text-slate-300 uppercase tracking-wider">
                {{ $t('TRACKING_TEMPLATES.TABLE.OBJECTIVE') }}
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-600 dark:text-slate-300 uppercase tracking-wider">
                {{ $t('TRACKING_TEMPLATES.TABLE.CHANNEL') }}
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-600 dark:text-slate-300 uppercase tracking-wider">
                {{ $t('TRACKING_TEMPLATES.TABLE.CREATED_BY') }}
              </th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-slate-600 dark:text-slate-300 uppercase tracking-wider whitespace-nowrap">
                {{ $t('TRACKING_TEMPLATES.TABLE.CREATED_AT') }}
              </th>
              <th class="px-4 py-3 text-right text-xs font-semibold text-slate-600 dark:text-slate-300 uppercase tracking-wider whitespace-nowrap">
                {{ $t('TRACKING_TEMPLATES.TABLE.ACTIONS') }}
              </th>
            </tr>
          </thead>
          <tbody class="bg-white dark:bg-slate-900 divide-y divide-slate-100 dark:divide-slate-800">
            <tr
              v-for="template in filteredTemplates"
              :key="template.id"
              class="hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors"
            >
              <td class="px-4 py-3">
                <span class="text-sm font-medium text-slate-800 dark:text-slate-200">
                  {{ template.name }}
                </span>
              </td>
              <td class="px-4 py-3">
                <span class="text-sm text-slate-600 dark:text-slate-400">
                  {{ truncateText(template.objective) }}
                </span>
              </td>
              <td class="px-4 py-3">
                <span
                  v-if="template.inbox_id"
                  class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-woot-50 text-woot-700 dark:bg-woot-800/30 dark:text-woot-300"
                >
                  {{ getInboxName(template) }}
                </span>
                <span v-else class="text-xs text-slate-400">-</span>
              </td>
              <td class="px-4 py-3">
                <span class="text-xs text-slate-600 dark:text-slate-400">
                  {{ getCreatorName(template) }}
                </span>
              </td>
              <td class="px-4 py-3 whitespace-nowrap">
                <span class="text-xs text-slate-500 dark:text-slate-400">
                  {{ formatDate(template.created_at) }}
                </span>
              </td>
              <td class="px-4 py-3 text-right">
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
