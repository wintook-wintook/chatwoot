<script setup>
// KANBAN0725
import { computed } from 'vue';

const props = defineProps({
  records: {
    type: Array,
    required: true,
  },
  loading: {
    type: Object,
    default: () => ({}),
  },
  canEdit: {
    type: Function,
    default: () => true,
  },
  canDelete: {
    type: Function,
    default: () => true,
  },
  showColor: {
    type: Boolean,
    default: true,
  },
  showDescription: {
    type: Boolean,
    default: true,
  },
  // Mapeo de campos para flexibilidad
  nameField: {
    type: String,
    default: 'name',
  },
  descriptionField: {
    type: String,
    default: 'description',
  },
  colorField: {
    type: String,
    default: 'color',
  },
});

const emit = defineEmits(['add', 'edit', 'delete']);

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
  <div class="w-full">
    <!-- Header con botón agregar -->
    <div class="flex items-center justify-between mb-6">
      <div class="flex-1"></div>
      <woot-button
        class="button nice rounded-md"
        icon="add-circle"
        color-scheme="primary"
        @click="handleAdd"
      >
        Add Item
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
            <th v-if="showDescription" class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              Description
            </th>
            <th v-if="showColor" class="px-6 py-3 text-left text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              Color
            </th>
            <th class="px-6 py-3 text-right text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              Actions
            </th>
          </tr>
        </thead>
        <tbody class="bg-white dark:bg-slate-800 divide-y divide-slate-200 dark:divide-slate-700">
          <tr v-for="record in records" :key="record.id" class="hover:bg-slate-50 dark:hover:bg-slate-700">
            <!-- Name -->
            <td class="px-6 py-4">
              <div class="text-sm font-medium text-slate-900 dark:text-slate-100">
                {{ record[nameField] }}
              </div>
            </td>
            
            <!-- Description -->
            <td v-if="showDescription" class="px-6 py-4">
              <div class="text-sm text-slate-600 dark:text-slate-400">
                {{ record[descriptionField] || '-' }}
              </div>
            </td>
            
            <!-- Color -->
            <td v-if="showColor" class="px-6 py-4">
              <div class="flex items-center">
                <div
                  class="w-4 h-4 rounded border border-slate-300 dark:border-slate-600 mr-2"
                  :style="{ backgroundColor: record[colorField] || '#6B7280' }"
                ></div>
                <span class="text-sm font-mono text-slate-600 dark:text-slate-400">
                  {{ record[colorField] || '#6B7280' }}
                </span>
              </div>
            </td>
            
            <!-- Actions -->
            <td class="px-6 py-4 text-right text-sm font-medium">
              <div class="flex items-center justify-end space-x-2">
                <woot-button
                  v-if="canEdit(record)"
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
          <tr v-if="records.length === 0">
            <td :colspan="3 + (showDescription ? 1 : 0) + (showColor ? 1 : 0)" class="px-6 py-12 text-center">
              <div class="text-slate-500 dark:text-slate-400">
                <div class="text-4xl mb-2">📋</div>
                <div class="text-sm">No items found</div>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>