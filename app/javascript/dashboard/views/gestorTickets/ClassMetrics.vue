<!--
  @tickets_cases — Plan-Casos E1 (F6)
  «Métricas» por clase: cada clase tiene las suyas (Soporte: SLA, resolución,
  CSAT; Comercial: embudo; Orden de trabajo: cumplimiento, horas y retrabajos;
  Proyecto: salud contra el plan, horas contra presupuesto y entregas).
  Una entrada más aquí por cada clase nueva.
-->
<script>
import Metrics from './Metrics.vue';
import CommercialMetrics from './commercial/CommercialMetrics.vue';
import WorkOrderMetrics from './workOrder/WorkOrderMetrics.vue'; // Plan-Clase-Orden-de-Trabajo F3
import ProjectMetrics from './project/ProjectMetrics.vue'; // Plan-Clase-Proyecto P3

export default {
  name: 'ClassMetrics',
  components: { Metrics, CommercialMetrics, WorkOrderMetrics, ProjectMetrics },
  props: {
    caseClass: { type: String, required: true },
  },
};
</script>

<template>
  <CommercialMetrics
    v-if="caseClass === 'commercial'"
    :case-class="caseClass"
  />
  <WorkOrderMetrics
    v-else-if="caseClass === 'work_order'"
    :case-class="caseClass"
  />
  <ProjectMetrics v-else-if="caseClass === 'project'" :case-class="caseClass" />
  <Metrics v-else :case-class="caseClass" />
</template>
