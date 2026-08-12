<script>
// ================================================================================
// proyecto@ai_agent_assistant
// ================================================================================
// Componente: DirectiveMention
// Descripción: La lista que sale al escribir «/» en el chat del asistente, para
//              referenciar una directiva sin tener que recordar su sintaxis.
//
// Envuelve el MentionBox nativo —el mismo de las respuestas predefinidas— para
// heredar la navegación con flechas y Enter. Lo único que aporta es traducir el
// Registry a items, y ordenarlos poniendo delante lo que NO rompe tu prompt.
//
// Referenciar no es insertar en el agente: el token entra en TU mensaje, y el
// asistente ya sabe qué hace esa directiva porque el catálogo va en su contexto.
// ================================================================================
import MentionBox from 'dashboard/components/widgets/mentions/MentionBox.vue';

export default {
  components: { MentionBox },
  props: {
    capabilities: {
      type: Array,
      default: () => [],
    },
    searchKey: {
      type: String,
      default: '',
    },
  },
  emits: ['select'],
  computed: {
    items() {
      const query = this.searchKey.trim().toLowerCase();

      return this.capabilities
        .filter(capability => capability.available)
        .flatMap(capability =>
          (capability.tokens || []).map(entry => ({
            key: entry.token,
            label: entry.token,
            description: this.describe(capability, entry),
            swallows: capability.swallows_prompt,
          }))
        )
        .filter(item => !query || item.label.toLowerCase().includes(query))
        .sort((a, b) => Number(a.swallows) - Number(b.swallows));
    },
  },
  methods: {
    // El efecto va primero: es lo que decide si esa directiva te sirve o te borra
    // el prompt, y es lo que nadie recuerda.
    describe(capability, entry) {
      const effect = capability.swallows_prompt
        ? this.$t('AI_AGENT_ASSISTANT.PICKER.EFFECT_SWALLOWS')
        : capability.renders_prompt
          ? this.$t('AI_AGENT_ASSISTANT.PICKER.EFFECT_RENDERS')
          : this.$t('AI_AGENT_ASSISTANT.PICKER.EFFECT_KEEPS');
      const detail =
        entry.label ||
        this.$t(`AI_AGENT_ASSISTANT.CAPABILITIES.${capability.key}.LABEL`);

      return `${effect} · ${detail}`;
    },
    onSelect(item = {}) {
      this.$emit('select', item.key);
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <MentionBox v-if="items.length" :items="items" @mention-select="onSelect" />
</template>
