<script>
// proyecto@asistente_agentes_ia — ENCABEZADO QUE ORDENA
// ============================================================================
// Un <th> que ordena al tocarlo, con la flecha del sentido activo. Existe como
// componente porque las dos tablas del Asistente tienen trece columnas
// ordenables entre las dos: repetir el botón, la flecha y el estado activo trece
// veces es donde una queda sin flecha y nadie lo nota.
//
// El estado del orden NO vive acá: lo tiene la tabla. Un encabezado que recuerde
// su propio orden puede contradecir a los otros —dos flechas activas a la vez—,
// y el orden es uno solo por tabla.
// ============================================================================
export default {
  props: {
    label: { type: String, required: true },
    // Campo por el que ordena. Tiene que estar declarado en el mapa de columnas
    // de la tabla (ver tableSort.js) o no va a ordenar nada.
    sortKey: { type: String, required: true },
    // El orden vigente de la tabla: { key, order }.
    sort: { type: Object, default: null },
    alignRight: { type: Boolean, default: false },
  },
  emits: ['sort'],
  computed: {
    isActive() {
      return this.sort?.key === this.sortKey;
    },
    icon() {
      if (!this.isActive) return null;

      return this.sort.order === 'asc' ? 'chevron-up' : 'chevron-down';
    },
  },
};
</script>

<template>
  <th class="p-0 font-normal">
    <button
      class="flex items-center w-full gap-1 p-3 text-xs font-medium rounded-none cursor-pointer"
      :class="[
        alignRight ? 'justify-end' : 'justify-start',
        isActive
          ? 'text-slate-700 dark:text-slate-200'
          : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200',
      ]"
      @click="$emit('sort', sortKey)"
    >
      {{ label }}
      <fluent-icon v-if="icon" :icon="icon" size="12" class="shrink-0" />
    </button>
  </th>
</template>
