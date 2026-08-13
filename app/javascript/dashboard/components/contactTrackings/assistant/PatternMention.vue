<script>
// ================================================================================
// proyecto@ai_agent_assistant
// ================================================================================
// Componente: PatternMention
// Descripción: La lista que sale al escribir «$» en el chat del asistente, para
//              señalarle un patrón de la biblioteca como ejemplo.
//
// Gemelo de DirectiveMention, y a propósito: dos gestos parecidos, «/» y «$», que
// se aprenden una vez. Lo que cambia es qué se referencia y para qué —
//   «/» → una directiva: sintaxis exacta, lo que importa es su EFECTO sobre el prompt.
//   «$» → un patrón: un bloque de ejemplo, lo que importa es qué PROBLEMA resuelve.
//
// Referenciar no es insertar: el token entra en TU mensaje y el asistente recibe el
// texto del bloque con su evidencia, para adaptarlo a tu negocio. Pegarlo tal cual
// dejaría los <huecos> literales dentro del prompt, que es justo lo que no queremos.
// ================================================================================
import MentionBox from 'dashboard/components/widgets/mentions/MentionBox.vue';

export default {
  components: { MentionBox },
  props: {
    blocks: {
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

      return this.blocks
        .map(block => ({
          key: `$${block.key}`,
          label: `$${block.key}`,
          // El nombre humano del bloque y la sección donde vive: es lo que dice si
          // te sirve, porque nadie recuerda 28 claves en inglés.
          description: this.blockLabel(block),
          section: this.sectionLabel(block),
          status: block.status,
          // El detalle solo se pinta en la fila marcada, así que viaja con el item
          // en vez de pedirse aparte al abrirlo.
          body: block.body,
          source: block.source,
        }))
        .filter(
          item =>
            !query ||
            item.label.toLowerCase().includes(query) ||
            item.description.toLowerCase().includes(query)
        )
        .sort((a, b) => this.rank(a.status) - this.rank(b.status));
    },
  },
  methods: {
    // Lo usable primero. Un bloque que aquí sería letra muerta no se esconde —
    // saber POR QUÉ no sirve es la mitad de lo que enseña la biblioteca — pero
    // tampoco encabeza la lista.
    rank(status) {
      return status === 'ready' ? 0 : 1;
    },
    blockLabel(block) {
      return this.$t(`AI_AGENT_ASSISTANT.PATTERNS.BLOCK.${block.key}`);
    },
    sectionLabel(block) {
      return this.$t(`AI_AGENT_ASSISTANT.PATTERNS.SECTION.${block.section}`);
    },
    statusClasses(status) {
      return status === 'ready'
        ? 'text-green-600 dark:text-green-400'
        : 'text-amber-600 dark:text-amber-400';
    },
    onSelect(item = {}) {
      this.$emit('select', item.key);
    },
  },
};
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <!-- Más alta que la lista de directivas: aquí la fila marcada se despliega con el
       texto del bloque, y en 9.75rem no cabría. -->
  <MentionBox
    v-if="items.length"
    class="!max-h-[24rem]"
    :items="items"
    @mentionSelect="onSelect"
  >
    <!-- Slot propio: el de por defecto antepone «/» a la etiqueta y aquí el
         prefijo ya viene en el token. -->
    <template #default="{ item, selected }">
      <p
        class="max-w-full min-w-0 mb-0 overflow-hidden font-mono text-sm font-medium truncate text-slate-900 dark:text-slate-100"
      >
        {{ item.label }}
      </p>
      <p class="max-w-full min-w-0 mb-0 overflow-hidden text-xs truncate">
        <span :class="statusClasses(item.status)">
          {{
            $t(
              `AI_AGENT_ASSISTANT.PATTERNS.STATUS.${(
                item.status || ''
              ).toUpperCase()}`
            )
          }}
        </span>
        <span class="text-slate-500 dark:text-slate-300">
          · {{ item.description }} · {{ item.section }}
        </span>
      </p>

      <!-- El detalle, en la fila donde estás parado. Un botón aparte no cabía: la
           fila entera YA es el botón que inserta, y un modal encima del chat te
           robaría el foco y se llevaría por delante lo que llevas escrito. -->
      <template v-if="selected">
        <p
          class="w-full p-2 mt-1 mb-0 font-mono text-xs leading-snug text-left whitespace-pre-wrap rounded bg-slate-50 dark:bg-slate-900 text-slate-700 dark:text-slate-200"
        >
          {{ item.body }}
        </p>
        <!-- La evidencia: un bloque sin ella sería solo una opinión. Misma frase que
             en el cajón, para que el mismo patrón se lea igual en los dos sitios. -->
        <p
          class="w-full mt-1 mb-0 text-xs italic leading-snug text-left text-slate-500 dark:text-slate-400"
        >
          {{ item.source }}
        </p>
      </template>
    </template>
  </MentionBox>
</template>
