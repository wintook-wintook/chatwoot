<script>
// feat/ficha_agente_ia — EL MENÚ DE RECURSOS
// Una sección a la vez: Datos del agente · Fuentes de datos · Agenda · Tickets · Archivos.
// Cada una con su contador (o ✓ / ! en Datos del agente).
export default {
  model: { prop: 'value', event: 'input' },
  props: {
    // [{ id, icon, label, count, total, state: 'ok' | 'todo' | null }]
    items: { type: Array, default: () => [] },
    value: { type: String, default: '' },
  },
  emits: ['input'],
};
</script>

<template>
  <nav
    class="flex flex-row gap-1 overflow-x-auto md:flex-col md:overflow-visible"
  >
    <button
      v-for="item in items"
      :key="item.id"
      type="button"
      class="flex items-center gap-2 px-3 py-2 text-sm text-left rounded-lg shrink-0"
      :class="
        value === item.id
          ? 'bg-woot-50 text-woot-700 font-medium dark:bg-woot-800 dark:text-woot-50'
          : 'text-slate-600 hover:bg-slate-50 dark:text-slate-300 dark:hover:bg-slate-800'
      "
      :data-section="item.id"
      @click="$emit('input', item.id)"
    >
      <fluent-icon :icon="item.icon" size="16" class="shrink-0" />
      <span class="flex-1 truncate">{{ item.label }}</span>
      <fluent-icon
        v-if="item.state === 'todo'"
        icon="warning"
        size="14"
        class="text-amber-600"
      />
      <fluent-icon
        v-else-if="item.state === 'ok'"
        icon="checkmark-circle"
        size="14"
        class="text-green-600"
      />
      <span
        v-else-if="item.total"
        class="px-1.5 text-xs rounded-full"
        :class="
          item.count
            ? 'bg-woot-500 text-white'
            : 'bg-slate-100 text-slate-500 dark:bg-slate-700'
        "
      >
        {{ item.count }}/{{ item.total }}
      </span>
    </button>
  </nav>
</template>
