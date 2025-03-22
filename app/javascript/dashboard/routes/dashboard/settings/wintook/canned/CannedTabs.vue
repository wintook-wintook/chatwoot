<script>
import { mapGetters } from 'vuex';
export default {
  name: 'CannedTabs',
  props: {
    selectedTabIndex: {
      type: Number,
      default: 0,
    },
  },
  computed: {
    ...mapGetters({
      globalConfig: 'globalConfig/get',
    }),
    tabs() {
      return [
        { key: 0, name: 'Respuestas predefinidas' },
        { key: 1, name: 'Vocabulario' },
        { key: 2, name: 'Sinónimos' },
        { key: 3, name: 'Foros' },
        { key: 4, name: 'Menú del sistema' },
      ];
    },
  },
  methods: {
    onClickTabChange(index) {
      this.$emit('update:selectedTabIndex', index);
      console.log(globalConfig)
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
