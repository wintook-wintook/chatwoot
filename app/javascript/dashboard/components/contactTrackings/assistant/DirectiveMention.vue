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
            // MentionBox pinta `description` como línea principal en su slot por
            // defecto; aquí se usa el slot propio, así que se guardan por separado.
            description: this.detailOf(capability, entry),
            effect: this.effectOf(capability),
            swallows: capability.swallows_prompt,
          }))
        )
        .filter(item => !query || item.label.toLowerCase().includes(query))
        .sort((a, b) => Number(a.swallows) - Number(b.swallows));
    },
  },
  methods: {
    detailOf(capability, entry) {
      return (
        entry.label ||
        this.$t(`AI_AGENT_ASSISTANT.CAPABILITIES.${capability.key}.LABEL`)
      );
    },
    // Lo que decide si esa directiva te sirve o te borra el prompt, y es lo que
    // nadie recuerda. Por eso va en la lista y con color.
    effectOf(capability) {
      if (capability.swallows_prompt) return 'swallows';
      return capability.renders_prompt ? 'renders' : 'keeps';
    },
    effectClasses(effect) {
      if (effect === 'swallows') return 'text-red-600 dark:text-red-400';
      if (effect === 'renders') return 'text-amber-600 dark:text-amber-400';
      return 'text-green-600 dark:text-green-400';
    },
    onSelect(item = {}) {
      this.$emit('select', item.key);
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <MentionBox v-if="items.length" :items="items" @mentionSelect="onSelect">
    <!-- Slot propio: el de por defecto antepone «/» a la etiqueta y saldría
         «/@buscar_articulo». Aquí manda el token tal cual se va a insertar. -->
    <template #default="{ item }">
      <p
        class="max-w-full min-w-0 mb-0 overflow-hidden font-mono text-sm font-medium truncate text-slate-900 dark:text-slate-100"
      >
        {{ item.label }}
      </p>
      <p class="max-w-full min-w-0 mb-0 overflow-hidden text-xs truncate">
        <span :class="effectClasses(item.effect)">
          {{
            $t(`AI_AGENT_ASSISTANT.PICKER.EFFECT_${item.effect.toUpperCase()}`)
          }}
        </span>
        <span class="text-slate-500 dark:text-slate-300">
          · {{ item.description }}
        </span>
      </p>
    </template>
  </MentionBox>
</template>
