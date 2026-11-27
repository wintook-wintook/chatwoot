<script>
// proyecto@crear_agente_conversando — F2: la barra que aparece al escribir «%».
// Solo dibuja los nombres y avisa cuál se eligió; el texto lo cambia quien la usa
// (ver constantPicker.js).
export default {
  props: {
    names: { type: Array, default: () => [] },
  },
  emits: ['pick', 'close'],
};
</script>

<template>
  <div
    class="flex flex-wrap items-center gap-1 px-2 py-1 mt-1 border rounded-md border-woot-100 bg-woot-25 dark:border-woot-700 dark:bg-woot-900/30"
  >
    <span class="text-xs text-slate-600 dark:text-slate-300">
      {{ $t('TRACKING_ASSISTANT_VIEW.CONSTANTS_PICKER') }}
    </span>
    <woot-button
      v-for="name in names"
      :key="name"
      size="tiny"
      variant="smooth"
      color-scheme="primary"
      class="font-mono"
      @mousedown.prevent
      @click="$emit('pick', name)"
    >
      {{ `%${name}%` }}
    </woot-button>
    <woot-button
      size="tiny"
      variant="clear"
      color-scheme="secondary"
      icon="dismiss"
      @mousedown.prevent
      @click="$emit('close')"
    />
  </div>
</template>
