// ✅ FUNCIÓN DE REFRESH QUE ACTUALIZA TODO
const refreshData = async () => {
  try {
    console.log('🔄 Manual refresh started...');
    await store.dispatch('kanbanTypeProcesses/get');
    const storeData = getters['kanbanTypeProcesses/getKanbanTypeProcesses'].value;
    localRecords.value = [...storeData];
    lastRefresh.value = new Date();
    console.log('✅ Manual refresh completed:', localRecords.value.length, 'records');
    useAlert('Data refreshed successfully');
  } catch (error) {
    console.error('❌ Manual refresh error:', error);
    useAlert('Error refreshing data');
  }
};

// ✅ FUNCIÓN DE AUTO-REFRESH DESPUÉS DE CAMBIOS
const autoRefresh = async () => {
  try {
    console.log('🔄 Auto-refresh started...');
    await store.dispatch('kanbanTypeProcesses/get');
    const storeData = getters['kanbanTypeProcesses/getKanbanTypeProcesses'].value;
    localRecords.value = [...storeData];
    lastRefresh.value = new Date();
    console.log('✅ Auto-refresh completed:', localRecords.value.length, 'records');
  } catch (error) {
    console.error('❌ Auto-refresh error:', error);
  }
};

<script setup>
// KANBAN0725
// ✅ LOGS INMEDIATOS PARA VER SI SE CARGA
console.log('🚀 COMPONENT LOADING - KanbanTypeProcesses started');

import { useAlert } from 'dashboard/composables';
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';

console.log('📦 Imports loaded successfully');

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

console.log('🎯 Composables initialized:', { 
  hasGetters: !!getters, 
  hasStore: !!store, 
  hasT: !!t 
});

// Estado del componente
const loading = ref({});
const showAddModal = ref(false);
const showEditModal = ref(false);
const showDeleteModal = ref(false);
const selectedItem = ref({});
const localRecords = ref([]); // ✅ ESTADO LOCAL PARA LOS REGISTROS
const lastRefresh = ref(new Date());

console.log('📊 Component state initialized');

// Datos del formulario
const formData = ref({
  process_name: '',
  description: '',
  color: '#6F2CE5',
  default: false,
  is_system: false,
});

// Computed
const uiFlags = computed(() => getters['kanbanTypeProcesses/getUIFlags'].value);
const deleteMessage = computed(() => ` ${selectedItem.value.process_name}?`);
const isFormValid = computed(() => {
  return formData.value.process_name && formData.value.process_name.length > 0;
});

// Métodos
const resetForm = () => {
  formData.value = {
    process_name: '',
    description: '',
    color: '#6F2CE5',
    default: false,
    is_system: false,
  };
};

const canDelete = (item) => {
  return !item.is_system;
};

const handleAdd = () => {
  resetForm();
  showAddModal.value = true;
};

const handleEdit = (item) => {
  selectedItem.value = item;
  formData.value = {
    process_name: item.process_name,
    description: item.description || '',
    color: item.color || '#6F2CE5',
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
    console.log('🔄 Creating with data:', formData.value);
    const response = await store.dispatch('kanbanTypeProcesses/create', formData.value);
    console.log('✅ Create response:', response);
    
    useAlert('Kanban Type Process created successfully');
    closeAddModal();
    
    // ✅ AUTO-REFRESH DESPUÉS DE CREAR
    await autoRefresh();
  } catch (error) {
    console.error('❌ Create error:', error);
    useAlert(error?.message || 'Error creating Kanban Type Process');
  }
};

const submitEdit = async () => {
  try {
    console.log('🔄 Updating with data:', formData.value);
    const response = await store.dispatch('kanbanTypeProcesses/update', {
      id: selectedItem.value.id,
      ...formData.value,
    });
    console.log('✅ Update response:', response);
    
    useAlert('Kanban Type Process updated successfully');
    closeEditModal();
    
    // ✅ AUTO-REFRESH DESPUÉS DE EDITAR
    await autoRefresh();
  } catch (error) {
    console.error('❌ Update error:', error);
    useAlert(error?.message || 'Error updating Kanban Type Process');
  }
};

const confirmDelete = async () => {
  loading.value[selectedItem.value.id] = true;
  try {
    console.log('🔄 Deleting item:', selectedItem.value.id);
    await store.dispatch('kanbanTypeProcesses/delete', selectedItem.value.id);
    console.log('✅ Delete completed');
    
    useAlert('Kanban Type Process deleted successfully');
    closeDeleteModal();
    
    // ✅ AUTO-REFRESH DESPUÉS DE ELIMINAR
    await autoRefresh();
  } catch (error) {
    console.error('❌ Delete error:', error);
    useAlert(error?.message || 'Error deleting Kanban Type Process');
  } finally {
    loading.value[selectedItem.value.id] = false;
  }
};

