<!--
  Los pasos de los asistentes de los agentes listos como pestañas arriba: las mismas de Kontrolya (woot-tabs:
  solo el nombre y la línea abajo en la activa).
-->
<script>
export default {
  name: 'WizardTabs',
  props: {
    steps: { type: Array, required: true },
    current: { type: String, required: true },
    // { clave: 'texto' }
    labels: { type: Object, required: true },
  },
  emits: ['go'],
  computed: {
    index() {
      return Math.max(this.steps.indexOf(this.current), 0);
    },
  },
};
</script>

<template>
  <woot-tabs
    class="shrink-0"
    :index="index"
    :border="false"
    @change="i => $emit('go', steps[i])"
  >
    <woot-tabs-item
      v-for="(s, i) in steps"
      :key="s"
      :index="i"
      :name="labels[s]"
      :show-badge="false"
    />
  </woot-tabs>
</template>
