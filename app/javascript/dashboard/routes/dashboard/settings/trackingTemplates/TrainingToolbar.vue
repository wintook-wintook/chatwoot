<script>
// proyecto@asistente_agentes_ia — Entrenamiento por secciones
// La barra arriba del Entrenamiento: vista Secciones o Texto, y lo que dice el
// comprobador. Aparte de EditTemplate.vue para no sumarle marcado a esa pantalla.
export default {
  props: {
    view: { type: String, default: 'sections' },
    validation: { type: Object, default: null },
  },
  emits: ['switch'],
  computed: {
    blocking() {
      return this.validation?.blocking || [];
    },
    degrading() {
      return this.validation?.degrading || [];
    },
    summary() {
      return {
        routes: this.validation?.routes?.length || 0,
        blocking: this.blocking.length,
        degrading: this.degrading.length,
      };
    },
    summaryClass() {
      if (this.blocking.length) return 'text-red-600 dark:text-red-400';
      if (this.degrading.length) return 'text-amber-700 dark:text-amber-300';
      return 'text-green-700 dark:text-green-400';
    },
  },
  methods: {
    viewClass(vista) {
      return this.view === vista
        ? 'bg-woot-500 text-white'
        : 'text-slate-600 dark:text-slate-300';
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2 mb-2">
    <div class="flex flex-wrap items-center justify-between gap-2">
      <div
        class="flex overflow-hidden text-xs border rounded-md border-slate-200 dark:border-slate-600"
      >
        <button
          type="button"
          class="px-3 py-1"
          :class="viewClass('sections')"
          @click="$emit('switch', 'sections')"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.VIEW_SECTIONS') }}
        </button>
        <button
          type="button"
          class="px-3 py-1"
          :class="viewClass('text')"
          @click="$emit('switch', 'text')"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.VIEW_TEXT') }}
        </button>
      </div>
      <span v-if="validation" class="text-xs" :class="summaryClass">
        {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.CHECK', summary) }}
      </span>
    </div>
    <ul
      v-if="blocking.length || degrading.length"
      class="!m-0 flex flex-col gap-1 list-none"
    >
      <li
        v-for="(hallazgo, i) in blocking"
        :key="`b${i}`"
        class="px-2 py-1 text-xs text-red-800 rounded bg-red-50 dark:bg-red-900/30 dark:text-red-200"
      >
        {{ hallazgo.message }}
      </li>
      <li
        v-for="(hallazgo, i) in degrading"
        :key="`d${i}`"
        class="px-2 py-1 text-xs rounded text-amber-800 bg-amber-50 dark:bg-amber-900/30 dark:text-amber-200"
      >
        {{ hallazgo.message }}
      </li>
    </ul>
  </div>
</template>
