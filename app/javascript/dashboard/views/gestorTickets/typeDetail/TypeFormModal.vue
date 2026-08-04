<!--
  @tickets_cases
  Modal reutilizable para crear/editar un Tipo de Caso. Lo usan tanto la lista
  (TicketTypes.vue) como el detalle (TicketTypeDetail.vue) para no duplicar el
  formulario ni la lógica de guardado.
-->
<script>
const PALETTE = [
  '#3b82f6',
  '#8b5cf6',
  '#06b6d4',
  '#f59e0b',
  '#ef4444',
  '#22c55e',
  '#ec4899',
  '#64748b',
];

const emptyForm = () => ({
  name: '',
  color: '#3b82f6',
  prefix: '',
  public: false,
});

export default {
  name: 'TypeFormModal',
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    // Tipo a editar; null = alta.
    editing: {
      type: Object,
      default: null,
    },
  },
  data() {
    return {
      palette: PALETTE,
      form: emptyForm(),
    };
  },
  computed: {
    isSaving() {
      return this.$store.getters['caseTickets/getTypesUIFlags'].isSaving;
    },
    title() {
      return this.editing
        ? this.$t('CASE_TICKETS.TYPES.EDIT_TITLE')
        : this.$t('CASE_TICKETS.TYPES.CREATE_TITLE');
    },
  },
  watch: {
    show(open) {
      if (open) this.syncForm();
    },
  },
  mounted() {
    this.syncForm();
  },
  methods: {
    syncForm() {
      if (this.editing) {
        this.form = {
          name: this.editing.name,
          color: this.editing.color || '#3b82f6',
          prefix: this.editing.prefix || '',
          public: !!this.editing.public,
        };
      } else {
        this.form = emptyForm();
      }
    },
    close() {
      this.$emit('close');
    },
    async save() {
      if (!this.form.name.trim()) return;
      try {
        if (this.editing) {
          await this.$store.dispatch('caseTickets/updateType', {
            id: this.editing.id,
            ...this.form,
          });
        } else {
          await this.$store.dispatch('caseTickets/createType', this.form);
        }
        this.$emit('saved');
        this.close();
      } catch (_e) {
        /* el store ya expone el error; se mantiene abierto el modal */
      }
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="close" size="small">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header :header-title="title" />

      <form
        class="flex flex-col self-stretch w-full gap-4 pb-8"
        @submit.prevent="save"
      >
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
            >{{ $t('CASE_TICKETS.TYPES.NAME_LABEL') }} *</span
          >
          <input
            v-model="form.name"
            type="text"
            class="w-full"
            required
            maxlength="100"
            :placeholder="$t('CASE_TICKETS.TYPES.NAME_PLACEHOLDER')"
          />
        </label>

        <div class="flex flex-col gap-1">
          <span
            class="text-sm font-medium text-slate-700 dark:text-slate-200"
            >{{ $t('CASE_TICKETS.TYPES.COLOR_LABEL') }}</span
          >
          <div class="flex items-center gap-2">
            <button
              v-for="c in palette"
              :key="c"
              type="button"
              class="border-2 rounded-full w-7 h-7 transition-transform"
              :class="
                form.color === c
                  ? 'border-slate-800 dark:border-white scale-110'
                  : 'border-transparent'
              "
              :style="{ backgroundColor: c }"
              @click="form.color = c"
            />
            <input
              v-model="form.color"
              type="color"
              class="w-8 h-8 p-0 bg-transparent border-0 rounded cursor-pointer"
            />
          </div>
        </div>

        <label class="flex flex-col gap-1">
          <span
            class="text-sm font-medium text-slate-700 dark:text-slate-200"
            >{{ $t('CASE_TICKETS.TYPES.PREFIX_LABEL') }}</span
          >
          <input
            v-model="form.prefix"
            type="text"
            class="w-32 font-mono uppercase"
            maxlength="8"
            :placeholder="$t('CASE_TICKETS.TYPES.PREFIX_PLACEHOLDER')"
            @input="form.prefix = form.prefix.toUpperCase()"
          />
          <span class="text-xs text-slate-400 dark:text-slate-500">{{
            $t('CASE_TICKETS.TYPES.PREFIX_HELP')
          }}</span>
        </label>

        <label class="flex items-start gap-2">
          <input v-model="form.public" type="checkbox" class="mt-1" />
          <span class="flex flex-col">
            <span
              class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >{{ $t('CASE_TICKETS.TYPES.PUBLIC_LABEL') }}</span
            >
            <span class="text-xs text-slate-400 dark:text-slate-500">{{
              $t('CASE_TICKETS.TYPES.PUBLIC_HELP')
            }}</span>
          </span>
        </label>

        <div class="flex justify-end gap-2 mt-2">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            type="button"
            @click="close"
          >
            {{ $t('CASE_TICKETS.CUSTOM_FIELDS.CANCEL_EDIT') }}
          </woot-button>
          <woot-button
            type="submit"
            :is-loading="isSaving"
            :disabled="!form.name.trim()"
          >
            {{
              editing
                ? $t('CASE_TICKETS.CUSTOM_FIELDS.SAVE')
                : $t('CASE_TICKETS.TYPES.CREATE_BUTTON')
            }}
          </woot-button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>
