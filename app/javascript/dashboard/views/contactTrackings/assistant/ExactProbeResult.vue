<script>
// proyecto@crear_agente_conversando §15 P2 — EL RESULTADO DE UNA FUENTE EXACTA
// ============================================================================
// Lo que regresa SourceProbeExact, dicho como lo vivía el agente:
//   hoja_buscar   qué buscó, qué fila encontró y qué regresaría (o qué preguntaría)
//   hoja (datos)  el resultado calculado
//   consulta ERP  con qué valores corrió y qué filas trajo (o el texto ya armado)
// ============================================================================
const K = 'TRACKING_ASSISTANT_VIEW.PROBE.';
// Medido con la hoja de grúas: regresa ligas de calendario de 200 caracteres.
const MAX_FOUND = 12;
const MAX_VALUE = 60;

export default {
  props: {
    result: { type: Object, required: true },
  },
  computed: {
    status() {
      return this.result.status || '';
    },
    message() {
      const r = this.result;
      const clave = `${K}${r.kind.toUpperCase()}_${this.status.toUpperCase()}`;
      return this.$t(clave, {
        sheet: r.sheet || '',
        criteria: (r.criteria || []).join('; '),
        asked: r.asked || '',
        missing: (r.missing || []).join(', '),
        returns: (r.returns || []).join(', '),
      });
    },
    params() {
      return Object.entries(this.result.params || {}).map(
        ([clave, valor]) => `${clave} = ${valor}`
      );
    },
    columns() {
      return this.result.columns || [];
    },
    found() {
      return (this.result.found || [])
        .slice(0, MAX_FOUND)
        .map(v =>
          String(v).length > MAX_VALUE ? `${String(v).slice(0, MAX_VALUE)}…` : v
        );
    },
    good() {
      return this.status === 'ok';
    },
  },
  methods: {
    cell(row, column) {
      const valor = row[column];
      return valor === null || valor === undefined ? '' : String(valor);
    },
  },
};
</script>

<template>
  <div class="flex flex-col min-h-0 gap-3 text-sm">
    <p
      class="!m-0 text-sm"
      :class="
        good
          ? 'text-slate-700 dark:text-slate-200'
          : 'text-amber-800 dark:text-amber-800'
      "
    >
      {{ message }}
    </p>

    <!-- hoja_buscar: lo que regresaría y las filas -->
    <div v-if="found.length" class="flex flex-wrap gap-1">
      <span
        v-for="valor in found"
        :key="valor"
        class="px-2 py-0.5 text-xs rounded bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-300"
      >
        {{ valor }}
      </span>
    </div>
    <ul
      v-if="result.rows && result.rows.length && !columns.length"
      class="!m-0 !pl-4 flex flex-col gap-0.5 overflow-y-auto text-xs text-slate-600 dark:text-slate-300 list-disc"
    >
      <li v-for="(fila, index) in result.rows" :key="index" class="break-all">
        {{ fila }}
      </li>
    </ul>
    <p
      v-if="result.more"
      class="!m-0 text-xs text-slate-500 dark:text-slate-400"
    >
      {{
        $t('TRACKING_ASSISTANT_VIEW.PROBE.MORE_ROWS', { count: result.more })
      }}
    </p>

    <!-- hoja en modo datos -->
    <p
      v-if="result.answer"
      class="!m-0 px-3 py-2 rounded-md bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100"
    >
      {{ result.answer }}
    </p>

    <!-- ERP: con qué valores corrió y qué trajo -->
    <div v-if="params.length" class="flex flex-wrap items-center gap-1">
      <span class="text-xs text-slate-500 dark:text-slate-400">
        {{ $t('TRACKING_ASSISTANT_VIEW.PROBE.ERP_PARAMS') }}
      </span>
      <span
        v-for="parametro in params"
        :key="parametro"
        class="px-2 py-0.5 font-mono text-xs rounded bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-200"
      >
        {{ parametro }}
      </span>
    </div>
    <div v-if="columns.length && result.rows.length" class="overflow-auto">
      <table class="w-full text-xs">
        <thead>
          <tr>
            <th
              v-for="columna in columns"
              :key="columna"
              class="px-2 py-1 font-semibold text-left text-slate-600 dark:text-slate-300"
            >
              {{ columna }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="(fila, index) in result.rows"
            :key="index"
            class="border-t border-slate-100 dark:border-slate-700"
          >
            <td
              v-for="columna in columns"
              :key="columna"
              class="px-2 py-1 text-slate-700 dark:text-slate-200"
            >
              {{ cell(fila, columna) }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p
      v-if="result.partial"
      class="!m-0 text-xs text-amber-800 dark:text-amber-800"
    >
      {{ $t('TRACKING_ASSISTANT_VIEW.PROBE.ERP_PARTIAL') }}
    </p>
    <p
      v-if="result.rendered"
      class="!m-0 px-3 py-2 font-mono text-xs whitespace-pre-wrap rounded-md bg-slate-50 dark:bg-slate-700 text-slate-800 dark:text-slate-100"
    >
      {{ result.rendered }}
    </p>
  </div>
</template>
