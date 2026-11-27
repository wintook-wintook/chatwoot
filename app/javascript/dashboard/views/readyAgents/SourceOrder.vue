<!--
  Orden de consulta de las fuentes del agente (los tres agentes listos). Busca en este orden y, antes de
  una fuente lenta (foro, CONTPAQi), revisa si lo de arriba ya lo contesta: si sí, no la consulta
  (Motor2::Search#cascade). Las predefinidas van siempre; su lugar también se puede mover.
  v-model: la lista de llaves marcadas (form.sources); al ordenar se agrega 'canned_response' para guardar su lugar.
-->
<script>
export const CANNED = 'canned_response';
// Sin orden de la empresa: de lo propio y rápido a lo externo y lento (igual que Motor2::Search::PRIORITY).
const PRIORITY = {
  canned_response: 0,
  catalog: 1,
  google_sheet: 2,
  article: 2,
  discourse: 8,
  contpaq_support: 9,
};
const rank = key => PRIORITY[key] ?? PRIORITY[key.split(':')[0]] ?? 5;

// La lista con las predefinidas y en orden (si ya traía las predefinidas, la empresa ya la ordenó).
export const orderedSources = keys => {
  if (keys.includes(CANNED)) return [...keys];
  return [CANNED, ...keys]
    .map((key, i) => ({ key, i }))
    .sort((a, b) => rank(a.key) - rank(b.key) || a.i - b.i)
    .map(x => x.key);
};

// Al marcar una fuente nueva: en su lugar según su tipo.
export const addSource = (keys, key) => {
  const list = orderedSources(keys);
  const at = list.findIndex(k => rank(k) > rank(key));
  if (at === -1) return [...list, key];
  return [...list.slice(0, at), key, ...list.slice(at)];
};

export default {
  name: 'SourceOrder',
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Array, required: true },
    sources: { type: Array, default: () => [] },
  },
  emits: ['input'],
  computed: {
    rows() {
      const byKey = Object.fromEntries(this.sources.map(s => [s.key, s]));
      return orderedSources(this.value)
        .filter(key => byKey[key])
        .map(key => byKey[key]);
    },
  },
  methods: {
    move(index, step) {
      const list = this.rows.map(r => r.key);
      const to = index + step;
      if (to < 0 || to >= list.length) return;
      [list[index], list[to]] = [list[to], list[index]];
      this.$emit('input', list);
    },
  },
};
</script>

<template>
  <div>
    <div v-if="rows.length > 1" class="flex flex-col gap-1">
      <span class="field-label">{{
        $t('READY_AGENTS.SOURCE_ORDER.TITLE')
      }}</span>
      <div
        v-for="(row, i) in rows"
        :key="row.key"
        class="flex items-center gap-2 px-2 py-1 text-sm border rounded border-slate-100 dark:border-slate-700"
      >
        <span class="w-5 text-xs text-slate-400">{{ i + 1 }}.</span>
        <span class="flex-1 truncate">{{ row.name }}</span>
        <button
          type="button"
          class="px-1 text-slate-500 disabled:opacity-30"
          :disabled="i === 0"
          @click="move(i, -1)"
        >
          <fluent-icon icon="chevron-up" size="14" />
        </button>
        <button
          type="button"
          class="px-1 text-slate-500 disabled:opacity-30"
          :disabled="i === rows.length - 1"
          @click="move(i, 1)"
        >
          <fluent-icon icon="chevron-down" size="14" />
        </button>
      </div>
      <p class="m-0 text-xs text-slate-500">
        {{ $t('READY_AGENTS.SOURCE_ORDER.HINT') }}
      </p>
    </div>
  </div>
</template>
