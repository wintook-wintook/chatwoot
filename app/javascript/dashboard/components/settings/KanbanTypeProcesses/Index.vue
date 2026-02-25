<!--
/**
 * index.vue
 *
 * 📌 Título: Gestión de Tipos de Kanban
 *
 * 🎯 Objetivo:
 * Este componente permite visualizar, crear, editar y eliminar los **Tipos de Kanban** 
 * que definen las categorías principales de organización dentro del tablero Kanban. 
 * Es la base para agrupar y clasificar procesos en flujos de trabajo.
 *
 * 🧩 Funcionalidades principales:
 * - Mostrar todos los Tipos de Kanban existentes en una tabla ordenada.
 * - Agregar nuevos tipos de proceso con nombre, descripción, color, y banderas de sistema/por defecto.
 * - Editar los atributos de un tipo de proceso existente.
 * - Eliminar tipos de proceso no marcados como "de sistema".
 * - Indicadores visuales de carga y validación de formularios.
 * - Modal de confirmación antes de eliminar un registro.
 * - Recarga automática de datos tras operaciones CRUD.
 *
 * 🧠 Reactividad y lógica:
 * - Usa `ref`, `computed` y `onBeforeMount` de Vue 3 Composition API.
 * - Lógica separada para formularios y estado de modales.
 * - Validación de formularios antes de permitir creación o actualización.
 * - Carga de datos al montar el componente con control de `isDataLoaded`.
 *
 * 🧪 Composables utilizados:
 * - `useStore`, `useStoreGetters`: Acceso centralizado al store Vuex.
 * - `useAlert`: Para mostrar notificaciones al usuario.
 * - `useI18n`: Para traducciones si es necesario.
 *
 * 🛠️ Autor: [Tu nombre o equipo]
 * 📅 Última modificación: [Fecha]
 */
-->
<script setup>
import { useAlert } from 'dashboard/composables';
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

// Estado del componente
const loading = ref({});
const showAddModal = ref(false);
const showEditModal = ref(false);
const showDeleteModal = ref(false);
const selectedItem = ref({});
const isDataLoaded = ref(false);

// Datos del formulario
const formData = ref({
  process_name: '',
  description: '',
  color: '#6F2CE5',
  default: false,
  is_system: false,
});

// Computed
const records = computed(() => {
  const typeProcesses = getters['kanbanTypeProcesses/getKanbanTypeProcesses'].value;
  console.log('🔄 Computing records:', typeProcesses.length, 'items');
  
  // ✅ FILTRAR DUPLICADOS POR ID
  const uniqueProcesses = typeProcesses.filter((item, index, self) => 
    index === self.findIndex(t => t.id === item.id)
  );
  
  console.log('✅ Unique records:', uniqueProcesses.length, 'items');
  
  // Mapear los datos para que coincidan con la estructura de la tabla
  return uniqueProcesses.map(item => ({
    ...item,
    name: item.process_name,
    description: item.description || t('KANBAN.COMMON.NO_DESCRIPTION'),
    color: item.color || '#6F2CE5',
  }));
});

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
    await store.dispatch('kanbanTypeProcesses/create', formData.value);
    useAlert(t('KANBAN.TYPE_PROCESSES.SUCCESS.CREATED'));
    // ✅ Recargar datos después de crear
    await store.dispatch('kanbanTypeProcesses/get');
    closeAddModal();
  } catch (error) {
    useAlert(error?.message || t('KANBAN.TYPE_PROCESSES.ERROR.CREATING'));
  }
};

const submitEdit = async () => {
  try {
    await store.dispatch('kanbanTypeProcesses/update', {
      id: selectedItem.value.id,
      ...formData.value,
    });
    useAlert(t('KANBAN.TYPE_PROCESSES.SUCCESS.UPDATED'));
    await store.dispatch('kanbanTypeProcesses/get');
    closeEditModal();
  } catch (error) {
    useAlert(error?.message || t('KANBAN.TYPE_PROCESSES.ERROR.UPDATING'));
  }
};

