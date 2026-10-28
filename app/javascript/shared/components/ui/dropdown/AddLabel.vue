<script>
export default {
  props: {
    // Texto del botón; por omisión el de la conversación.
    text: { type: String, default: '' },
  },
  methods: {
    addLabel() {
      this.$emit('add');
    },
  },
};
</script>

<template>
  <woot-button
    variant="smooth"
    class="label--add"
    icon="add"
    size="tiny"
    @click="addLabel"
  >
    {{ text || $t('CONTACT_PANEL.LABELS.CONVERSATION.ADD_BUTTON') }}
  </woot-button>
</template>

<style lang="scss" scoped>
.label--add {
  margin-bottom: var(--space-micro);
  margin-right: var(--space-micro);
}
</style>
