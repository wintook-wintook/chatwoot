<!--
  El robot del agente en la lista y el tablero de casos (helper/caseAgent):
  morado = contestando, ámbar = en pausa, gris tachado = sin agente.
  El detalle (qué agente, objetivo, intentos) va en el título al pasar el mouse.
-->
<script>
import { agentView } from 'dashboard/helper/caseAgent';

export default {
  name: 'CaseAgentIcon',
  props: {
    agent: { type: Object, default: null },
    size: { type: [String, Number], default: 14 },
    // En un botón que ya dice qué es (el filtro): sin título propio.
    decorative: { type: Boolean, default: false },
  },
  computed: {
    view() {
      return agentView(this.agent, this.$t.bind(this));
    },
  },
};
</script>

<template>
  <span
    v-if="view"
    class="relative inline-flex items-center justify-center shrink-0"
    :class="view.cls"
    :title="decorative ? null : view.title"
    :aria-label="decorative ? null : view.title"
    :aria-hidden="decorative ? 'true' : null"
    :role="decorative ? null : 'img'"
  >
    <fluent-icon icon="bot" :size="size" />
    <!-- Sin agente: una diagonal encima del robot -->
    <span
      v-if="view.crossed"
      class="absolute h-px bg-current w-[130%] rotate-[-45deg]"
    />
  </span>
</template>