const confirmDelete = async () => {
  loading.value[selectedItem.value.id] = true;
  try {
    await store.dispatch('kanbanTypeProcesses/delete', selectedItem.value.id);
    useAlert(t('KANBAN.TYPE_PROCESSES.SUCCESS.DELETED'));
  } catch (error) {
    useAlert(error?.message || t('KANBAN.TYPE_PROCESSES.ERROR.DELETING'));
  } finally {
    loading.value[selectedItem.value.id] = false;
    await store.dispatch('kanbanTypeProcesses/get');
    closeDeleteModal();
  }
};

onBeforeMount(async () => {
  console.log('🔄 KanbanTypeProcesses - Component mounting...');
  
  if (!isDataLoaded.value) {
    console.log('🔄 Loading kanban type processes for first time...');
    try {
      console.log('📡 Calling store dispatch...');
      await store.dispatch('kanbanTypeProcesses/get');
      console.log('✅ Store dispatch completed');
      isDataLoaded.value = true;
      console.log('✅ Data loaded successfully');
    } catch (error) {
      console.error('❌ Error loading data:', error);
    }
  } else {
    console.log('⏭️ Data already loaded, skipping...');
  }
  
  console.log('📊 Current records:', records.value);
  console.log('🎛️ Current uiFlags:', uiFlags.value);
});
</script>

