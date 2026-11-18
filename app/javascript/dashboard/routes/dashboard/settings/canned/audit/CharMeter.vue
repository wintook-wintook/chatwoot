<script>
// proyecto@auditoria_predefinidas — EL MEDIDOR DE CARACTERES DEL FORMULARIO
// ============================================================================
//   ███████████░░░░░  1,734 / 2,000  · Cerca del límite
//
// Cuenta lo que recibe el agente (nombre + «: » + contenido, ver cannedSize.js), no
// solo el contenido. Avisa, no bloquea: una predefinida larga funciona, pero el agente
// ve solo una parte. Pasado el tope enseña los bloques (como los parte SectionFit) con
// su tamaño, para ver qué conviene llevar a otra predefinida.
// ============================================================================
import {
  MAX_CHARS,
  agentChars,
  sizeLevel,
  blocksOf,
  LEVEL_TEXT,
  LEVEL_BAR,
} from './cannedSize';

export default {
  props: {
    shortCode: { type: String, default: '' },
    content: { type: String, default: '' },
  },
  data() {
    return { showBlocks: false, max: MAX_CHARS };
  },
  computed: {
    chars() {
      return agentChars(this.shortCode, this.content);
    },
    level() {
      return sizeLevel(this.chars);
    },
    percent() {
      return Math.min(100, Math.round((this.chars / MAX_CHARS) * 100));
    },
    textClass() {
      return LEVEL_TEXT[this.level];
    },
    barClass() {
      return LEVEL_BAR[this.level];
    },
    blocks() {
      return blocksOf(`${this.shortCode}: ${this.content}`);
    },
  },
  methods: {
    number(n) {
      return n.toLocaleString();
    },
    preview(block) {
      const linea = block.replace(/\s+/g, ' ');
      return linea.length > 80 ? `${linea.slice(0, 80)}…` : linea;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-1 text-xs" data-test="char-meter">
    <div class="flex items-center gap-2">
      <div
        class="flex-1 h-1.5 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-700"
        role="meter"
        :aria-valuenow="chars"
        aria-valuemin="0"
        :aria-valuemax="max"
        :aria-label="$t('CANNED_MGMT.AUDIT.METER.LABEL')"
      >
        <div
          class="h-full transition-all"
          :class="barClass"
          :style="{ width: `${percent}%` }"
        />
      </div>
      <span
        class="font-medium tabular-nums whitespace-nowrap"
        :class="textClass"
      >
        {{ number(chars) }} / {{ number(max) }}
      </span>
    </div>
    <p class="!m-0" :class="textClass">
      {{ $t(`CANNED_MGMT.AUDIT.METER.${level.toUpperCase()}`) }}
      <button
        v-if="level === 'over'"
        type="button"
        class="ml-1 underline"
        @click="showBlocks = !showBlocks"
      >
        {{
          showBlocks
            ? $t('CANNED_MGMT.AUDIT.METER.HIDE_BLOCKS')
            : $t('CANNED_MGMT.AUDIT.METER.SHOW_BLOCKS', {
                count: blocks.length,
              })
        }}
      </button>
    </p>
    <ol
      v-if="level === 'over' && showBlocks"
      class="!m-0 max-h-32 overflow-y-auto list-none !pl-0 flex flex-col gap-0.5"
    >
      <li
        v-for="(block, i) in blocks"
        :key="i"
        class="flex gap-2 text-slate-600 dark:text-slate-300"
      >
        <span class="w-12 text-right tabular-nums shrink-0">
          {{ number(block.length) }}
        </span>
        <span class="truncate">{{ preview(block) }}</span>
      </li>
    </ol>
  </div>
</template>
