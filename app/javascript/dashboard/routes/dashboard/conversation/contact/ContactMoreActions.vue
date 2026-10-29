<!--
  Botón con menú de la ficha del contacto: «Más» (las acciones que no son las
  principales), «+ Nuevo» o «Mensaje ▾» (`split`: el clic hace la acción
  principal y la flecha abre el menú).
  `actions`: [{ key, label, icon, danger?, disabled? }] · emite `select(key)` y,
  con `split`, `main` al clic del botón.
-->
<script>
export default {
  name: 'ContactMoreActions',
  props: {
    actions: { type: Array, default: () => [] },
    label: { type: String, default: '' },
    icon: { type: String, default: 'more-horizontal' },
    variant: { type: String, default: 'smooth' },
    colorScheme: { type: String, default: 'secondary' },
    split: { type: Boolean, default: false },
    // Solo el ícono (el «···» de la página del contacto).
    iconOnly: { type: Boolean, default: false },
  },
  emits: ['select', 'main'],
  data() {
    return { open: false };
  },
  computed: {
    buttonLabel() {
      return this.label || this.$t('CONTACT_PANEL.ACTIONS.MORE');
    },
  },
  methods: {
    close() {
      this.open = false;
    },
    choose(action) {
      if (action.disabled) return;
      this.open = false;
      this.$emit('select', action.key);
    },
  },
};
</script>

<template>
  <div v-if="actions.length" v-on-clickaway="close" class="relative">
    <div v-if="split" class="flex">
      <woot-button
        :icon="icon"
        :variant="variant"
        size="small"
        :color-scheme="colorScheme"
        class="ltr:!rounded-r-none rtl:!rounded-l-none"
        @click="$emit('main')"
      >
        {{ buttonLabel }}
      </woot-button>
      <woot-button
        icon="chevron-down"
        :variant="variant"
        size="small"
        :color-scheme="colorScheme"
        class="ltr:!rounded-l-none rtl:!rounded-r-none ltr:border-l rtl:border-r border-white/40"
        :title="$t('CONTACT_PANEL.ACTIONS.MORE')"
        @click="open = !open"
      />
    </div>
    <woot-button
      v-else
      :icon="icon"
      :variant="variant"
      size="small"
      :color-scheme="colorScheme"
      :title="iconOnly ? buttonLabel : null"
      @click="open = !open"
    >
      <template v-if="!iconOnly">{{ buttonLabel }}</template>
    </woot-button>
    <ul
      v-if="open"
      class="absolute z-50 w-56 p-1 m-0 mt-1 list-none bg-white border rounded-md shadow-xl ltr:right-0 rtl:left-0 top-full dark:bg-slate-800 border-slate-50 dark:border-slate-700"
    >
      <li v-for="action in actions" :key="action.key">
        <button
          type="button"
          class="flex items-center w-full gap-2 px-3 py-2 text-sm text-left rounded-md hover:bg-slate-50 dark:hover:bg-slate-700 disabled:opacity-50"
          :class="
            action.danger
              ? 'text-red-600 dark:text-red-400'
              : 'text-slate-700 dark:text-slate-200'
          "
          :disabled="action.disabled"
          @click="choose(action)"
        >
          <fluent-icon :icon="action.icon" size="16" />
          {{ action.label }}
        </button>
      </li>
    </ul>
  </div>
</template>
