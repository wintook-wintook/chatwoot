<!--
  @tickets_cases — Plan-Casos E2 (alta desde la Lista/Tablero)
  Buscador de cliente (contacto) para el alta de un caso fuera de la conversación.
  v-model = contacto elegido { id, name, email, phone_number, organization_id } o null.
  Con organization-id (Plan-Organizaciones O2) muestra solo los contactos de esa
  organización, sin tener que escribir.
-->
<script>
import ContactAPI from 'dashboard/api/contacts';
import OrganizationsAPI from 'dashboard/api/organizations';

export default {
  name: 'ContactPicker',
  props: {
    value: { type: Object, default: null },
    organizationId: { type: Number, default: null },
  },
  emits: ['input'],
  data() {
    return {
      query: '',
      results: [],
      isSearching: false,
      timer: null,
      organizationContacts: [],
      focused: false,
    };
  },
  computed: {
    // Con organización: sus contactos, filtrados por lo escrito.
    organizationResults() {
      const q = this.query.trim().toLowerCase();
      return this.organizationContacts.filter(contact =>
        [contact.name, contact.email, contact.phone_number]
          .filter(Boolean)
          .some(text => text.toLowerCase().includes(q))
      );
    },
    shownResults() {
      return this.organizationId ? this.organizationResults : this.results;
    },
  },
  watch: {
    organizationId: { immediate: true, handler: 'fetchOrganizationContacts' },
  },
  beforeDestroy() {
    clearTimeout(this.timer);
  },
  methods: {
    async fetchOrganizationContacts() {
      this.organizationContacts = [];
      if (!this.organizationId) return;
      try {
        const { data } = await OrganizationsAPI.find(this.organizationId);
        this.organizationContacts = (data.organization.contacts || []).map(
          contact => ({ ...contact, organization_id: this.organizationId })
        );
      } catch {
        this.organizationContacts = [];
      }
    },
    // Deja que el clic en la lista llegue antes de cerrarla.
    onBlur() {
      setTimeout(() => {
        this.focused = false;
      }, 150);
    },
    onInput() {
      if (this.organizationId) return;
      clearTimeout(this.timer);
      this.timer = setTimeout(this.search, 300);
    },
    async search() {
      const q = this.query.trim();
      if (q.length < 2) {
        this.results = [];
        return;
      }
      this.isSearching = true;
      try {
        const { data } = await ContactAPI.search(encodeURIComponent(q), 1);
        this.results = (data.payload || []).slice(0, 6);
      } catch (_e) {
        this.results = [];
      } finally {
        this.isSearching = false;
      }
    },
    pick(contact) {
      const {
        id,
        name,
        email,
        phone_number: phoneNumber,
        organization_id: organizationId,
      } = contact;
      this.$emit('input', {
        id,
        name,
        email,
        phone_number: phoneNumber,
        organization_id: organizationId || null,
      });
      this.query = '';
      this.results = [];
    },
    detail(contact) {
      return [contact.email, contact.phone_number].filter(Boolean).join(' · ');
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
      <div class="min-w-0">
        <p
          class="m-0 text-sm font-medium truncate text-slate-800 dark:text-slate-100"
        >
          {{ value.name }}
        </p>
        <p
          v-if="detail(value)"
          class="m-0 text-xs truncate text-slate-500 dark:text-slate-400"
        >
          {{ detail(value) }}
        </p>
      </div>
      <woot-button
        size="tiny"
        variant="clear"
        color-scheme="secondary"
        icon="dismiss"
        type="button"
        :title="$t('CASE_TICKETS.CREATE.CHANGE_CONTACT')"
        @click="$emit('input', null)"
      />
    </div>
    <template v-else>
      <input
        v-model="query"
        type="text"
        class="input !mb-0"
        :placeholder="$t('CASE_TICKETS.CREATE.CONTACT_PLACEHOLDER')"
        @input="onInput"
        @focus="focused = true"
        @blur="onBlur"
      />
      <ul
        v-if="
          organizationId
            ? focused
            : results.length || (query.trim().length >= 2 && !isSearching)
        "
        class="absolute left-0 right-0 z-50 py-1 mt-1 overflow-y-auto list-none bg-white border rounded-md shadow-md top-full dark:bg-slate-800 border-slate-100 dark:border-slate-700 max-h-60"
      >
        <li
          v-for="c in shownResults"
          :key="c.id"
          class="px-3 py-2 cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700"
          @click="pick(c)"
        >
          <p class="m-0 text-sm text-slate-800 dark:text-slate-100">
            {{ c.name }}
          </p>
          <p
            v-if="detail(c)"
            class="m-0 text-xs text-slate-500 dark:text-slate-400"
          >
            {{ detail(c) }}
          </p>
        </li>
        <li
          v-if="!shownResults.length"
          class="px-3 py-2 text-sm text-slate-400 dark:text-slate-500"
        >
          {{ $t('CASE_TICKETS.CREATE.NO_CONTACTS') }}
        </li>
      </ul>
    </template>
  </div>
</template>
