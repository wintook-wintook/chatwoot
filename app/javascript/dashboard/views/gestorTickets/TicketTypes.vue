<!--
  @tickets_cases
  Gestión de tipos de caso configurables por cuenta — Tailwind + dark mode.
-->
<template>
  <div class="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-25 dark:bg-slate-900">
    <!-- Header -->
    <div class="flex items-center justify-between flex-shrink-0 px-6 py-4 bg-white border-b dark:bg-slate-900 border-slate-50 dark:border-slate-800/50">
      <div class="flex items-center gap-4">
        <woot-button size="small" variant="clear" color-scheme="secondary" icon="arrow-left" @click="$router.push({ name: 'gestorTickets_index' })">
          Volver
        </woot-button>
        <h1 class="m-0 text-xl font-bold text-slate-800 dark:text-slate-100">{{ $t('CASE_TICKETS.TYPES.TITLE') }}</h1>
      </div>
      <woot-button size="small" icon="add-circle" @click="openCreate">{{ $t('CASE_TICKETS.TYPES.CREATE_BUTTON') }}</woot-button>
    </div>

    <!-- Loading -->
    <div v-if="isFetching" class="flex items-center justify-center flex-1 text-slate-400 dark:text-slate-500">
      <span>Cargando tipos...</span>
    </div>

    <!-- Lista -->
    <div v-else class="flex flex-col flex-1 gap-2 px-6 py-4 overflow-y-auto">
      <p class="m-0 mb-2 text-sm text-slate-500 dark:text-slate-400">
        {{ $t('CASE_TICKETS.TYPES.HELP') }}
      </p>
      <div
        v-for="type in types"
        :key="type.id"
        class="flex items-center gap-3 p-3 bg-white border rounded-lg dark:bg-slate-800 border-slate-75 dark:border-slate-700"
      >
        <span class="flex-shrink-0 w-4 h-4 rounded-full" :style="{ backgroundColor: type.color }" />
        <span class="flex-1 text-sm font-medium text-slate-800 dark:text-slate-100">{{ type.name }}</span>
        <span
        v-if="type.prefix"
        class="px-1.5 py-0.5 font-mono text-xs rounded bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
      >{{ type.prefix }}</span>
      <woot-button size="tiny" variant="clear" color-scheme="secondary" icon="edit" @click="openEdit(type)" />
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="alert"
          icon="delete"
          :is-loading="deletingId === type.id"
          @click="confirmDelete(type)"
        />
      </div>
    </div>

    <!-- Modal crear/editar -->
    <woot-modal v-if="showModal" :show="showModal" :on-close="() => showModal = false" size="small">
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header :header-title="editing ? $t('CASE_TICKETS.TYPES.EDIT_TITLE') : $t('CASE_TICKETS.TYPES.CREATE_TITLE')" />

        <form class="flex flex-col self-stretch w-full gap-4 pb-8" @submit.prevent="save">
          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200">{{ $t('CASE_TICKETS.TYPES.NAME_LABEL') }} *</span>
            <input v-model="form.name" type="text" class="w-full" required maxlength="100" placeholder="Ej: Postventa" />
          </label>

          <div class="flex flex-col gap-1">
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200">{{ $t('CASE_TICKETS.TYPES.COLOR_LABEL') }}</span>
            <div class="flex items-center gap-2">
              <button
                v-for="c in palette"
                :key="c"
                type="button"
                class="w-7 h-7 rounded-full border-2 transition-transform"
                :class="form.color === c ? 'border-slate-800 dark:border-white scale-110' : 'border-transparent'"
                :style="{ backgroundColor: c }"
                @click="form.color = c"
              />
              <input v-model="form.color" type="color" class="w-8 h-8 p-0 border-0 rounded cursor-pointer bg-transparent" />
            </div>
          </div>

          <label class="flex flex-col gap-1">
            <span class="text-sm font-medium text-slate-700 dark:text-slate-200">{{ $t('CASE_TICKETS.TYPES.PREFIX_LABEL') }}</span>
            <input
              v-model="form.prefix"
              type="text"
              class="w-32 font-mono uppercase"
              maxlength="8"
              placeholder="SOP"
              @input="form.prefix = form.prefix.toUpperCase()"
            />
            <span class="text-xs text-slate-400 dark:text-slate-500">{{ $t('CASE_TICKETS.TYPES.PREFIX_HELP') }}</span>
          </label>

          <div class="flex justify-end gap-2 mt-2">
            <woot-button variant="clear" color-scheme="secondary" type="button" @click="showModal = false">Cancelar</woot-button>
            <woot-button type="submit" :is-loading="isSaving" :disabled="!form.name.trim()">
              {{ editing ? 'Guardar' : 'Crear' }}
            </woot-button>
          </div>
        </form>
      </div>
    </woot-modal>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';

const PALETTE = ['#3b82f6', '#8b5cf6', '#06b6d4', '#f59e0b', '#ef4444', '#22c55e', '#ec4899', '#64748b'];

export default {
  name: 'TicketTypes',
  data() {
    return {
      showModal: false,
      editing: null,
      form: { name: '', color: '#3b82f6', prefix: '' },
      deletingId: null,
      palette: PALETTE,
    };
  },
  computed: {
    ...mapGetters({
      types: 'caseTickets/getTypes',
      typesUiFlags: 'caseTickets/getTypesUIFlags',
    }),
    isFetching() { return this.typesUiFlags.isFetching; },
    isSaving()   { return this.typesUiFlags.isSaving; },
  },
  mounted() {
    this.$store.dispatch('caseTickets/fetchTypes');
  },
  methods: {
    openCreate() {
      this.editing = null;
      this.form = { name: '', color: '#3b82f6', prefix: '' };
      this.showModal = true;
    },
    openEdit(type) {
      this.editing = type;
      this.form = { name: type.name, color: type.color, prefix: type.prefix || '' };
      this.showModal = true;
    },
    async save() {
      try {
        if (this.editing) {
          await this.$store.dispatch('caseTickets/updateType', { id: this.editing.id, ...this.form });
        } else {
          await this.$store.dispatch('caseTickets/createType', this.form);
        }
        this.showModal = false;
      } catch (_e) { /* silent */ }
    },
    async confirmDelete(type) {
      if (!window.confirm(this.$t('CASE_TICKETS.TYPES.DELETE_CONFIRM', { name: type.name }))) return;
      this.deletingId = type.id;
      try { await this.$store.dispatch('caseTickets/deleteType', type.id); }
      finally { this.deletingId = null; }
    },
  },
};
</script>
