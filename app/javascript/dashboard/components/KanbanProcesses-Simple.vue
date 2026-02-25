<script setup>
// KANBAN0725
import { useAlert } from 'dashboard/composables';
import { computed, onBeforeMount, ref, watch } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';

import SimpleCrudTable from '../../shared/SimpleCrudTable.vue';
import CrudModal from '../../shared/CrudModal.vue';
import FormField from '../../shared/FormField.vue';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

// Estado del componente
const loading = ref({});
const showAddModal = ref(false);
const showEditModal = ref(false);
const showDeleteModal = ref(false);
const selectedItem = ref({});
const selectedKanbanTypeProcessId = ref(null);

// Datos del formulario
const formData = ref({
  type_process_name: '',
  description: '',
  color: '#3B82F6',
  position: 0,
  default: false,
  is_system: false,
});

// Computed
const kanbanTypeProcesses = computed(() => getters['kanbanTypeProcesses/getKanbanTypeProcesses'].value);
const kanbanProcesses = computed(() => getters['kanbanProcesses/getKanbanProcesses'].value);
const kanbanProcessesUIFlags = computed(() => getters['kanbanProcesses/getUIFlags'].value);

const filteredKanbanProcesses = computed(() => {
  if (!selectedKanbanTypeProcessId.value) return [];
  
  const filtered = kanbanProcesses.value.filter(
    process => process.kanban_type_process_id === selectedKanbanTypeProcessId.value
  ).sort((a, b) => a.position - b.position);
  
  // Mapear los datos para que coincidan con la estructura de la tabla
  return filtered.map(item => ({
    ...item,
    name: item.type_process_name,
    description: item.description || `Position: ${item.position}`,
    color: item.color || '#3B82F6',
  }));
});

const kanbanTypeOptions = computed(() => 
  kanbanTypeProcesses.value.map(type => ({
    id: type.id,
    name: type.process_name
  }))
);

const nextPosition = computed(() => {
  const processes = kanbanProcesses.value.filter(
    p => p.kanban_type_process_id === selectedKanbanTypeProcessId.value
  );
  return processes.length > 0 
    ? Math.max(...processes.map(p => p.position)) + 1
    : 0;
});

const deleteMessage = computed(() => ` ${selectedItem.value.type_process_name}?`);
const isFormValid = computed(() => {
  return formData.value.type_process_name && 
         formData.value.type_process_name.length > 0 &&
         typeof formData.value.position === 'number';
});

// Métodos
const resetForm = () => {
  formData.value = {
    type_process_name: '',
    description: '',
    color: '#3B82F6',
    position: nextPosition.value,
    default: false,
    is_system: false,
  };
};

const canDelete = (item) => {
  return !item.is_system;
};

const loadKanbanProcesses = async () => {
  if (selectedKanbanTypeProcessId.value) {
    try {
      await store.dispatch('kanbanProcesses/get', { 
        kanbanTypeProcessId: selectedKanbanTypeProcessId.value 
      });
    } catch (error) {
      useAlert('Error loading kanban processes');
    }
  }
};

const handleAdd = () => {
  if (!selectedKanbanTypeProcessId.value) {
    useAlert('Please select a kanban type process first');
    return;
  }
  resetForm();
  showAddModal.value = true;
};

const handleEdit = (item) => {
  selectedItem.value = item;
  formData.value = {
    type_process_name: item.type_process_name,
    description: item.description || '',
    color: item.color || '#3B82F6',
    position: item.position,
    default: item.default,
    is_system: item.is_system,
  };
  showEditModal.value = true;
};

const handleDelete = (item) => {
  selectedItem.value = item;
  showDeleteModal.value = true;
};

const closeAddModal = () => {
  showAddModal.value = false;
  resetForm();
};

const closeEditModal = () => {
  showEditModal.value = false;
  resetForm();
};

const closeDeleteModal = () => {
  showDeleteModal.value = false;
  selectedItem.value = {};
};

const submitAdd = async () => {
  try {
    await store.dispatch('kanbanProcesses/create', {
      kanban_type_process_id: selectedKanbanTypeProcessId.value,
      ...formData.value,
    });
    useAlert('Kanban Process created successfully');
    closeAddModal();
  } catch (error) {
    useAlert(error?.message || 'Error creating Kanban Process');
  }
};

const submitEdit = async () => {
  try {
    await store.dispatch('kanbanProcesses/update', {
      id: selectedItem.value.id,
      ...formData.value,
    });
    useAlert('Kanban Process updated successfully');
    closeEditModal();
  } catch (error) {
    useAlert(error?.message || 'Error updating Kanban Process');
  }
};

const confirmDelete = async () => {
  loading.value[selectedItem.value.id] = true;
  try {
    await store.dispatch('kanbanProcesses/delete', selectedItem.value.id);
    useAlert('Kanban Process deleted successfully');
  } catch (error) {
    useAlert(error?.message || 'Error deleting Kanban Process');
  } finally {
    loading.value[selectedItem.value.id] = false;
    closeDeleteModal();
  }
};

// Watchers
watch(selectedKanbanTypeProcessId, loadKanbanProcesses);
watch(nextPosition, (newVal) => {
  if (showAddModal.value) {
    formData.value.position = newVal;
  }
});

