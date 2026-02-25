<!-- 
 Referencia Archivo: Archivo index de kanbanProcesses
 /**
 * index.vue
 *
 * 📌 Título: Gestión de Procesos Kanban por Tipo de Proceso
 *
 * 🎯 Objetivo:
 * Este componente permite a los usuarios visualizar, crear, editar y eliminar procesos específicos
 * dentro de un tipo de proceso Kanban. Sirve como una interfaz administrativa para gestionar
 * los distintos flujos de trabajo asociados a cada tipo Kanban.
 *
 * 🧩 Funcionalidades principales:
 * - Seleccionar un tipo de proceso Kanban para visualizar sus procesos.
 * - Listado dinámico de procesos según el tipo seleccionado.
 * - Crear nuevos procesos con propiedades como nombre, color, posición y si es por defecto o del sistema.
 * - Editar procesos existentes de forma segura y validada.
 * - Eliminar procesos (con restricción para procesos del sistema).
 * - Modal para crear, editar y confirmar eliminación de procesos.
 * - Actualización automática del listado después de cada operación.
 *
 * 🧠 Reactividad y lógica:
 * - Usa `ref`, `computed` y `watch` de Vue 3 para manejar el estado y los datos derivados.
 * - Lógica de negocio desacoplada usando `store.dispatch` para interacción con Vuex.
 * - Validaciones y sincronización del formulario con los datos existentes.
 * - Computed para filtrar y ordenar los procesos según posición y tipo.
 *
 * 🧪 Composables utilizados:
 * - `useStore`, `useStoreGetters`: Acceso al store Vuex centralizado.
 * - `useAlert`: Para mostrar notificaciones al usuario.
 * - `useI18n`: Soporte para traducción de textos.
 *
 * 🛠️ Autor: [Tu nombre o equipo]
 * 📅 Última modificación: [Fecha]
 */
 -->
<script setup>
import { useAlert } from 'dashboard/composables';
import { computed, onBeforeMount, ref, watch } from 'vue';
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
const showDefaultAlert = computed(() => {
  return selectedItem.value.default && selectedItem.value.default !== formData.value.default;
});
const kanbanTypeProcesses = computed(
  () => getters['kanbanTypeProcesses/getKanbanTypeProcesses'].value
);
const kanbanProcesses = computed(
  () => getters['kanbanProcesses/getKanbanProcesses'].value
);
const kanbanProcessesUIFlags = computed(
  () => getters['kanbanProcesses/getUIFlags'].value
);

const filteredKanbanProcesses = computed(() => {
  if (!selectedKanbanTypeProcessId.value) return [];

  const filtered = kanbanProcesses.value
    .filter(
      process =>
        process.kanban_type_process_id === selectedKanbanTypeProcessId.value
    )
    .sort((a, b) => a.position - b.position);

  // ✅ FILTRAR DUPLICADOS POR ID
  const uniqueProcesses = filtered.filter(
    (item, index, self) => index === self.findIndex(t => t.id === item.id)
  );

  return uniqueProcesses;
});

