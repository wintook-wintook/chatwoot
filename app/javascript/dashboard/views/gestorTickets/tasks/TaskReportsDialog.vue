<!-- Reporte de cierre — los reportes de una tarea: uno por cada vez que se concluyó. -->
<script>
import TaskReportsList from './TaskReportsList.vue';

export default {
  name: 'TaskReportsDialog',
  components: { TaskReportsList },
  props: {
    filters: { type: Object, default: null },
  },
  emits: ['close'],
};
</script>

<template>
  <woot-modal :show="!!filters" :on-close="() => $emit('close')">
    <woot-modal-header :header-title="$t('TASK_REPORT.VIEW')" />
    <div class="px-6 pb-6">
      <TaskReportsList v-if="filters" :filters="filters" />
    </div>
  </woot-modal>
</template>
