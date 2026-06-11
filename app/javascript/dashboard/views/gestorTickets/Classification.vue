<!--
  @tickets_cases 2B
  Gestión de la clasificación ITIL: servicios afectados y categorías/subcategorías.
  Tailwind + dark mode, mismo estilo que TicketTypes.vue.
-->
<script>
import { mapGetters } from 'vuex';

const PALETTE = [
  '#3b82f6',
  '#8b5cf6',
  '#06b6d4',
  '#f59e0b',
  '#ef4444',
  '#22c55e',
  '#ec4899',
  '#64748b',
];

export default {
  name: 'TicketClassification',
  data() {
    return {
      activeTab: 'services',
      palette: PALETTE,
      // servicios
      showServiceModal: false,
      serviceEditing: null,
      serviceForm: { name: '', color: '#64748b', active: true },
      // categorías
      showCategoryModal: false,
      categoryEditing: null,
      categoryForm: { name: '', active: true, parent_id: null },
      parentName: '',
      // borrado
      showDeleteModal: false,
      deleteKind: null,
      toDelete: null,
    };
  },
  computed: {
    ...mapGetters({
      services: 'caseTickets/getServices',
      servicesUiFlags: 'caseTickets/getServicesUIFlags',
      categories: 'caseTickets/getCategories',
      categoriesUiFlags: 'caseTickets/getCategoriesUIFlags',
    }),
    tabs() {
      return [
        {
          key: 'services',
          label: this.$t('CASE_TICKETS.CLASSIFICATION.TAB_SERVICES'),
        },
        {
          key: 'categories',
          label: this.$t('CASE_TICKETS.CLASSIFICATION.TAB_CATEGORIES'),
        },
      ];
    },
    categoryModalTitle() {
      if (this.categoryEditing)
        return this.$t('CASE_TICKETS.CLASSIFICATION.EDIT_CATEGORY');
      return this.categoryForm.parent_id
        ? this.$t('CASE_TICKETS.CLASSIFICATION.NEW_SUBCATEGORY')
        : this.$t('CASE_TICKETS.CLASSIFICATION.NEW_CATEGORY');
    },
    deleteMessageValue() {
      return this.toDelete ? ` "${this.toDelete.name}"?` : '';
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchServices');
    this.$store.dispatch('caseTickets/fetchCategories');
  },
  methods: {
    // ── servicios ──
    openServiceCreate() {
      this.serviceEditing = null;
      this.serviceForm = { name: '', color: '#64748b', active: true };
      this.showServiceModal = true;
    },
    openServiceEdit(s) {
      this.serviceEditing = s;
      this.serviceForm = { name: s.name, color: s.color, active: s.active };
      this.showServiceModal = true;
    },
    async saveService() {
      try {
        if (this.serviceEditing) {
          await this.$store.dispatch('caseTickets/updateService', {
            id: this.serviceEditing.id,
            ...this.serviceForm,
          });
        } else {
          await this.$store.dispatch(
            'caseTickets/createService',
            this.serviceForm
          );
        }
        this.showServiceModal = false;
      } catch (_e) {
        /* silent */
      }
    },
    // ── categorías ──
    openCategoryCreate(parent) {
      this.categoryEditing = null;
      this.parentName = parent ? parent.name : '';
      this.categoryForm = {
        name: '',
        active: true,
        parent_id: parent ? parent.id : null,
      };
      this.showCategoryModal = true;
    },
    openCategoryEdit(c) {
      this.categoryEditing = c;
      this.categoryForm = {
        name: c.name,
        active: c.active,
        parent_id: c.parent_id || null,
      };
      this.showCategoryModal = true;
    },
    async saveCategory() {
      try {
        if (this.categoryEditing) {
          await this.$store.dispatch('caseTickets/updateCategory', {
            id: this.categoryEditing.id,
            ...this.categoryForm,
          });
        } else {
          await this.$store.dispatch(
            'caseTickets/createCategory',
            this.categoryForm
          );
        }
        this.showCategoryModal = false;
      } catch (_e) {
        /* silent */
      }
    },
    // ── borrado ──
    askDelete(kind, record) {
      this.deleteKind = kind;
      this.toDelete = record;
      this.showDeleteModal = true;
    },
    closeDelete() {
      this.showDeleteModal = false;
      this.toDelete = null;
      this.deleteKind = null;
    },
    async confirmDelete() {
      const { deleteKind, toDelete } = this;
      if (!toDelete) return;
      this.showDeleteModal = false;
      try {
        if (deleteKind === 'service') {
          await this.$store.dispatch('caseTickets/deleteService', toDelete.id);
        } else {
          await this.$store.dispatch('caseTickets/deleteCategory', toDelete.id);
        }
      } finally {
        this.toDelete = null;
        this.deleteKind = null;
      }
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <!-- Header -->
    <div
      class="flex items-center justify-between flex-shrink-0 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex items-center gap-4">
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          icon="arrow-left"
          @click="$router.push({ name: 'gestorTickets_index' })"
        >
          {{ $t('CASE_TICKETS.CLASSIFICATION.BACK') }}
        </woot-button>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CASE_TICKETS.CLASSIFICATION.TITLE') }}
        </h1>
      </div>
    </div>

    <!-- Tabs -->
    <div class="flex gap-1 px-6 pt-4">
      <button
        v-for="tab in tabs"
        :key="tab.key"
        class="px-3 py-1.5 text-sm font-medium rounded-t-lg"
        :class="
          activeTab === tab.key
            ? 'bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100'
            : 'text-slate-500 dark:text-slate-400 hover:text-slate-700'
        "
        @click="activeTab = tab.key"
      >
        {{ tab.label }}
      </button>
    </div>

    <div class="flex flex-col flex-1 gap-2 px-6 py-4 overflow-y-auto">
      <!-- ── Servicios ─────────────────────────────────────── -->
      <template v-if="activeTab === 'services'">
        <div class="flex items-center justify-between mb-2">
          <p class="m-0 text-sm text-slate-500 dark:text-slate-400">
            {{ $t('CASE_TICKETS.CLASSIFICATION.SERVICES_HELP') }}
          </p>
          <woot-button
            size="small"
            icon="add-circle"
            @click="openServiceCreate"
          >
            {{ $t('CASE_TICKETS.CLASSIFICATION.NEW_SERVICE') }}
          </woot-button>
        </div>
        <div
          v-for="s in services"
          :key="s.id"
          class="flex items-center gap-3 p-3 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <span
            class="flex-shrink-0 w-4 h-4 rounded-full"
            :style="{ backgroundColor: s.color }"
          />
          <span
            class="flex-1 text-sm font-medium text-slate-800 dark:text-slate-100"
            >{{ s.name }}</span
          >
          <span
            v-if="!s.active"
            class="px-1.5 py-0.5 text-xs rounded bg-slate-100 text-slate-500 dark:bg-slate-700"
            >{{ $t('CASE_TICKETS.CLASSIFICATION.INACTIVE') }}</span
          >
          <woot-button
            size="tiny"
            variant="clear"
            color-scheme="secondary"
            icon="edit"
            @click="openServiceEdit(s)"
          />
          <woot-button
            size="tiny"
            variant="clear"
            color-scheme="alert"
            icon="delete"
            @click="askDelete('service', s)"
          />
        </div>
      </template>

      <!-- ── Categorías ────────────────────────────────────── -->
      <template v-else>
        <div class="flex items-center justify-between mb-2">
          <p class="m-0 text-sm text-slate-500 dark:text-slate-400">
            {{ $t('CASE_TICKETS.CLASSIFICATION.CATEGORIES_HELP') }}
          </p>
          <woot-button
            size="small"
            icon="add-circle"
            @click="openCategoryCreate(null)"
          >
            {{ $t('CASE_TICKETS.CLASSIFICATION.NEW_CATEGORY') }}
          </woot-button>
        </div>
        <div
          v-for="c in categories"
          :key="c.id"
          class="bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
        >
          <div class="flex items-center gap-3 p-3">
            <span
              class="flex-1 text-sm font-medium text-slate-800 dark:text-slate-100"
              >{{ c.name }}</span
            >
            <span
              v-if="!c.active"
              class="px-1.5 py-0.5 text-xs rounded bg-slate-100 text-slate-500 dark:bg-slate-700"
              >{{ $t('CASE_TICKETS.CLASSIFICATION.INACTIVE') }}</span
            >
            <woot-button
              size="tiny"
              variant="clear"
              color-scheme="secondary"
              icon="add"
              @click="openCategoryCreate(c)"
            />
            <woot-button
              size="tiny"
              variant="clear"
              color-scheme="secondary"
              icon="edit"
              @click="openCategoryEdit(c)"
            />
            <woot-button
              size="tiny"
              variant="clear"
              color-scheme="alert"
              icon="delete"
              @click="askDelete('category', c)"
            />
          </div>
          <div
            v-for="sub in c.subcategories"
            :key="sub.id"
            class="flex items-center gap-3 px-3 py-2 ml-6 border-t border-slate-50 dark:border-slate-700/50"
          >
            <span class="text-slate-400">—</span>
            <span class="flex-1 text-sm text-slate-700 dark:text-slate-200">{{
              sub.name
            }}</span>
            <woot-button
              size="tiny"
              variant="clear"
              color-scheme="secondary"
              icon="edit"
              @click="openCategoryEdit(sub)"
            />
            <woot-button
              size="tiny"
              variant="clear"
              color-scheme="alert"
              icon="delete"
              @click="askDelete('category', sub)"
            />
          </div>
        </div>
      </template>
    </div>

    <!-- Modal servicio -->
    <woot-modal
      v-if="showServiceModal"
      :show="showServiceModal"
      :on-close="() => (showServiceModal = false)"
      size="small"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="
            serviceEditing
              ? $t('CASE_TICKETS.CLASSIFICATION.EDIT_SERVICE')
              : $t('CASE_TICKETS.CLASSIFICATION.NEW_SERVICE')
          "
        />
        <form
          class="flex flex-col self-stretch w-full gap-4 pb-8"
          @submit.prevent="saveService"
        >
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.CLASSIFICATION.NAME_LABEL') }} *</span
            >
            <input
              v-model="serviceForm.name"
              type="text"
              class="w-full"
              required
              maxlength="100"
            />
          </label>
          <div class="flex flex-col gap-1">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.CLASSIFICATION.COLOR_LABEL') }}</span
            >
            <div class="flex items-center gap-2">
              <button
                v-for="col in palette"
                :key="col"
                type="button"
                class="rounded-full border-2 w-7 h-7"
                :class="
                  serviceForm.color === col
                    ? 'border-slate-800 dark:border-white scale-110'
                    : 'border-transparent'
                "
                :style="{ backgroundColor: col }"
                @click="serviceForm.color = col"
              />
              <input
                v-model="serviceForm.color"
                type="color"
                class="w-8 h-8 p-0 bg-transparent border-0 rounded cursor-pointer"
              />
            </div>
          </div>
          <label class="flex items-center gap-2">
            <input v-model="serviceForm.active" type="checkbox" />
            <span class="text-sm text-slate-700 dark:text-slate-200">{{
              $t('CASE_TICKETS.CLASSIFICATION.ACTIVE_LABEL')
            }}</span>
          </label>
          <div class="flex justify-end gap-2 mt-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              type="button"
              @click="showServiceModal = false"
            >
              {{ $t('CASE_TICKETS.CLASSIFICATION.CANCEL') }}
            </woot-button>
            <woot-button
              type="submit"
              :is-loading="servicesUiFlags.isSaving"
              :disabled="!serviceForm.name.trim()"
            >
              {{ $t('CASE_TICKETS.CLASSIFICATION.SAVE') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Modal categoría -->
    <woot-modal
      v-if="showCategoryModal"
      :show="showCategoryModal"
      :on-close="() => (showCategoryModal = false)"
      size="small"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header :header-title="categoryModalTitle" />
        <form
          class="flex flex-col self-stretch w-full gap-4 pb-8"
          @submit.prevent="saveCategory"
        >
          <p
            v-if="categoryForm.parent_id"
            class="m-0 text-xs text-slate-500 dark:text-slate-400"
          >
            {{
              $t('CASE_TICKETS.CLASSIFICATION.SUBCATEGORY_OF', {
                parent: parentName,
              })
            }}
          </p>
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.CLASSIFICATION.NAME_LABEL') }} *</span
            >
            <input
              v-model="categoryForm.name"
              type="text"
              class="w-full"
              required
              maxlength="100"
            />
          </label>
          <label class="flex items-center gap-2">
            <input v-model="categoryForm.active" type="checkbox" />
            <span class="text-sm text-slate-700 dark:text-slate-200">{{
              $t('CASE_TICKETS.CLASSIFICATION.ACTIVE_LABEL')
            }}</span>
          </label>
          <div class="flex justify-end gap-2 mt-2">
            <woot-button
              variant="clear"
              color-scheme="secondary"
              type="button"
              @click="showCategoryModal = false"
            >
              {{ $t('CASE_TICKETS.CLASSIFICATION.CANCEL') }}
            </woot-button>
            <woot-button
              type="submit"
              :is-loading="categoriesUiFlags.isSaving"
              :disabled="!categoryForm.name.trim()"
            >
              {{ $t('CASE_TICKETS.CLASSIFICATION.SAVE') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Confirmación de borrado -->
    <woot-delete-modal
      :show.sync="showDeleteModal"
      :on-close="closeDelete"
      :on-confirm="confirmDelete"
      :title="$t('CASE_TICKETS.CLASSIFICATION.DELETE.TITLE')"
      :message="$t('CASE_TICKETS.CLASSIFICATION.DELETE.MESSAGE')"
      :message-value="deleteMessageValue"
      :confirm-text="$t('CASE_TICKETS.CLASSIFICATION.DELETE.YES')"
      :reject-text="$t('CASE_TICKETS.CLASSIFICATION.DELETE.NO')"
    />
  </div>
</template>
