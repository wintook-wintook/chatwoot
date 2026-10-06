<!--
  @tickets_cases 2B
  Clasificación ITIL: servicios afectados y categorías/subcategorías. Ahora con
  tablas nativas (vue-easytable) + paginado inferior y pestañas nativas, en lugar
  de las listas de tarjetas. Las categorías se aplanan (padre + subcategorías) en
  una sola tabla con sangría, para conservar el look de tabla sobre un árbol.
-->
<script>
import { mapGetters } from 'vuex';
import { VeTable } from 'vue-easytable';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';

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
const PER_PAGE_OPTIONS = [25, 50, 100];

export default {
  name: 'TicketClassification',
  components: { VeTable, TableFooter },
  data() {
    return {
      activeTabIndex: 0,
      palette: PALETTE,
      perPageOptions: PER_PAGE_OPTIONS,
      servicesPage: 1,
      servicesPerPage: 25,
      categoriesPage: 1,
      categoriesPerPage: 25,
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
          count: this.services.length,
        },
        {
          key: 'categories',
          label: this.$t('CASE_TICKETS.CLASSIFICATION.TAB_CATEGORIES'),
          count: this.categories.length,
        },
      ];
    },
    activeTab() {
      return this.tabs[this.activeTabIndex].key;
    },
    // Aplana categorías → [padre, sus subcategorías, …] con nivel para la sangría.
    flattenedCategories() {
      const rows = [];
      (this.categories || []).forEach(cat => {
        rows.push({ ...cat, level: 0, isSub: false });
        (cat.subcategories || []).forEach(sub => {
          rows.push({ ...sub, level: 1, isSub: true, parentName: cat.name });
        });
      });
      return rows;
    },
    pagedServices() {
      const start = (this.servicesPage - 1) * this.servicesPerPage;
      return this.services.slice(start, start + this.servicesPerPage);
    },
    pagedCategories() {
      const start = (this.categoriesPage - 1) * this.categoriesPerPage;
      return this.flattenedCategories.slice(
        start,
        start + this.categoriesPerPage
      );
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
    serviceColumns() {
      return [
        {
          field: 'name',
          key: 'name',
          title: this.$t('CASE_TICKETS.CLASSIFICATION.TABLE_NAME'),
          align: 'left',
          renderBodyCell: ({ row }) => (
            <div class="flex items-center gap-3 min-w-0">
              <span
                class="flex-shrink-0 w-3 h-3 rounded-full"
                style={{ backgroundColor: row.color }}
              />
              <span class="text-sm font-medium truncate text-slate-800 dark:text-slate-100">
                {row.name}
              </span>
            </div>
          ),
        },
        {
          field: 'status',
          key: 'status',
          title: this.$t('CASE_TICKETS.CLASSIFICATION.TABLE_STATUS'),
          align: 'left',
          width: 140,
          renderBodyCell: ({ row }) => this.statusToggle(row, 'service'),
        },
        {
          field: 'actions',
          key: 'actions',
          title: '',
          align: 'right',
          width: 110,
          renderBodyCell: ({ row }) => (
            <div class="flex items-center justify-end gap-1">
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                icon="edit"
                onClick={() => this.openServiceEdit(row)}
              />
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="alert"
                icon="delete"
                onClick={() => this.askDelete('service', row)}
              />
            </div>
          ),
        },
      ];
    },
    categoryColumns() {
      return [
        {
          field: 'name',
          key: 'name',
          title: this.$t('CASE_TICKETS.CLASSIFICATION.TABLE_NAME'),
          align: 'left',
          renderBodyCell: ({ row }) => (
            <div
              class="flex items-center gap-2 min-w-0"
              style={{ paddingLeft: row.isSub ? '1.5rem' : '0' }}
            >
              {row.isSub ? (
                <span class="text-slate-300 dark:text-slate-600">—</span>
              ) : null}
              <span
                class={
                  row.isSub
                    ? 'text-sm truncate text-slate-700 dark:text-slate-200'
                    : 'text-sm font-medium truncate text-slate-800 dark:text-slate-100'
                }
              >
                {row.name}
              </span>
            </div>
          ),
        },
        {
          field: 'kind',
          key: 'kind',
          title: this.$t('CASE_TICKETS.CLASSIFICATION.TABLE_KIND'),
          align: 'left',
          width: 150,
          renderBodyCell: ({ row }) => (
            <span class="text-xs text-slate-500 dark:text-slate-400">
              {row.isSub
                ? this.$t('CASE_TICKETS.CLASSIFICATION.KIND_SUBCATEGORY')
                : this.$t('CASE_TICKETS.CLASSIFICATION.KIND_CATEGORY')}
            </span>
          ),
        },
        {
          field: 'status',
          key: 'status',
          title: this.$t('CASE_TICKETS.CLASSIFICATION.TABLE_STATUS'),
          align: 'left',
          width: 140,
          renderBodyCell: ({ row }) => this.statusToggle(row, 'category'),
        },
        {
          field: 'actions',
          key: 'actions',
          title: '',
          align: 'right',
          width: 150,
          renderBodyCell: ({ row }) => (
            <div class="flex items-center justify-end gap-1">
              {row.isSub ? null : (
                <woot-button
                  size="tiny"
                  variant="clear"
                  color-scheme="secondary"
                  icon="add"
                  title={this.$t('CASE_TICKETS.CLASSIFICATION.ADD_SUB')}
                  onClick={() => this.openCategoryCreate(row)}
                />
              )}
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="secondary"
                icon="edit"
                onClick={() => this.openCategoryEdit(row)}
              />
              <woot-button
                size="tiny"
                variant="clear"
                color-scheme="alert"
                icon="delete"
                onClick={() => this.askDelete('category', row)}
              />
            </div>
          ),
        },
      ];
    },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchServices');
    this.$store.dispatch('caseTickets/fetchCategories');
  },
  methods: {
    onTabChange(index) {
      this.activeTabIndex = index;
    },
    // Badge de estado que también es toggle (clic alterna activo/inactivo).
    statusToggle(row, kind) {
      const active = !!row.active;
      return (
        <woot-button
          size="tiny"
          variant={active ? 'smooth' : 'clear'}
          color-scheme={active ? 'success' : 'secondary'}
          icon={active ? 'checkmark-circle' : 'dismiss-circle'}
          onClick={() => this.toggleActive(row, kind)}
        >
          {active
            ? this.$t('CASE_TICKETS.CLASSIFICATION.ACTIVE_BADGE')
            : this.$t('CASE_TICKETS.CLASSIFICATION.INACTIVE')}
        </woot-button>
      );
    },
    async toggleActive(row, kind) {
      const action =
        kind === 'service'
          ? 'caseTickets/updateService'
          : 'caseTickets/updateCategory';
      try {
        await this.$store.dispatch(action, { id: row.id, active: !row.active });
      } catch (_e) {
        /* silent */
      }
    },
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
    changeServicesPage(page) {
      this.servicesPage = page;
    },
    changeServicesPerPage() {
      this.servicesPage = 1;
    },
    changeCategoriesPage(page) {
      this.categoriesPage = page;
    },
    changeCategoriesPerPage() {
      this.categoriesPage = 1;
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900"
  >
    <!-- Header + tabs -->
    <div
      class="flex-shrink-0 px-6 pt-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex items-center gap-4 mb-1">
        <woot-button
          size="small"
          variant="clear"
          color-scheme="secondary"
          icon="chevron-left"
          @click="$router.push({ name: 'gestorTickets_index' })"
        >
          {{ $t('CASE_TICKETS.CLASSIFICATION.BACK') }}
        </woot-button>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">
          {{ $t('CASE_TICKETS.CLASSIFICATION.TITLE') }}
        </h1>
      </div>
      <woot-tabs :index="activeTabIndex" class="-mb-px" @change="onTabChange">
        <woot-tabs-item
          v-for="(t, i) in tabs"
          :key="t.key"
          :index="i"
          :name="t.label"
          :count="t.count"
          :show-badge="t.count > 0"
        />
      </woot-tabs>
    </div>

    <!-- ── Servicios ─────────────────────────────────────── -->
    <template v-if="activeTab === 'services'">
      <div class="flex items-center justify-between flex-shrink-0 px-6 py-3">
        <p class="m-0 mr-4 text-sm text-slate-500 dark:text-slate-400">
          {{ $t('CASE_TICKETS.CLASSIFICATION.SERVICES_HELP') }}
        </p>
        <woot-button
          size="small"
          icon="add-circle"
          class="flex-shrink-0"
          @click="openServiceCreate"
        >
          {{ $t('CASE_TICKETS.CLASSIFICATION.NEW_SERVICE') }}
        </woot-button>
      </div>

      <div
        v-if="!services.length"
        class="flex flex-col items-center justify-center flex-1 gap-3 text-slate-400 dark:text-slate-500"
      >
        <fluent-icon icon="folder" size="36" />
        <p>{{ $t('CASE_TICKETS.CLASSIFICATION.EMPTY_SERVICES') }}</p>
      </div>

      <template v-else>
        <div class="flex-1 min-h-0 px-6 pb-2 classif-table-wrap">
          <VeTable
            fixed-header
            max-height="100%"
            row-key-field-name="id"
            :columns="serviceColumns"
            :table-data="pagedServices"
            :border-around="false"
          />
        </div>
        <div
          class="flex items-center justify-between flex-shrink-0 border-t border-slate-50 dark:border-slate-800/50"
        >
          <label
            class="flex items-center gap-1 pl-6 text-xs text-slate-500 dark:text-slate-400"
          >
            {{ $t('CASE_TICKETS.CLASSIFICATION.PER_PAGE') }}
            <select
              v-model.number="servicesPerPage"
              class="!mb-0 w-20 text-sm"
              @change="changeServicesPerPage"
            >
              <option v-for="n in perPageOptions" :key="n" :value="n">
                {{ n }}
              </option>
            </select>
          </label>
          <TableFooter
            :current-page="servicesPage"
            :total-count="services.length"
            :page-size="servicesPerPage"
            @pageChange="changeServicesPage"
          />
        </div>
      </template>
    </template>

    <!-- ── Categorías ────────────────────────────────────── -->
    <template v-else>
      <div class="flex items-center justify-between flex-shrink-0 px-6 py-3">
        <p class="m-0 mr-4 text-sm text-slate-500 dark:text-slate-400">
          {{ $t('CASE_TICKETS.CLASSIFICATION.CATEGORIES_HELP') }}
        </p>
        <woot-button
          size="small"
          icon="add-circle"
          class="flex-shrink-0"
          @click="openCategoryCreate(null)"
        >
          {{ $t('CASE_TICKETS.CLASSIFICATION.NEW_CATEGORY') }}
        </woot-button>
      </div>

      <div
        v-if="!flattenedCategories.length"
        class="flex flex-col items-center justify-center flex-1 gap-3 text-slate-400 dark:text-slate-500"
      >
        <fluent-icon icon="list" size="36" />
        <p>{{ $t('CASE_TICKETS.CLASSIFICATION.EMPTY_CATEGORIES') }}</p>
      </div>

      <template v-else>
        <div class="flex-1 min-h-0 px-6 pb-2 classif-table-wrap">
          <VeTable
            fixed-header
            max-height="100%"
            row-key-field-name="id"
            :columns="categoryColumns"
            :table-data="pagedCategories"
            :border-around="false"
          />
        </div>
        <div
          class="flex items-center justify-between flex-shrink-0 border-t border-slate-50 dark:border-slate-800/50"
        >
          <label
            class="flex items-center gap-1 pl-6 text-xs text-slate-500 dark:text-slate-400"
          >
            {{ $t('CASE_TICKETS.CLASSIFICATION.PER_PAGE') }}
            <select
              v-model.number="categoriesPerPage"
              class="!mb-0 w-20 text-sm"
              @change="changeCategoriesPerPage"
            >
              <option v-for="n in perPageOptions" :key="n" :value="n">
                {{ n }}
              </option>
            </select>
          </label>
          <TableFooter
            :current-page="categoriesPage"
            :total-count="flattenedCategories.length"
            :page-size="categoriesPerPage"
            @pageChange="changeCategoriesPage"
          />
        </div>
      </template>
    </template>

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
                class="border-2 rounded-full w-7 h-7"
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

<style lang="scss" scoped>
.classif-table-wrap {
  overflow: hidden;
}

.classif-table-wrap::v-deep {
  .ve-table {
    height: 100%;
  }
  .ve-table-header-th {
    padding: var(--space-small) var(--space-one) !important;
    font-size: var(--font-size-mini) !important;
  }
  .ve-table-body-td {
    padding: var(--space-small) var(--space-one) !important;
    vertical-align: middle;
  }
}
</style>
