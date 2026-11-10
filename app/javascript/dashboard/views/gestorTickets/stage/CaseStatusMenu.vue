<!--
  Botón «Cambiar estado ▾» del caso (cabecera y pestaña Avance usan el mismo).
  En una oportunidad suma Posponer/Retomar y Cancelar arriba; debajo, las etapas o
  estados a los que puede pasar (`options` = validTransitions del detalle) y cuál es
  la actual. Solo avisa qué eligió: el detalle hace el movimiento con su flujo de
  siempre (cierre, resultado, fecha, tareas pendientes).
-->
<script>
export default {
  name: 'CaseStatusMenu',
  props: {
    options: { type: Array, default: () => [] },
    currentLabel: { type: String, default: '' },
    isCommercial: { type: Boolean, default: false },
    isPostponed: { type: Boolean, default: false },
    isLoading: { type: Boolean, default: false },
    // Hacia dónde abre el menú (en la cabecera, alineado a la derecha).
    align: { type: String, default: 'right' },
  },
  emits: ['select', 'cancel', 'postpone', 'resume'],
  data() {
    return { open: false };
  },
  methods: {
    select(opt) {
      this.open = false;
      this.$emit('select', opt);
    },
    cancel() {
      this.open = false;
      this.$emit('cancel');
    },
    togglePostpone() {
      this.open = false;
      if (this.isPostponed) this.$emit('resume');
      else this.$emit('postpone');
    },
  },
};
</script>

<template>
  <div v-on-clickaway="() => (open = false)" class="relative">
    <woot-button size="small" :is-loading="isLoading" @click="open = !open">
      {{ $t('CASE_TICKETS.STATUS_QUICK.LABEL') }}
      <fluent-icon icon="chevron-down" size="12" class="ml-1" />
    </woot-button>
    <ul
      v-if="open"
      class="absolute z-50 py-1 mt-1 overflow-y-auto list-none bg-white border rounded-md shadow-md top-full max-h-[60vh] dark:bg-slate-800 border-slate-100 dark:border-slate-700 min-w-[200px]"
      :class="align === 'right' ? 'right-0' : 'left-0'"
    >
      <template v-if="isCommercial">
        <li
          class="px-4 py-2 text-sm cursor-pointer text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
          @click="togglePostpone"
        >
          {{
            isPostponed
              ? $t('CASE_TICKETS.COMMERCIAL.ACTIONS.RESUME')
              : $t('CASE_TICKETS.COMMERCIAL.ACTIONS.POSTPONE')
          }}
        </li>
        <li
          class="px-4 py-2 text-sm cursor-pointer text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
          @click="cancel"
        >
          {{ $t('CASE_TICKETS.COMMERCIAL.ACTIONS.CANCEL') }}
        </li>
        <li class="my-1 border-t border-slate-100 dark:border-slate-700" />
      </template>
      <li
        v-if="currentLabel"
        class="px-4 py-1.5 text-xs text-slate-400 dark:text-slate-500"
      >
        {{ $t('CASE_TICKETS.STAGE_BAR.NOW', { stage: currentLabel }) }}
      </li>
      <li
        v-for="opt in options"
        :key="`${opt.columnId || 'x'}-${opt.status || 'x'}`"
        class="px-4 py-2 text-sm cursor-pointer text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700"
        @click="select(opt)"
      >
        {{ opt.label }}
      </li>
      <li
        v-if="!options.length"
        class="px-4 py-2 text-sm text-slate-400 dark:text-slate-500"
      >
        {{ $t('CASE_TICKETS.DETAIL.NO_TRANSITIONS') }}
      </li>
    </ul>
  </div>
</template>