<template>
  <div class="p-6 max-w-7xl mx-auto">
    <!-- Header -->
    <div class="mb-6">
      <h1 class="text-2xl font-semibold text-slate-900 dark:text-slate-100 mb-2">
        {{ $t('KANBAN.TYPE_PROCESSES.TITLE') }}
      </h1>
      <p class="text-slate-600 dark:text-slate-400">
        {{ $t('KANBAN.TYPE_PROCESSES.DESCRIPTION') }}
      </p>
    </div>

    <!-- Loading State -->
    <div v-if="uiFlags.isFetching" class="flex items-center justify-center py-12">
      <div class="flex items-center space-x-3">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <span class="text-slate-600 dark:text-slate-400">
          {{ $t('KANBAN.COMMON.FETCHING_TYPE_PROCESSES') }}
        </span>
      </div>
    </div>

    <!-- Contenido principal -->
    <div class="w-full">
      <!-- Header con botón agregar -->
      <div class="flex items-center justify-between mb-6">
        <div class="flex-1"></div>
        <woot-button class="button nice rounded-md" icon="add-circle" color-scheme="primary" @click="handleAdd">
          {{ $t('KANBAN.TYPE_PROCESSES.ADD_NEW') }}
        </woot-button>
      </div>

      <!-- Tabla -->
      <div class="bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 overflow-hidden">
        <table class="min-w-full">
          <thead class="bg-slate-50 dark:bg-slate-900">
            <tr>
              <th
                class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                {{ $t('KANBAN.COMMON.NAME') }}
              </th>
              <!-- <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                {{ $t('KANBAN.COMMON.DESCRIPTION') }}
              </th> -->
              <!-- <th
                class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                {{ $t('KANBAN.COMMON.COLOR') }}
              </th> -->
              <th
                class="px-6 py-3 text-right text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                {{ $t('KANBAN.COMMON.ACTIONS') }}
              </th>
            </tr>
          </thead>
          <tbody class="bg-white dark:bg-slate-800 divide-y divide-slate-200 dark:divide-slate-700">
            <tr v-for="record in records" :key="record.id" class="hover:bg-slate-50 dark:hover:bg-slate-700">
              <!-- Name -->
              <td class="px-6 py-4">
                <div class="text-sm font-medium text-slate-900 dark:text-slate-100">
                  {{ record.process_name }}
                </div>
                <div v-if="record.default || record.is_system" class="flex items-center mt-1 space-x-2">
                  <span v-if="record.default"
                    class="px-2 py-0.5 text-xs bg-green-100 text-green-800 rounded dark:bg-green-900 dark:text-green-300">
                    {{ $t('KANBAN.TYPE_PROCESSES.DEFAULT') }}
                  </span>
                  <span v-if="record.is_system"
                    class="px-2 py-0.5 text-xs bg-blue-100 text-blue-800 rounded dark:bg-blue-900 dark:text-blue-300">
                    {{ $t('KANBAN.TYPE_PROCESSES.SYSTEM') }}
                  </span>
                </div>
              </td>

              <!-- Description -->
              <!-- <td class="px-6 py-4">
                <div class="text-sm text-slate-600 dark:text-slate-400">
                  {{ record.description || '-' }}
                </div>
              </td> -->

              <!-- Color -->
              <!-- <td class="px-6 py-4">
                <div class="flex items-center">
                  <div class="w-4 h-4 rounded border border-slate-300 dark:border-slate-600 mr-2"
                    :style="{ backgroundColor: record.color || '#6F2CE5' }"></div>
                  <span class="text-sm font-mono text-slate-600 dark:text-slate-400">
                    {{ record.color || '#6F2CE5' }}
                  </span>
                </div>
              </td> -->

              <!-- Actions -->
              <td class="px-6 py-4 text-right text-sm font-medium">
                <div class="flex items-center justify-end space-x-2">
                  <woot-button variant="smooth" size="tiny" color-scheme="secondary" icon="edit"
                    :is-loading="loading[record.id]" @click="handleEdit(record)"
                    v-tooltip.top="$t('KANBAN.TYPE_PROCESSES.EDIT')" />
                  <woot-button v-if="canDelete(record)" variant="smooth" size="tiny" color-scheme="alert"
                    icon="dismiss-circle" :is-loading="loading[record.id]" @click="handleDelete(record)"
                    v-tooltip.top="$t('KANBAN.TYPE_PROCESSES.DELETE')" />
                </div>
              </td>
            </tr>

            <!-- Empty state -->
            <tr v-if="records.length === 0">
              <td colspan="4" class="px-6 py-12 text-center">
                <div class="text-slate-500 dark:text-slate-400">
                  <div class="text-4xl mb-2">📋</div>
                  <div class="text-sm">{{ $t('KANBAN.TYPE_PROCESSES.NO_RECORDS') }}</div>
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
        <woot-modal-header :header-title="$t('KANBAN.TYPE_PROCESSES.ADD.TITLE2')"
          :header-content="$t('KANBAN.TYPE_PROCESSES.ADD.DESC2')" />

        <form class="flex flex-wrap mx-0" @submit.prevent="submitAdd">
          <woot-input v-model="formData.process_name" class="w-full mb-4"
            :label="$t('KANBAN.TYPE_PROCESSES.FORM.PROCESS_NAME.LABEL')"
            :placeholder="$t('KANBAN.TYPE_PROCESSES.FORM.PROCESS_NAME.PLACEHOLDER')" required />

          <!-- <woot-input
            v-model="formData.description"
            class="w-full mb-4"
            input-type="textarea"
            :label="$t('KANBAN.TYPE_PROCESSES.FORM.DESCRIPTION.LABEL')"
            :placeholder="$t('KANBAN.TYPE_PROCESSES.FORM.DESCRIPTION.PLACEHOLDER')"
          />

          <div class="w-full mb-4">
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
              {{ $t('KANBAN.TYPE_PROCESSES.FORM.COLOR.LABEL') }}
            </label>
            <div class="flex items-center space-x-3">
              <input v-model="formData.color" type="color"
                class="w-12 h-10 border border-slate-300 dark:border-slate-600 rounded-md cursor-pointer" />
              <input v-model="formData.color" type="text"
                class="flex-1 border border-slate-300 dark:border-slate-600 rounded-md px-3 py-2 text-sm bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-300"
                placeholder="#6F2CE5" />
            </div>
          </div> -->

          <div class="flex items-center w-full gap-2 mb-4">
            <input v-model="formData.default" type="checkbox" id="default_process" />
            <label for="default_process">{{ $t('KANBAN.TYPE_PROCESSES.FORM.DEFAULT_PROCESS') }}</label>
          </div>

          <!-- <div class="flex items-center w-full gap-2 mb-4">
            <input v-model="formData.is_system" type="checkbox" id="is_system" />
            <label for="is_system">{{ $t('KANBAN.TYPE_PROCESSES.FORM.SYSTEM_PROCESS') }}</label>
          </div> -->

          <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
            <woot-button :is-disabled="!isFormValid || uiFlags.isCreating" :is-loading="uiFlags.isCreating"
              color-scheme="primary" type="submit">
              {{ $t('KANBAN.TYPE_PROCESSES.FORM.CREATE') }}
            </woot-button>

            <woot-button class="button clear" @click.prevent="closeAddModal">
              {{ $t('KANBAN.TYPE_PROCESSES.FORM.CANCEL') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Modal Editar -->
    <woot-modal v-if="showEditModal" :show="showEditModal" :on-close="closeEditModal">
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header :header-title="`${$t('KANBAN.TYPE_PROCESSES.EDITETAPA.TITLE')} - ${selectedItem.process_name}`" />

        <form class="flex flex-wrap mx-0" @submit.prevent="submitEdit">
          <woot-input v-model="formData.process_name" class="w-full mb-4"
            :label="$t('KANBAN.TYPE_PROCESSES.FORM.PROCESS_NAME.LABEL')"
            :placeholder="$t('KANBAN.TYPE_PROCESSES.FORM.PROCESS_NAME.PLACEHOLDER')" required />

          <!-- <woot-input v-model="formData.description" class="w-full mb-4" input-type="textarea"
            :label="$t('KANBAN.TYPE_PROCESSES.FORM.DESCRIPTION.LABEL')"
            :placeholder="$t('KANBAN.TYPE_PROCESSES.FORM.DESCRIPTION.PLACEHOLDER')" /> -->
<!-- 
          <div class="w-full mb-4">
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
              {{ $t('KANBAN.TYPE_PROCESSES.FORM.COLOR.LABEL') }}
            </label>
            <div class="flex items-center space-x-3">
              <input v-model="formData.color" type="color"
                class="w-12 h-10 border border-slate-300 dark:border-slate-600 rounded-md cursor-pointer" />
              <input v-model="formData.color" type="text"
                class="flex-1 border border-slate-300 dark:border-slate-600 rounded-md px-3 py-2 text-sm bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-300"
                placeholder="#6F2CE5" />
            </div>
          </div> -->

          <div class="flex items-center w-full gap-2 mb-4">
            <input v-model="formData.default" type="checkbox" id="edit_default_process" />
            <label for="edit_default_process">{{ $t('KANBAN.TYPE_PROCESSES.FORM.DEFAULT_PROCESS') }}</label>
          </div>

          <!-- <div class="flex items-center w-full gap-2 mb-4">
            <input v-model="formData.is_system" type="checkbox" id="edit_is_system"
              :disabled="selectedItem.is_system" />
            <label for="edit_is_system">{{ $t('KANBAN.TYPE_PROCESSES.FORM.SYSTEM_PROCESS') }}</label>
          </div> -->

          <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
            <woot-button :is-disabled="!isFormValid || uiFlags.isUpdating" :is-loading="uiFlags.isUpdating"
              color-scheme="primary" type="submit">
              {{ $t('KANBAN.TYPE_PROCESSES.FORM.UPDATE') }}
            </woot-button>

            <woot-button class="button clear" @click.prevent="closeEditModal">
              {{ $t('KANBAN.TYPE_PROCESSES.FORM.CANCEL') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Modal Confirmar Eliminación -->
    <woot-delete-modal :show.sync="showDeleteModal" :on-close="closeDeleteModal" :on-confirm="confirmDelete"
      :title="$t('KANBAN.COMMON.CONFIRM_DELETION')" :message="$t('KANBAN.TYPE_PROCESSES.CONFIRM_DELETE')"
      :message-value="deleteMessage" :confirm-text="$t('KANBAN.COMMON.YES_DELETE')"
      :reject-text="$t('KANBAN.COMMON.NO_CANCEL')" />
  </div>
</template>