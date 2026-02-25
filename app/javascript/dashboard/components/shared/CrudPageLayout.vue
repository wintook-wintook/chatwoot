<script setup>
import { computed } from 'vue';
import CrudTable from './CrudTable.vue';
import BaseSettingsHeader from '../BaseSettingsHeader.vue';
import SettingsLayout from '../../SettingsLayout.vue';

const props = defineProps({
  // Layout props
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    required: true,
  },
  linkText: {
    type: String,
    default: '',
  },
  featureName: {
    type: String,
    required: true,
  },
  addButtonText: {
    type: String,
    required: true,
  },
  
  // Table props
  records: {
    type: Array,
    required: true,
  },
  headers: {
    type: Array,
    required: true,
  },
  loading: {
    type: Object,
    default: () => ({}),
  },
  
  // State props
  isLoading: {
    type: Boolean,
    default: false,
  },
  loadingMessage: {
    type: String,
    default: 'Cargando...',
  },
  noRecordsMessage: {
    type: String,
    default: 'No hay registros disponibles',
  },
  
  // Function props
  canEdit: {
    type: Function,
    default: () => true,
  },
  canDelete: {
    type: Function,
    default: () => true,
  },
  editTooltip: {
    type: String,
    default: 'Editar',
  },
  deleteTooltip: {
    type: String,
    default: 'Eliminar',
  },
});

const emit = defineEmits(['add', 'edit', 'delete']);

const noRecordsFound = computed(() => !props.records.length);

const handleAdd = () => {
  emit('add');
};

const handleEdit = (record) => {
  emit('edit', record);
};

const handleDelete = (record) => {
  emit('delete', record);
};
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="loadingMessage"
    :no-records-found="noRecordsFound"
    :no-records-message="noRecordsMessage"
  >
    <template #header>
      <BaseSettingsHeader
        :title="title"
        :description="description"
        :link-text="linkText"
        :feature-name="featureName"
      >
        <template #actions>
          <!-- Slot personalizable para acciones adicionales -->
          <slot name="header-actions">
            <woot-button
              class="button nice rounded-md"
              icon="add-circle"
              @click="handleAdd"
            >
              {{ addButtonText }}
            </woot-button>
          </slot>
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <CrudTable
        :records="records"
        :headers="headers"
        :loading="loading"
        :can-edit="canEdit"
        :can-delete="canDelete"
        :edit-tooltip="editTooltip"
        :delete-tooltip="deleteTooltip"
        @edit="handleEdit"
        @delete="handleDelete"
      >
        <!-- Pasar el slot de row al CrudTable -->
        <template #row="slotProps">
          <slot name="table-row" v-bind="slotProps"></slot>
        </template>
      </CrudTable>
    </template>

    <!-- Slot para modales y otros elementos -->
    <template #modals>
      <slot name="modals"></slot>
    </template>
  </SettingsLayout>
  
  <!-- Renderizar modales fuera del SettingsLayout -->
  <slot name="modals"></slot>
</template>