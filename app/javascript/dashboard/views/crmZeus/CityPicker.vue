<!--
  CrmZeus O2 — selector de ciudad como el de CRMZeus: se teclean las primeras letras
  y se elige «Ciudad, EDO, País». Si no está, se da de alta ahí mismo con su estado.
  Emite `change` con { id, full_name } (o null al quitarla).
-->
<script>
import CrmCatalogs from 'dashboard/api/crmCatalogs';
import { errorMessage } from './crmHelpers';

export default {
  name: 'CrmCityPicker',
  props: {
    label: { type: String, default: '' },
    countries: { type: Array, default: () => [] },
    disabled: { type: Boolean, default: false },
  },
  data() {
    return {
      query: '',
      results: [],
      open: false,
      searching: false,
      debounce: null,
      creating: null,
      error: '',
    };
  },
  computed: {
    states() {
      return this.countries.flatMap(country =>
        country.states.map(state => ({
          ...state,
          label: `${state.name} (${country.name})`,
        }))
      );
    },
  },
  beforeDestroy() {
    clearTimeout(this.debounce);
  },
  methods: {
    onInput() {
      this.open = true;
      clearTimeout(this.debounce);
      this.debounce = setTimeout(this.search, 300);
    },
    async search() {
      if (!this.query.trim()) {
        this.results = [];
        return;
      }
      this.searching = true;
      try {
        const { data } = await CrmCatalogs.searchCities({ q: this.query });
        this.results = data.cities;
      } finally {
        this.searching = false;
      }
    },
    pick(city) {
      this.$emit('change', city);
      this.reset();
    },
    clear() {
      this.$emit('change', null);
    },
    startCreate() {
      this.creating = { name: this.query.trim(), state_id: '' };
      this.open = false;
      this.error = '';
    },
    async create() {
      if (!this.creating.name.trim() || !this.creating.state_id) return;
      try {
        const { data } = await CrmCatalogs.createCity(this.creating);
        this.pick(data.city);
      } catch (error) {
        this.error = errorMessage(error, this.$t('CRM_ZEUS.ERROR'));
      }
    },
    reset() {
      this.query = '';
      this.results = [];
      this.open = false;
      this.creating = null;
      this.error = '';
    },
    close() {
      // Deja tiempo al clic de un resultado antes de cerrar la lista.
      setTimeout(() => {
        this.open = false;
      }, 200);
    },
  },
};
</script>

<template>
  <div class="relative">
    <div v-if="label && !creating" class="flex items-center gap-2 mb-2">
      <span
        class="flex-1 px-3 py-2 text-sm rounded-md bg-slate-50 dark:bg-slate-800 text-slate-800 dark:text-slate-100"
      >
        {{ label }}
      </span>
      <woot-button
        v-if="!disabled"
        type="button"
        size="tiny"
        variant="clear"
        color-scheme="secondary"
        icon="dismiss"
        :title="$t('CRM_ZEUS.CITY.CLEAR')"
        @click="clear"
      />
    </div>
    <template v-if="!label && !creating && !disabled">
      <input
        v-model="query"
        type="search"
        class="!mb-0"
        :placeholder="$t('CRM_ZEUS.CITY.PLACEHOLDER')"
        @input="onInput"
        @focus="open = true"
        @blur="close"
      />
      <ul
        v-if="open && query.trim()"
        class="absolute z-20 w-full p-1 mt-1 overflow-auto bg-white border rounded-md shadow-lg max-h-60 dark:bg-slate-800 border-slate-100 dark:border-slate-700"
      >
        <li
          v-for="city in results"
          :key="city.id"
          class="px-3 py-1.5 text-sm rounded cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700"
          @mousedown.prevent="pick(city)"
        >
          {{ city.full_name }}
        </li>
        <li
          v-if="!searching && !results.length"
          class="px-3 py-1.5 text-sm text-slate-500"
        >
          {{ $t('CRM_ZEUS.CITY.NONE') }}
        </li>
        <li
          class="px-3 py-1.5 text-sm rounded cursor-pointer text-woot-600 hover:bg-slate-50 dark:hover:bg-slate-700"
          @mousedown.prevent="startCreate"
        >
          {{ $t('CRM_ZEUS.CITY.CREATE', { name: query.trim() }) }}
        </li>
      </ul>
    </template>
    <div
      v-if="creating"
      class="flex flex-col gap-2 p-3 mb-2 border rounded-md border-slate-100 dark:border-slate-700"
    >
      <p class="m-0 text-sm font-medium text-slate-800 dark:text-slate-100">
        {{ $t('CRM_ZEUS.CITY.NEW_TITLE') }}
      </p>
      <input
        v-model="creating.name"
        type="text"
        class="!mb-0"
        :placeholder="$t('CRM_ZEUS.CITY.NAME')"
      />
      <select v-model="creating.state_id" class="!mb-0">
        <option value="">{{ $t('CRM_ZEUS.CITY.STATE') }}</option>
        <option v-for="state in states" :key="state.id" :value="state.id">
          {{ state.label }}
        </option>
      </select>
      <p v-if="error" class="m-0 text-xs text-red-600">{{ error }}</p>
      <div class="flex justify-end gap-2">
        <button type="button" class="button clear small" @click="reset">
          {{ $t('CRM_ZEUS.CANCEL') }}
        </button>
        <woot-button type="button" size="small" @click="create">
          {{ $t('CRM_ZEUS.CITY.SAVE') }}
        </woot-button>
      </div>
    </div>
  </div>
</template>
