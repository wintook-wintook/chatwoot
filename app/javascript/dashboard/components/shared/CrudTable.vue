<script setup>
import { computed } from 'vue';

const props = defineProps({
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

const emit = defineEmits(['edit', 'delete']);

const handleEdit = (record) => {
  emit('edit', record);
};

const handleDelete = (record) => {
  emit('delete', record);
};
</script>

<template>
  <table class="min-w-full overflow-x-auto divide-y divide-slate-75 dark:divide-slate-700">
    <thead>
      <th
        v-for="header in headers"
        :key="header"
        class="py-4 ltr:pr-4 rtl:pl-4 text-left font-semibold text-slate-700 dark:text-slate-300"
      >
        {{ header }}
      </th>
    </thead>
    <tbody class="divide-y divide-slate-25 dark:divide-slate-800 flex-1 text-slate-700 dark:text-slate-100">
      <tr v-for="record in records" :key="record.id">
        <!-- Slot personalizable para cada fila -->
        <slot name="row" :record="record" :index="record.id">
          <!-- Contenido por defecto si no se define el slot -->
          <td v-for="(value, key) in record" :key="key" class="py-4 ltr:pr-4 rtl:pl-4">
            {{ value }}
          </td>
        </slot>
        
        <!-- Columna de acciones siempre al final -->
        <td class="py-4 min-w-xs">
          <div class="flex gap-1">
            <woot-button
              v-if="canEdit(record)"
              v-tooltip.top="editTooltip"
              variant="smooth"
              size="tiny"
              color-scheme="secondary"
              class-names="grey-btn"
              :is-loading="loading[record.id]"
              icon="edit"
              @click="handleEdit(record)"
            />
            <woot-button
              v-if="canDelete(record)"
              v-tooltip.top="deleteTooltip"
              variant="smooth"
              color-scheme="alert"
              size="tiny"
              icon="dismiss-circle"
              class-names="grey-btn"
              :is-loading="loading[record.id]"
              @click="handleDelete(record)"
            />
          </div>
        </td>
      </tr>
    </tbody>
  </table>
</template>