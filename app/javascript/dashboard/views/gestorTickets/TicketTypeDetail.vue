<!--
  @tickets_cases
  Detalle de un Tipo de Caso: cabecera con sus datos + pestañas de Campos
  personalizados y Columnas del tablero. Cada pestaña gestiona sus propias tablas
  y modales; aquí solo vive la navegación, la cabecera y la edición del tipo.
-->
<script>
import { mapGetters } from 'vuex';
import FieldsTab from './typeDetail/FieldsTab.vue';
import ColumnsTab from './typeDetail/ColumnsTab.vue';
import TypeFormModal from './typeDetail/TypeFormModal.vue';

export default {
  name: 'TicketTypeDetail',
  components: { FieldsTab, ColumnsTab, TypeFormModal },
  props: {
    typeId: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      activeTabIndex: 0,
      showEditModal: false,
    };
  },
  computed: {
    ...mapGetters({
      types: 'caseTickets/getTypes',
      typesUiFlags: 'caseTickets/getTypesUIFlags',
      getTypeFields: 'caseTickets/getTypeFields',
      getTypeColumns: 'caseTickets/getTypeColumns',
    }),
    type() {
      return this.types.find(t => t.id === this.typeId) || null;
    },
    isLoading() {
      return this.typesUiFlags.isFetching && !this.type;
    },
    fieldsCount() {
      const fromStore = this.getTypeFields(this.typeId).length;
      return (
        fromStore || (this.type ? (this.type.custom_fields || []).length : 0)
      );
    },
    columnsCount() {
      const fromStore = this.getTypeColumns(this.typeId).length;
      return fromStore || (this.type ? (this.type.columns || []).length : 0);
    },
    tabs() {
      return [
        {
          key: 'fields',
          label: this.$t('CASE_TICKETS.TYPES.DETAIL.FIELDS_TAB'),
          count: this.fieldsCount,
        },
        {
          key: 'columns',
          label: this.$t('CASE_TICKETS.TYPES.DETAIL.COLUMNS_TAB'),
          count: this.columnsCount,
        },
      ];
    },
  },
  mounted() {
    // Navegación directa / refresco: si la lista de tipos no está cargada,
    // la traemos para poder resolver la cabecera de este tipo.
    if (!this.types.length) {
      this.$store.dispatch('caseTickets/fetchTypes');
    }
  },
  methods: {
    goBack() {
      this.$router.push({ name: 'gestorTickets_types' });
    },
    onTabChange(index) {
      this.activeTabIndex = index;
    },
    onTypeSaved() {
      this.$store.dispatch('caseTickets/fetchTypes');
    },
    // Refresca los contadores de la cabecera al cambiar campos/columnas.
    refreshCounts() {
      this.$store.dispatch('caseTickets/fetchTypes');
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
      class="flex-shrink-0 px-6 pt-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50"
    >
      <div class="flex items-center justify-between mb-1">
        <div class="flex items-center min-w-0 gap-3">
          <woot-button
            size="small"
            variant="clear"
            color-scheme="secondary"
            icon="chevron-left"
            @click="goBack"
          >
            {{ $t('CASE_TICKETS.TYPES.DETAIL.BACK') }}
          </woot-button>

          <template v-if="type">
            <span
              class="flex-shrink-0 w-4 h-4 rounded-full"
              :style="{ backgroundColor: type.color }"
            />
            <h1
              class="m-0 text-xl font-bold truncate text-slate-800 dark:text-slate-100"
            >
              {{ type.name }}
            </h1>
            <span
              v-if="type.prefix"
              class="px-1.5 py-0.5 font-mono text-xs rounded bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
              >{{ type.prefix }}</span
            >
            <span
              v-if="type.public"
              class="px-1.5 py-0.5 text-xs rounded-full bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300"
              >{{ $t('CASE_TICKETS.TYPES.PUBLIC_ON') }}</span
            >
          </template>
        </div>

        <woot-button
          v-if="type"
          size="small"
          variant="smooth"
          color-scheme="secondary"
          icon="edit"
          @click="showEditModal = true"
        >
          {{ $t('CASE_TICKETS.EDIT.BUTTON') }}
        </woot-button>
      </div>

      <!-- Tabs -->
      <woot-tabs
        v-if="type"
        :index="activeTabIndex"
        class="-mb-px"
        @change="onTabChange"
      >
        <woot-tabs-item
          v-for="(t, i) in tabs"
          :key="t.key"
          :index="i"
          :name="t.label"
          :count="t.count"
        />
      </woot-tabs>
    </div>

    <!-- Loading -->
    <div
      v-if="isLoading"
      class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500"
    >
      <span>{{ $t('CASE_TICKETS.TYPES.DETAIL.LOADING') }}</span>
    </div>

    <!-- Not found -->
    <div
      v-else-if="!type"
      class="flex flex-col items-center justify-center flex-1 gap-4 text-slate-400 dark:text-slate-500"
    >
      <fluent-icon icon="warning" size="36" />
      <p>{{ $t('CASE_TICKETS.TYPES.DETAIL.NOT_FOUND') }}</p>
      <woot-button size="small" variant="clear" @click="goBack">
        {{ $t('CASE_TICKETS.TYPES.DETAIL.BACK') }}
      </woot-button>
    </div>

    <!-- Contenido de las pestañas (ambas montadas para conservar el borrador
         de columnas sin guardar al alternar de pestaña). -->
    <template v-else>
      <FieldsTab
        v-show="activeTabIndex === 0"
        :case-type-id="typeId"
        @changed="refreshCounts"
      />
      <ColumnsTab
        v-show="activeTabIndex === 1"
        :case-type-id="typeId"
        @changed="refreshCounts"
      />
    </template>

    <!-- Modal de edición del tipo -->
    <TypeFormModal
      v-if="type"
      :show="showEditModal"
      :editing="type"
      @saved="onTypeSaved"
      @close="showEditModal = false"
    />
  </div>
</template>