onBeforeMount(async () => {
  await store.dispatch('kanbanTypeProcesses/get');
  if (kanbanTypeProcesses.value.length > 0) {
    selectedKanbanTypeProcessId.value = kanbanTypeProcesses.value[0].id;
  }
});
</script>

<template>
  <div class="p-6">
    <div class="mb-6">
      <h1 class="text-2xl font-semibold text-slate-900 dark:text-slate-100 mb-2">
        Kanban Processes
      </h1>
      <p class="text-slate-600 dark:text-slate-400 mb-4">
        Manage the specific processes within each kanban type process.
      </p>
      
      <!-- Selector de Tipo de Proceso -->
      <div class="mb-4">
        <FormField
          v-model="selectedKanbanTypeProcessId"
          type="select"
          label="Select Kanban Type Process"
          :options="kanbanTypeOptions"
          placeholder="Choose a type process"
        />
      </div>
    </div>

    <!-- Tabla -->
    <SimpleCrudTable
      v-if="selectedKanbanTypeProcessId"
      :records="filteredKanbanProcesses"
      :loading="loading"
      :can-delete="canDelete"
      name-field="type_process_name"
      description-field="description"
      color-field="color"
      @add="handleAdd"
      @edit="handleEdit"
      @delete="handleDelete"
    />

    <div v-else class="bg-slate-50 dark:bg-slate-800 rounded-lg border-2 border-dashed border-slate-300 dark:border-slate-600 p-12 text-center">
      <div class="text-slate-500 dark:text-slate-400">
        <div class="text-4xl mb-4">🔄</div>
        <div class="text-lg font-medium mb-2">Select a Type Process</div>
        <div class="text-sm">Choose a kanban type process to view and manage its processes.</div>
      </div>
    </div>

    <!-- Modal Agregar -->
    <CrudModal
      :show="showAddModal"
      title="Add Kanban Process"
      description="Create a new process within the selected kanban type."
      :is-loading="kanbanProcessesUIFlags.isCreating"
      :is-disabled="!isFormValid"
      submit-text="Create Process"
      cancel-text="Cancel"
      @close="closeAddModal"
      @submit="submitAdd"
    >
      <template #form-content>
        <FormField
          v-model="formData.type_process_name"
          type="text"
          label="Process Name"
          placeholder="Enter the process name"
          required
        />
        
        <FormField
          v-model="formData.description"
          type="textarea"
          label="Description"
          placeholder="Enter a description (optional)"
        />

        <div class="w-full mb-4">
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
            Color
          </label>
          <div class="flex items-center space-x-3">
            <input
              v-model="formData.color"
              type="color"
              class="w-12 h-10 border border-slate-300 dark:border-slate-600 rounded-md cursor-pointer"
            />
            <input
              v-model="formData.color"
              type="text"
              class="flex-1 border border-slate-300 dark:border-slate-600 rounded-md px-3 py-2 text-sm bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-300"
              placeholder="#3B82F6"
            />
          </div>
        </div>
        
        <FormField
          v-model="formData.position"
          type="number"
          label="Position"
          placeholder="Enter position"
          :min="0"
          required
        />
        
        <FormField
          v-model="formData.default"
          type="checkbox"
          label="Set as default process"
        />
        
        <FormField
          v-model="formData.is_system"
          type="checkbox"
          label="System process"
        />
      </template>
    </CrudModal>

    <!-- Modal Editar -->
    <CrudModal
      :show="showEditModal"
      :title="`Edit Process - ${selectedItem.type_process_name}`"
      :is-loading="kanbanProcessesUIFlags.isUpdating"
      :is-disabled="!isFormValid"
      submit-text="Update Process"
      cancel-text="Cancel"
      @close="closeEditModal"
      @submit="submitEdit"
    >
      <template #form-content>
        <FormField
          v-model="formData.type_process_name"
          type="text"
          label="Process Name"
          placeholder="Enter the process name"
          required
        />
        
        <FormField
          v-model="formData.description"
          type="textarea"
          label="Description"
          placeholder="Enter a description (optional)"
        />

        <div class="w-full mb-4">
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
            Color
          </label>
          <div class="flex items-center space-x-3">
            <input
              v-model="formData.color"
              type="color"
              class="w-12 h-10 border border-slate-300 dark:border-slate-600 rounded-md cursor-pointer"
            />
            <input
              v-model="formData.color"
              type="text"
              class="flex-1 border border-slate-300 dark:border-slate-600 rounded-md px-3 py-2 text-sm bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-300"
              placeholder="#3B82F6"
            />
          </div>
        </div>
        
        <FormField
          v-model="formData.position"
          type="number"
          label="Position"
          placeholder="Enter position"
          :min="0"
          required
        />
        
        <FormField
          v-model="formData.default"
          type="checkbox"
          label="Set as default process"
        />
        
        <FormField
          v-model="formData.is_system"
          type="checkbox"
          label="System process"
          :disabled="selectedItem.is_system"
        />
      </template>
    </CrudModal>

    <!-- Modal Confirmar Eliminación -->
    <woot-delete-modal
      :show.sync="showDeleteModal"
      :on-close="closeDeleteModal"
      :on-confirm="confirmDelete"
      title="Confirm Deletion"
      message="Are you sure you want to delete this kanban process?"
      :message-value="deleteMessage"
      confirm-text="Yes, Delete"
      reject-text="Cancel"
    />
  </div>
</template>