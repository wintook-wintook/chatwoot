<!--
  Pestañas dentro de un paso de los asistentes (áreas de «Qué atiende», «Al calificar», «Seguimiento»): las mismas
  de Kontrolya (woot-tabs). v-model: la clave de la pestaña activa.
-->
<script>
export default {
  name: 'SubTabs',
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: String, required: true },
    // [{ key, label }]
    tabs: { type: Array, required: true },
  },
  emits: ['input'],
  computed: {
    index() {
      return Math.max(
        this.tabs.findIndex(t => t.key === this.value),
        0
      );
    },
  },
};
</script>

<template>
  <woot-tabs
    :index="index"
    :border="false"
    @change="i => $emit('input', tabs[i].key)"
  >
    <woot-tabs-item
      v-for="(tab, i) in tabs"
      :key="tab.key"
      :index="i"
      :name="tab.label"
      :show-badge="false"
    />
  </woot-tabs>
</template>
