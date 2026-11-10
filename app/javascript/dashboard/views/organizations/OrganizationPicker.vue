<!--
  Plan-Organizaciones O2 — buscador de organización para los formularios que piden
  cliente. v-model = { id, name, stage } o null. Al elegirla, el buscador de contacto
  muestra solo sus contactos (ContactPicker :organization-id).
-->
<script>
import OrganizationsAPI from 'dashboard/api/organizations';

export default {
  name: 'OrganizationPicker',
  props: {
    value: { type: Object, default: null },
  },
  emits: ['input'],
  data() {
    return { query: '', results: [], timer: null };
  },
  beforeDestroy() {
    clearTimeout(this.timer);
  },
  methods: {
    onInput() {
      clearTimeout(this.timer);
      this.timer = setTimeout(this.search, 300);
    },
    async search() {
      const q = this.query.trim();
      if (q.length < 2) {
        this.results = [];
        return;
      }
      try {
        const { data } = await OrganizationsAPI.list({ q, stage: '' });
        this.results = (data.organizations || []).slice(0, 6);
      } catch {
        this.results = [];
      }
    },
    pick(organization) {
      const { id, name, stage } = organization;
      this.$emit('input', { id, name, stage });
      this.query = '';
      this.results = [];
    },
  },
};
</script>

<template>
  <div class="relative">
    <div
      v-if="value"
      class="flex items-center justify-between gap-2 px-3 py-2 border rounded-lg border-slate-100 dark:border-slate-700 bg-slate-25 dark:bg-slate-800"
    >
      <span
        class="text-sm font-medium truncate text-slate-800 dark:text-slate-100"
      >
        {{ value.name }}
        <span v-if="value.stage" class="text-xs font-normal text-slate-500">
          · {{ $t(`ORGANIZATIONS.STAGES.${value.stage}`) }}
        </span>
      </span>
      <woot-button
        size="tiny"
        variant="clear"
        color-scheme="secondary"
        icon="dismiss"
        type="button"
        :title="$t('ORGANIZATIONS.PICKER.CLEAR')"
        @click="$emit('input', null)"
      />
    </div>
    <template v-else>
      <input
        v-model="query"
        type="text"
        class="input !mb-0"
        :placeholder="$t('ORGANIZATIONS.PICKER.PLACEHOLDER')"
        @input="onInput"
      />
      <ul
        v-if="results.length"
        class="absolute left-0 right-0 z-50 py-1 mt-1 overflow-y-auto list-none bg-white border rounded-md shadow-md top-full dark:bg-slate-800 border-slate-100 dark:border-slate-700 max-h-60"
      >
        <li
          v-for="organization in results"
          :key="organization.id"
          class="px-3 py-2 text-sm cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700"
          @click="pick(organization)"
        >
          {{ organization.name }}
          <span class="text-xs text-slate-500">
            · {{ $t(`ORGANIZATIONS.STAGES.${organization.stage}`) }}
          </span>
        </li>
      </ul>
    </template>
  </div>
</template>