const kanbanTypeOptions = computed(() =>
  kanbanTypeProcesses.value.map(type => ({
    value: type.id,
    label: type.process_name,
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

const deleteMessage = computed(
  () => ` ${selectedItem.value.type_process_name}?`
);
const isFormValid = computed(() => {
  return (
    formData.value.type_process_name &&
    formData.value.type_process_name.length > 0 &&
    typeof formData.value.position === 'number'
  );
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

const canDelete = item => {
  return !item.is_system;
};

const loadKanbanProcesses = async () => {
  if (selectedKanbanTypeProcessId.value) {
    try {
      await store.dispatch('kanbanProcesses/get', {
        kanbanTypeProcessId: selectedKanbanTypeProcessId.value,
      });
    } catch (error) {
      useAlert(t('KANBAN.PROCESSES.ERROR.LOADING'));
    }
  }
};

const handleAdd = () => {
  if (!selectedKanbanTypeProcessId.value) {
    useAlert(t('KANBAN.PROCESSES.SELECT_TYPE_FIRST'));
    return;
  }
  resetForm();
  showAddModal.value = true;
};

const handleEdit = item => {
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

const handleDelete = item => {
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
    useAlert(t('KANBAN.PROCESSES.SUCCESS.CREATED'));
    closeAddModal();
    loadKanbanProcesses();
  } catch (error) {
    useAlert(error?.message || t('KANBAN.PROCESSES.ERROR.CREATING'));
  }
};

const submitEdit = async () => {
  // console.log('🔍 submitEdit called:');
  // console.log('- selectedItem.value:', selectedItem.value);
  // console.log('- selectedKanbanTypeProcessId.value:', selectedKanbanTypeProcessId.value);
  // console.log('- formData.value:', formData.value);
  
  try {
    // Validar que tenemos todos los datos necesarios
    if (!selectedItem.value.id) {
      throw new Error(t('KANBAN.PROCESSES.ERROR.NO_ID'));
    }
    
    if (!selectedKanbanTypeProcessId.value) {
      throw new Error(t('KANBAN.PROCESSES.ERROR.NO_TYPE_SELECTED'));
    }
    
    const updatePayload = {
      kanbanTypeProcessId: selectedKanbanTypeProcessId.value,
      id: selectedItem.value.id,
      ...formData.value,
    };
    
    console.log('🚀 Dispatching update with payload:', updatePayload);
    
    await store.dispatch('kanbanProcesses/update', updatePayload);
    
    useAlert(t('KANBAN.PROCESSES.SUCCESS.UPDATED'));
    closeEditModal();
    await loadKanbanProcesses();
  } catch (error) {
    console.error('❌ submitEdit error:', error);
    useAlert(error?.message || t('KANBAN.PROCESSES.ERROR.UPDATING'));
  }
};

const confirmDelete = async () => {
  loading.value[selectedItem.value.id] = true;
  try {
    await store.dispatch('kanbanProcesses/delete', selectedItem.value.id);
    useAlert(t('KANBAN.PROCESSES.SUCCESS.DELETED'));
    await loadKanbanProcesses();
  } catch (error) {
    useAlert(error?.message || t('KANBAN.PROCESSES.ERROR.DELETING'));
  } finally {
    loading.value[selectedItem.value.id] = false;
    closeDeleteModal();
  }
};

// Watchers
watch(selectedKanbanTypeProcessId, loadKanbanProcesses);
watch(nextPosition, newVal => {
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
  <div class="p-6 max-w-7xl mx-auto">
    <!-- Header -->
    <div class="mb-6">
      <h1 class="text-2xl font-semibold text-slate-900 dark:text-slate-100 mb-2">
        {{ $t('KANBAN.PROCESSES.TITLE') }}
      </h1>
      <p class="text-slate-600 dark:text-slate-400 mb-4">
        {{ $t('KANBAN.PROCESSES.DESCRIPTION') }}
      </p>

      <!-- Selector de Tipo de Proceso -->
      <div class="mb-4">
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
          {{ $t('KANBAN.PROCESSES.SELECT_TYPE') }}
        </label>
        <select
          v-model="selectedKanbanTypeProcessId"
          class="border border-slate-300 dark:border-slate-600 rounded-md px-3 py-2 text-sm bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-300 w-full max-w-md"
        >
          <option value="" disabled>{{ $t('KANBAN.PROCESSES.CHOOSE_TYPE') }}</option>
          <option
            v-for="option in kanbanTypeOptions"
            :key="option.value"
            :value="option.value"
          >
            {{ option.label }}
          </option>
        </select>
      </div>
    </div>

    <!-- Loading State -->
    <div
      v-if="kanbanProcessesUIFlags.isFetching"
      class="flex items-center justify-center py-12"
    >
      <div class="flex items-center space-x-3">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <span class="text-slate-600 dark:text-slate-400">
          {{ $t('KANBAN.COMMON.FETCHING_PROCESSES') }}
        </span>
      </div>
    </div>

    <!-- Estado de selección -->
    <div
      v-else-if="!selectedKanbanTypeProcessId"
      class="bg-slate-50 dark:bg-slate-800 rounded-lg border-2 border-dashed border-slate-300 dark:border-slate-600 p-12 text-center"
    >
      <div class="text-slate-500 dark:text-slate-400">
        <div class="text-4xl mb-4">🔄</div>
        <div class="text-lg font-medium mb-2">{{ $t('KANBAN.PROCESSES.SELECT_MESSAGE') }}</div>
        <div class="text-sm">
          {{ $t('KANBAN.PROCESSES.SELECT_DESCRIPTION') }}
        </div>
      </div>
    </div>

    <!-- Tabla -->
    <div v-else class="w-full">
      <!-- Header con botón agregar -->
      <div class="flex items-center justify-between mb-6">
        <div class="flex-1"></div>
        <woot-button
          class="button nice rounded-md"
          icon="add-circle"
          color-scheme="primary"
          @click="handleAdd"
        >
          {{ $t('KANBAN.PROCESSES.ADD_NEW') }}
        </woot-button>
      </div>

      <!-- Tabla -->
      <div class="bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 overflow-hidden">
        <table class="min-w-full">
          <thead class="bg-slate-50 dark:bg-slate-900">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                {{ $t('KANBAN.COMMON.NAME') }}
              </th>
              <!-- <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                {{ $t('KANBAN.COMMON.DESCRIPTION') }}
              </th> -->
              <!-- <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                {{ $t('KANBAN.COMMON.COLOR') }}
              </th> -->
              <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                {{ $t('KANBAN.COMMON.POSITION') }}
              </th>
              <th class="px-6 py-3 text-right text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                {{ $t('KANBAN.COMMON.ACTIONS') }}
              </th>
            </tr>
          </thead>
          <tbody class="bg-white dark:bg-slate-800 divide-y divide-slate-200 dark:divide-slate-700">
            <tr
              v-for="record in filteredKanbanProcesses"
              :key="record.id"
              class="hover:bg-slate-50 dark:hover:bg-slate-700"
            >
              <!-- Name -->
              <td class="px-6 py-4">
                <div class="text-sm font-medium text-slate-900 dark:text-slate-100">
                  {{ record.type_process_name }}
                </div>
                <div v-if="record.default || record.is_system" class="flex items-center mt-1 space-x-2">
                  <span
                    v-if="record.default"
                    class="px-2 py-0.5 text-xs bg-green-100 text-green-800 rounded dark:bg-green-900 dark:text-green-300"
                  >
                    {{ $t('KANBAN.PROCESSES.DEFAULT') }}
                  </span>
                  <span
                    v-if="record.is_system"
                    class="px-2 py-0.5 text-xs bg-blue-100 text-blue-800 rounded dark:bg-blue-900 dark:text-blue-300"
                  >
                    {{ $t('KANBAN.PROCESSES.SYSTEM') }}
                  </span>
                </div>
              </td>

              <!-- Description -->
              <!-- <td class="px-6 py-4">
                <div class="text-sm text-slate-600 dark:text-slate-400">
                  {{ record.description || `Position: ${record.position}` }}
                </div>
              </td> -->

              <!-- Color -->
              <!-- <td class="px-6 py-4">
                <div class="flex items-center">
                  <div
                    class="w-4 h-4 rounded border border-slate-300 dark:border-slate-600 mr-2"
                    :style="{ backgroundColor: record.color || '#3B82F6' }"
                  ></div>
                  <span class="text-sm font-mono text-slate-600 dark:text-slate-400">
                    {{ record.color || '#3B82F6' }}
                  </span>
                </div>
              </td> -->

              <!-- Position -->
              <td class="px-6 py-4">
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-slate-100 text-slate-800 dark:bg-slate-700 dark:text-slate-200">
                  {{ record.position }}
                </span>
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
                    v-tooltip.top="$t('KANBAN.PROCESSES.EDIT')"
                  />
                  <woot-button
                    v-if="canDelete(record)"
                    variant="smooth"
                    size="tiny"
                    color-scheme="alert"
                    icon="dismiss-circle"
                    :is-loading="loading[record.id]"
                    @click="handleDelete(record)"
                    v-tooltip.top="$t('KANBAN.PROCESSES.DELETE')"
                  />
                </div>
              </td>
            </tr>

            <!-- Empty state -->
            <tr v-if="filteredKanbanProcesses.length === 0">
              <td colspan="5" class="px-6 py-12 text-center">
                <div class="text-slate-500 dark:text-slate-400">
                  <div class="text-4xl mb-2">📋</div>
                  <div class="text-sm">
                    {{ $t('KANBAN.PROCESSES.NO_RECORDS') }}
                  </div>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Modal Agregar -->
    <woot-modal
      v-if="showAddModal"
      :show="showAddModal"
      :on-close="closeAddModal"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="$t('KANBAN.PROCESSES.ADD.TITLE')"
          :header-content="$t('KANBAN.PROCESSES.ADD.DESC')"
        />

        <form class="flex flex-wrap mx-0" @submit.prevent="submitAdd">
          <woot-input
            v-model="formData.type_process_name"
            class="w-full mb-4"
            :label="$t('KANBAN.PROCESSES.FORM.PROCESS_NAME.LABEL')"
            :placeholder="$t('KANBAN.PROCESSES.FORM.PROCESS_NAME.PLACEHOLDER')"
            required
          />

          <!-- <woot-input
            v-model="formData.description"
            class="w-full mb-4"
            input-type="textarea"
            :label="$t('KANBAN.PROCESSES.FORM.DESCRIPTION.LABEL')"
            :placeholder="$t('KANBAN.PROCESSES.FORM.DESCRIPTION.PLACEHOLDER')"
          />

          <div class="w-full mb-4">
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
              {{ $t('KANBAN.PROCESSES.FORM.COLOR.LABEL') }}
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
          </div> -->

          <woot-input
            v-model.number="formData.position"
            class="w-full mb-4"
            type="number"
            :label="$t('KANBAN.PROCESSES.FORM.POSITION.LABEL')"
            :placeholder="$t('KANBAN.PROCESSES.FORM.POSITION.PLACEHOLDER')"
            :min="0"
            required
          />

          <div class="flex items-center w-full gap-2 mb-4">
            <input
              v-model="formData.default"
              type="checkbox"
              id="default_process"
            />
            <label for="default_process">{{ $t('KANBAN.PROCESSES.FORM.DEFAULT_PROCESS') }}</label>
          </div>

          <!-- <div class="flex items-center w-full gap-2 mb-4">
            <input
              v-model="formData.is_system"
              type="checkbox"
              id="is_system"
            />
            <label for="is_system">{{ $t('KANBAN.PROCESSES.FORM.SYSTEM_PROCESS') }}</label>
          </div> -->

          <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
            <woot-button
              :is-disabled="!isFormValid || kanbanProcessesUIFlags.isCreating"
              :is-loading="kanbanProcessesUIFlags.isCreating"
              color-scheme="primary"
              type="submit"
            >
              {{ $t('KANBAN.PROCESSES.FORM.CREATE') }}
            </woot-button>

            <woot-button class="button clear" @click.prevent="closeAddModal">
              {{ $t('KANBAN.PROCESSES.FORM.CANCEL') }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Modal Editar -->
    <woot-modal
      v-if="showEditModal"
      :show="showEditModal"
      :on-close="closeEditModal"
    >
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header
          :header-title="`${$t('KANBAN.PROCESSES.EDITETAPA.TITLE')} - ${selectedItem.type_process_name}`"
        />

        <form class="flex flex-wrap mx-0" @submit.prevent="submitEdit">
          <woot-input
            v-model="formData.type_process_name"
            class="w-full mb-4"
            :label="$t('KANBAN.PROCESSES.FORM.PROCESS_NAME.LABEL')"
            :placeholder="$t('KANBAN.PROCESSES.FORM.PROCESS_NAME.PLACEHOLDER')"
            required
          />

          <!-- <woot-input
            v-model="formData.description"
            class="w-full mb-4"
            input-type="textarea"
            :label="$t('KANBAN.PROCESSES.FORM.DESCRIPTION.LABEL')"
            :placeholder="$t('KANBAN.PROCESSES.FORM.DESCRIPTION.PLACEHOLDER')"
          /> -->

          <!-- <div class="w-full mb-4">
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
              {{ $t('KANBAN.PROCESSES.FORM.COLOR.LABEL') }}
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
          </div> -->

          <woot-input
            v-model.number="formData.position"
            class="w-full mb-4"
            type="number"
            :label="$t('KANBAN.PROCESSES.FORM.POSITION.LABEL')"
            :placeholder="$t('KANBAN.PROCESSES.FORM.POSITION.PLACEHOLDER')"
            :min="0"
            required
          />

          <div class="flex items-center w-full gap-2 mb-4">
            <input
              v-model="formData.default"
              type="checkbox"
              id="edit_default_process"
            />
            <label for="edit_default_process">{{ $t('KANBAN.PROCESSES.FORM.DEFAULT_PROCESS') }}</label>
          </div>

          <!-- <div class="flex items-center w-full gap-2 mb-4">
            <input
              v-model="formData.is_system"
              type="checkbox"
              id="edit_is_system"
              :disabled="selectedItem.is_system"
            />
            <label for="edit_is_system">{{ $t('KANBAN.PROCESSES.FORM.SYSTEM_PROCESS') }}</label>
          </div> -->

          <!-- <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
            <woot-button
              :is-disabled="!isFormValid || kanbanProcessesUIFlags.isUpdating"
              :is-loading="kanbanProcessesUIFlags.isUpdating"
              color-scheme="primary"
              type="submit"
            >
              {{ $t('KANBAN.PROCESSES.FORM.UPDATE') }}
            </woot-button> -->


          <div v-if="showDefaultAlert"
            class="flex items-center w-full gap-2 mb-4 text-sm text-amber-600 dark:text-amber-400 bg-amber-50 dark:bg-amber-900/20 px-3 py-2 rounded border border-amber-200 dark:border-amber-800">
            ⚠️ No se puede modificar el estado por defecto de esta etapa de oportunidad.
          </div>

          <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
            <woot-button :is-disabled="!isFormValid ||
              kanbanProcessesUIFlags.isUpdating ||
              (selectedItem.default && selectedItem.default !== formData.default)"
              :is-loading="kanbanProcessesUIFlags.isUpdating" color-scheme="primary" type="submit">
              {{ $t('KANBAN.PROCESSES.FORM.UPDATE') }}
            </woot-button>

            <woot-button class="button clear" @click.prevent="closeEditModal">
              {{ $t('KANBAN.PROCESSES.FORM.CANCEL') }}
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
      :title="$t('KANBAN.COMMON.CONFIRM_DELETION')"
      :message="$t('KANBAN.PROCESSES.CONFIRM_DELETE')"
      :message-value="deleteMessage"
      :confirm-text="$t('KANBAN.COMMON.YES_DELETE')"
      :reject-text="$t('KANBAN.COMMON.NO_CANCEL')"
    />
  </div>
</template>