onBeforeMount(async () => {
  console.log('🔄 onBeforeMount started');
  try {
    console.log('🔄 Loading initial data...');
    await store.dispatch('kanbanTypeProcesses/get');
    console.log('📡 Store dispatch completed');
    
    // ✅ CARGAR DATOS INICIALES AL ESTADO LOCAL
    const storeData = getters['kanbanTypeProcesses/getKanbanTypeProcesses'].value;
    console.log('📊 Store data received:', storeData);
    
    localRecords.value = [...storeData];
    lastRefresh.value = new Date();
    console.log('✅ Initial data loaded to localRecords:', localRecords.value.length, 'items');
  } catch (error) {
    console.error('❌ Error loading initial data:', error);
  }
  console.log('✅ onBeforeMount completed');
});

// ✅ LOG FINAL DE SETUP
console.log('🏁 Component setup completed');
</script>

<template>
  <div class="p-6 max-w-7xl mx-auto">
    <!-- DEBUG INFO MÁS VISIBLE -->
    <div class="bg-yellow-100 border-l-4 border-yellow-500 p-4 mb-6">
      <div class="flex items-center">
        <div class="ml-3">
          <h3 class="text-sm font-medium text-yellow-800">🐛 Component Debug Status</h3>
          <div class="mt-2 text-sm text-yellow-700">
            <p>✅ Component loaded: TRUE</p>
            <p>📊 Local records: {{ localRecords.length }} items</p>
            <p>🔄 Is fetching: {{ uiFlags.isFetching }}</p>
            <p>⏰ Last refresh: {{ lastRefresh.toLocaleTimeString() }}</p>
            <p>🆔 Component ID: {{ Math.random().toString(36).substr(2, 9) }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Header -->
    <div class="mb-6">
      <h1 class="text-2xl font-semibold text-slate-900 dark:text-slate-100 mb-2">
        Kanban Type Processes
      </h1>
      <p class="text-slate-600 dark:text-slate-400">
        Manage the different types of kanban processes for your organization.
      </p>
    </div>

    <!-- Loading State -->
    <div v-if="uiFlags.isFetching" class="flex items-center justify-center py-12">
      <div class="flex items-center space-x-3">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <span class="text-slate-600 dark:text-slate-400">Loading...</span>
      </div>
    </div>

    <!-- Tabla Manual (sin dependencias externas) -->
    <div v-else class="w-full">
      <!-- Header con botón agregar y refresh -->
      <div class="flex items-center justify-between mb-6">
        <!-- Botón Refresh -->
        <woot-button
          variant="clear"
          icon="refresh"
          size="small"
          :is-loading="uiFlags.isFetching"
          @click="refreshData"
        >
          Refresh
        </woot-button>
        
        <!-- Botón Agregar -->
        <woot-button
          class="button nice rounded-md"
          icon="add-circle"
          color-scheme="primary"
          @click="handleAdd"
        >
          Add new type process
        </woot-button>
      </div>

      <!-- Tabla -->
      <div class="bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 overflow-hidden">
        <table class="min-w-full">
          <thead class="bg-slate-50 dark:bg-slate-900">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                Name
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                Description
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                Color
              </th>
              <th class="px-6 py-3 text-right text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="bg-white dark:bg-slate-800 divide-y divide-slate-200 dark:divide-slate-700">
            <tr v-for="record in localRecords" :key="record.id" class="hover:bg-slate-50 dark:hover:bg-slate-700">
              <!-- Name -->
              <td class="px-6 py-4">
                <div class="text-sm font-medium text-slate-900 dark:text-slate-100">
                  {{ record.process_name }}
                </div>
              </td>
              
              <!-- Description -->
              <td class="px-6 py-4">
                <div class="text-sm text-slate-600 dark:text-slate-400">
                  {{ record.description || 'No description' }}
                </div>
              </td>
              
              <!-- Color -->
              <td class="px-6 py-4">
                <div class="flex items-center">
                  <div
                    class="w-4 h-4 rounded border border-slate-300 dark:border-slate-600 mr-2"
                    :style="{ backgroundColor: record.color || '#6F2CE5' }"
                  ></div>
                  <span class="text-sm font-mono text-slate-600 dark:text-slate-400">
                    {{ record.color || '#6F2CE5' }}
                  </span>
                </div>
              </td>
              
              <!-- Actions -->
              <td class="px-6 py-4 text-right text-sm font-medium">
                <div class="flex items-center justify-end space-x-2">
                  <woot-button
                    variant="smooth"
                    size="tiny"
                    color-scheme="secondary"
                    icon="edit"
                    :is-loading="loading[record.id]"
                    @click="handleEdit(record)"
                  />
                  <woot-button
                    v-if="canDelete(record)"
                    variant="smooth"
                    size="tiny"
                    color-scheme="alert"
                    icon="dismiss-circle"
                    :is-loading="loading[record.id]"
                    @click="handleDelete(record)"
                  />
                </div>
              </td>
            </tr>
            
            <!-- Empty state -->
            <tr v-if="localRecords.length === 0">
              <td colspan="4" class="px-6 py-12 text-center">
                <div class="text-slate-500 dark:text-slate-400">
                  <div class="text-4xl mb-2">📋</div>
                  <div class="text-sm">No kanban type processes found</div>
                  <woot-button
                    class="mt-4"
                    color-scheme="primary"
                    size="small"
                    @click="handleAdd"
                  >
                    Create your first one
                  </woot-button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Modal Agregar -->
    <woot-modal v-if="showAddModal" :show="showAddModal" :on-close="closeAddModal">
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header 
          header-title="Add Kanban Type Process"
          header-content="Create a new kanban type process to organize your workflows."
        />
        
        <form class="flex flex-wrap mx-0" @submit.prevent="submitAdd">
          <woot-input
            v-model="formData.process_name"
            class="w-full mb-4"
            label="Process Name"
            placeholder="Enter the process name"
            required
          />
          
          <woot-input
            v-model="formData.description"
            class="w-full mb-4"
            input-type="textarea"
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
                placeholder="#6F2CE5"
              />
            </div>
          </div>
          
          <div class="flex items-center w-full gap-2 mb-4">
            <input v-model="formData.default" type="checkbox" id="default_process" />
            <label for="default_process">Set as default type process</label>
          </div>
          
          <div class="flex items-center w-full gap-2 mb-4">
            <input v-model="formData.is_system" type="checkbox" id="is_system" />
            <label for="is_system">System type process</label>
          </div>

          <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
            <woot-button
              :is-disabled="!isFormValid || uiFlags.isCreating"
              :is-loading="uiFlags.isCreating"
              color-scheme="primary"
              type="submit"
            >
              Create Type Process
            </woot-button>
            
            <woot-button 
              class="button clear" 
              @click.prevent="closeAddModal"
            >
              Cancel
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Modal Editar -->
    <woot-modal v-if="showEditModal" :show="showEditModal" :on-close="closeEditModal">
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header 
          :header-title="`Edit Type Process - ${selectedItem.process_name}`"
        />
        
        <form class="flex flex-wrap mx-0" @submit.prevent="submitEdit">
          <woot-input
            v-model="formData.process_name"
            class="w-full mb-4"
            label="Process Name"
            placeholder="Enter the process name"
            required
          />
          
          <!-- <woot-input
            v-model="formData.description"
            class="w-full mb-4"
            input-type="textarea"
            label="Description"
            placeholder="Enter a description (optional)"
          /> -->

          <!-- <div class="w-full mb-4">
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
                placeholder="#6F2CE5"
              />
            </div>
          </div> -->
          
          <div class="flex items-center w-full gap-2 mb-4">
            <input v-model="formData.default" type="checkbox" id="edit_default_process" />
            <label for="edit_default_process">Set as default type process</label>
          </div>
          
          <div class="flex items-center w-full gap-2 mb-4">
            <input 
              v-model="formData.is_system" 
              type="checkbox" 
              id="edit_is_system" 
              :disabled="selectedItem.is_system"
            />
            <label for="edit_is_system">System type process</label>
          </div>

          <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
            <woot-button
              :is-disabled="!isFormValid || uiFlags.isUpdating"
              :is-loading="uiFlags.isUpdating"
              color-scheme="primary"
              type="submit"
            >
              Update Type Process
            </woot-button>
            
            <woot-button 
              class="button clear" 
              @click.prevent="closeEditModal"
            >
              Cancel
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Modal Confirmar Eliminación -->
    <woot-delete-modal
      :show.sync="showDeleteModal"
      :on-close="closeDeleteModal"
      :on-confirm="confirmDelete"
      title="Confirm Deletion"
      message="Are you sure you want to delete this kanban type process?"
      :message-value="deleteMessage"
      confirm-text="Yes, Delete"
      reject-text="Cancel"
    />
  </div>
</template>