<!--
  Campaña con Vendedor IA — el correo de un toque, por bloques (título, texto, botón, imagen), como los editores
  de los líderes pero sencillo. Sale como markdown (body) y guarda los bloques para volver a abrirlo igual.
  Sin bloques, lo escribe el agente con IA para cada contacto. v-model: { body, blocks }.
-->
<script>
const TYPES = ['heading', 'text', 'button', 'image'];

export const toMarkdown = blocks =>
  (blocks || [])
    .map(b => {
      const text = (b.text || '').trim();
      const url = (b.url || '').trim();
      if (b.type === 'heading') return text ? `## ${text}` : '';
      if (b.type === 'button') return text && url ? `[${text}](${url})` : '';
      if (b.type === 'image')
        return url ? `![${text || 'imagen'}](${url})` : '';
      return text;
    })
    .filter(Boolean)
    .join('\n\n');

export default {
  name: 'EmailEditor',
  model: { prop: 'value', event: 'input' },
  props: {
    value: { type: Object, required: true },
    signature: { type: String, default: '' },
  },
  emits: ['input'],
  computed: {
    types() {
      return TYPES;
    },
    blocks() {
      return this.value.blocks || [];
    },
  },
  methods: {
    t(key) {
      return this.$t(`CAMPAIGNS2.EMAIL.${key}`);
    },
    emit(blocks) {
      this.$emit('input', { blocks, body: toMarkdown(blocks) });
    },
    add(type) {
      this.emit([...this.blocks, { type, text: '', url: '' }]);
    },
    set(i, field, val) {
      this.emit(
        this.blocks.map((b, j) => (j === i ? { ...b, [field]: val } : b))
      );
    },
    remove(i) {
      this.emit(this.blocks.filter((_b, j) => j !== i));
    },
    move(i, dir) {
      const list = [...this.blocks];
      const j = i + dir;
      if (j < 0 || j >= list.length) return;
      [list[i], list[j]] = [list[j], list[i]];
      this.emit(list);
    },
    insertVar(i, name) {
      const b = this.blocks[i];
      this.set(i, 'text', `${b.text || ''}{{${name}}}`);
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <p v-if="!blocks.length" class="m-0 text-xs text-slate-500">
      {{ t('AI_WRITES') }}
    </p>
    <div
      v-for="(block, i) in blocks"
      :key="i"
      class="flex flex-col gap-1 p-2 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <div class="flex items-center justify-between gap-2">
        <span class="text-xs font-medium text-slate-600 dark:text-slate-300">
          {{ t(`TYPES.${block.type}`) }}
        </span>
        <span class="flex items-center gap-1">
          <button
            type="button"
            class="px-1 text-slate-400 hover:text-slate-700"
            :title="t('UP')"
            @click="move(i, -1)"
          >
            <fluent-icon icon="chevron-up" size="14" />
          </button>
          <button
            type="button"
            class="px-1 text-slate-400 hover:text-slate-700"
            :title="t('DOWN')"
            @click="move(i, 1)"
          >
            <fluent-icon icon="chevron-down" size="14" />
          </button>
          <button
            type="button"
            class="px-1 text-slate-400 hover:text-red-600"
            :title="t('REMOVE')"
            @click="remove(i)"
          >
            <fluent-icon icon="dismiss" size="14" />
          </button>
        </span>
      </div>
      <textarea
        v-if="block.type === 'text'"
        rows="4"
        class="!mb-0"
        :value="block.text"
        :placeholder="t('TEXT_PLACEHOLDER')"
        @input="set(i, 'text', $event.target.value)"
      />
      <input
        v-else
        type="text"
        class="!mb-0"
        :value="block.text"
        :placeholder="t(`PLACEHOLDER.${block.type}`)"
        @input="set(i, 'text', $event.target.value)"
      />
      <input
        v-if="block.type === 'button' || block.type === 'image'"
        type="url"
        class="!mb-0"
        :value="block.url"
        :placeholder="t(`URL.${block.type}`)"
        @input="set(i, 'url', $event.target.value)"
      />
      <span
        v-if="block.type === 'text' || block.type === 'heading'"
        class="flex gap-2"
      >
        <button
          v-for="name in ['contacto', 'empresa']"
          :key="name"
          type="button"
          class="px-2 text-xs rounded bg-slate-50 dark:bg-slate-700 text-woot-600"
          @click="insertVar(i, name)"
        >
          {{ t(`VAR.${name}`) }}
        </button>
      </span>
    </div>
    <div class="flex flex-wrap gap-2">
      <woot-button
        v-for="type in types"
        :key="type"
        size="tiny"
        variant="smooth"
        color-scheme="secondary"
        icon="add"
        type="button"
        @click="add(type)"
      >
        {{ t(`TYPES.${type}`) }}
      </woot-button>
    </div>
    <p v-if="signature" class="m-0 text-xs text-slate-500">
      {{ t('SIGNATURE') }}
    </p>
  </div>
</template>
