<!--
  Asistente (Dali) — D5a: tarjeta de datos que acompaña una respuesta de ventas.
  Las cifras llegan crudas del servidor (Assistant::SalesCards): aquí solo se
  formatean (moneda, %) y se enlazan a su pantalla. Sin gráfica: cifras y tabla.
-->
<script>
import { formatMoney } from 'dashboard/helper/caseCommercial';

export default {
  name: 'AssistantDataCard',
  props: {
    card: { type: Object, required: true },
  },
  emits: ['navigate'],
  methods: {
    format(cell) {
      if (!cell || cell.value === null || cell.value === undefined) return '—';
      if (cell.kind === 'money') return formatMoney(cell.value, cell.currency);
      if (cell.kind === 'percent') return `${cell.value}%`;
      return cell.value;
    },
  },
};
</script>

<template>
  <div
    class="w-full p-3 bg-white border rounded-lg border-slate-100 dark:bg-slate-800 dark:border-slate-700"
  >
    <p
      v-if="card.title"
      class="m-0 mb-2 text-xs font-semibold text-slate-600 dark:text-slate-300"
    >
      {{ card.title }}
    </p>
    <div v-if="card.tiles && card.tiles.length" class="grid grid-cols-2 gap-2">
      <div
        v-for="tile in card.tiles"
        :key="tile.label"
        class="px-2 py-1.5 rounded-md bg-slate-25 dark:bg-slate-900/40"
      >
        <p class="m-0 text-[11px] text-slate-500 dark:text-slate-400">
          {{ tile.label }}
        </p>
        <p
          class="m-0 text-sm font-semibold tabular-nums text-slate-800 dark:text-slate-100"
        >
          {{ format(tile) }}
        </p>
      </div>
    </div>
    <table
      v-if="card.table && card.table.rows.length"
      class="w-full mt-2 text-xs"
    >
      <thead>
        <tr class="text-slate-500 dark:text-slate-400">
          <th
            v-for="col in card.table.columns"
            :key="col.label"
            class="py-1 pr-2 font-medium"
            :class="col.kind === 'text' ? 'text-left' : 'text-right'"
          >
            {{ col.label }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="(row, i) in card.table.rows"
          :key="i"
          class="border-t border-slate-50 dark:border-slate-700/60"
        >
          <td
            v-for="(cell, j) in row"
            :key="j"
            class="py-1 pr-2 text-slate-700 dark:text-slate-200"
            :class="
              card.table.columns[j] && card.table.columns[j].kind !== 'text'
                ? 'text-right tabular-nums whitespace-nowrap'
                : 'truncate max-w-[9rem]'
            "
          >
            <button
              v-if="cell.path"
              type="button"
              class="p-0 text-woot-600 hover:underline"
              @click="$emit('navigate', cell.path)"
            >
              {{ format(cell) }}
            </button>
            <template v-else>{{ format(cell) }}</template>
          </td>
        </tr>
      </tbody>
    </table>
    <button
      v-if="card.link"
      type="button"
      class="flex items-center gap-1 p-0 mt-2 text-xs text-woot-600 hover:underline"
      @click="$emit('navigate', card.link.path)"
    >
      {{ card.link.label }}
      <fluent-icon icon="arrow-right" size="12" />
    </button>
  </div>
</template>
