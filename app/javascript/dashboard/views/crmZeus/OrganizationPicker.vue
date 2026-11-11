<!--
  CrmZeus Q2 — buscador de organizaciones (clientes y prospectos) por clave, razón
  social o nombre comercial. Emite `pick` con la organización de la lista.
-->
<script>
import CrmOrganizations from 'dashboard/api/crmOrganizations';

export default {
  name: 'CrmOrganizationPicker',
  data() {
    return {
      query: '',
      results: [],
      open: false,
      searching: false,
      debounce: null,
    };
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
        const { data } = await CrmOrganizations.list({ q: this.query });
        this.results = data.organizations;
      } finally {
        this.searching = false;
      }
    },
    pick(organization) {
      this.$emit('pick', organization);
      this.query = '';
      this.results = [];
      this.open = false;
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
    <input
      v-model="query"
      type="search"
      class="block w-full h-10 p-2 !mb-0 text-base box-border rounded-md bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-solid border-slate-200 dark:border-slate-600 focus:border-woot-500 dark:focus:border-woot-600"
      :placeholder="$t('CRM_ZEUS.QUOTE_FORM.ORGANIZATION_SEARCH')"
      @input="onInput"
      @focus="open = true"
      @blur="close"
    />
    <ul
      v-if="open && query.trim()"
      class="absolute z-20 w-full p-1 mt-1 overflow-auto bg-white border rounded-md shadow-lg max-h-60 dark:bg-slate-800 border-slate-100 dark:border-slate-700"
    >
      <li
        v-for="org in results"
        :key="org.id"
        class="flex items-center gap-2 px-3 py-1.5 text-sm rounded cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700"
        @mousedown.prevent="pick(org)"
      >
        <span v-if="org.key" class="text-slate-500">{{ org.key }}</span>
        <span class="flex-1 text-slate-800 dark:text-slate-100">
          {{ org.trade_name }}
          <span class="text-xs text-slate-500">{{ org.legal_name }}</span>
        </span>
        <span class="text-xs text-slate-500">
          {{ $t(`CRM_ZEUS.TYPE.${org.organization_type.toUpperCase()}`) }}
        </span>
      </li>
      <li
        v-if="!searching && !results.length"
        class="px-3 py-1.5 text-sm text-slate-500"
      >
        {{ $t('CRM_ZEUS.QUOTE_FORM.ORGANIZATION_NONE') }}
      </li>
    </ul>
  </div>
</template>
