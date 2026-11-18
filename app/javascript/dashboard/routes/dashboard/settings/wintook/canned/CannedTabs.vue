<script>
export default {
  name: 'CannedTabs',
  props: {
    selectedTabIndex: {
      type: Number,
      default: 0,
    },
  },
  computed: {
    tabs() {
      return [
        { key: 0, name: 'Respuestas predefinidas' },
        // proyecto@auditoria_predefinidas: junto a la lista, que es lo que audita.
        { key: 1, name: this.$t('CANNED_MGMT.AUDIT.TAB') },
        { key: 2, name: 'Vocabulario' },
        { key: 3, name: 'Sinónimos' },
        { key: 4, name: 'Foros' },
        { key: 5, name: 'Menú del sistema' },
      ];
    },
  },
  methods: {
    onClickTabChange(index) {
      this.$emit('update:selectedTabIndex', index);
    },
  },
};
</script>

<template>
  <div class="mt-3 mb-3 flex-1">
    <woot-tabs :index="selectedTabIndex" @change="onClickTabChange">
      <woot-tabs-item
        v-for="tab in tabs"
        :key="tab.key"
        :name="tab.name"
        :show-badge="false"
      />
    </woot-tabs>
  </div>
</template>
