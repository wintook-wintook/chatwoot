<!--
  Accesos rápidos — buscar un contacto o una organización desde cualquier pantalla y
  abrir su ficha. Si el rol no deja ver una de las dos listas, muestra la otra.
-->
<script>
import ContactAPI from 'dashboard/api/contacts';
import OrganizationsAPI from 'dashboard/api/organizations';

const MIN_CHARS = 2;
const MAX_RESULTS = 8;
const DEBOUNCE_MS = 300;

export default {
  name: 'QuickSearchModal',
  props: {
    show: { type: Boolean, default: false },
  },
  emits: ['close'],
  data() {
    return {
      query: '',
      contacts: [],
      organizations: [],
      searching: false,
      searched: false,
      timer: null,
    };
  },
  computed: {
    hasResults() {
      return this.contacts.length > 0 || this.organizations.length > 0;
    },
    // Enter abre el primero de la lista.
    first() {
      return this.contacts[0] || this.organizations[0] || null;
    },
  },
  watch: {
    show(open) {
      if (!open) return;
      this.reset();
      this.$nextTick(() => this.$refs.input?.focus());
    },
  },
  beforeDestroy() {
    clearTimeout(this.timer);
  },
  methods: {
    reset() {
      this.query = '';
      this.contacts = [];
      this.organizations = [];
      this.searched = false;
    },
    onInput() {
      clearTimeout(this.timer);
      this.timer = setTimeout(this.search, DEBOUNCE_MS);
    },
    async search() {
      const q = this.query.trim();
      if (q.length < MIN_CHARS) {
        this.contacts = [];
        this.organizations = [];
        this.searched = false;
        this.searching = false;
        return;
      }
      this.searching = true;
      const [contacts, organizations] = await Promise.allSettled([
        ContactAPI.search(encodeURIComponent(q), 1),
        OrganizationsAPI.list({ q, stage: '' }),
      ]);
      // Una respuesta vieja no pisa a la del texto actual.
      if (q !== this.query.trim()) return;
      this.contacts =
        contacts.status === 'fulfilled'
          ? (contacts.value.data.payload || []).slice(0, MAX_RESULTS)
          : [];
      this.organizations =
        organizations.status === 'fulfilled'
          ? (organizations.value.data.organizations || []).slice(0, MAX_RESULTS)
          : [];
      this.searching = false;
      this.searched = true;
    },
    openContact(contact) {
      this.go('contact_profile_dashboard', { contactId: contact.id });
    },
    openOrganization(organization) {
      this.go('organization_detail', { organizationId: organization.id });
    },
    go(name, params) {
      this.$emit('close');
      this.$router.push({
        name,
        params: { accountId: this.$route.params.accountId, ...params },
      });
    },
    openFirst() {
      if (!this.first) return;
      if (this.contacts.length) this.openContact(this.first);
      else this.openOrganization(this.first);
    },
    contactDetail(contact) {
      return contact.phone_number || contact.email || '';
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')">
    <woot-modal-header :header-title="$t('QUICK_ACTIONS.SEARCH.TITLE')" />
    <div class="px-6 pb-6 space-y-3">
      <input
        ref="input"
        v-model="query"
        type="search"
        class="!mb-0"
        :aria-label="$t('QUICK_ACTIONS.SEARCH.TITLE')"
        :placeholder="$t('QUICK_ACTIONS.SEARCH.PLACEHOLDER')"
        @input="onInput"
        @keydown.enter.prevent="openFirst"
      />
      <p
        v-if="searching"
        class="m-0 text-sm text-slate-500 dark:text-slate-400"
      >
        {{ $t('QUICK_ACTIONS.SEARCH.SEARCHING') }}
      </p>
      <p
        v-else-if="searched && !hasResults"
        class="m-0 text-sm text-slate-500 dark:text-slate-400"
      >
        {{ $t('QUICK_ACTIONS.SEARCH.EMPTY') }}
      </p>
      <section v-if="contacts.length">
        <h4
          class="m-0 mb-1 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
        >
          {{ $t('QUICK_ACTIONS.SEARCH.CONTACTS') }}
        </h4>
        <button
          v-for="contact in contacts"
          :key="contact.id"
          type="button"
          class="flex items-center justify-between w-full gap-3 px-2 py-2 text-sm text-left rounded-md hover:bg-slate-50 dark:hover:bg-slate-700"
          @click="openContact(contact)"
        >
          <span class="truncate text-slate-800 dark:text-slate-100">
            {{ contact.name }}
          </span>
          <span class="text-xs truncate text-slate-500 dark:text-slate-400">
            {{ contactDetail(contact) }}
          </span>
        </button>
      </section>
      <section v-if="organizations.length">
        <h4
          class="m-0 mb-1 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
        >
          {{ $t('QUICK_ACTIONS.SEARCH.ORGANIZATIONS') }}
        </h4>
        <button
          v-for="organization in organizations"
          :key="organization.id"
          type="button"
          class="block w-full px-2 py-2 text-sm text-left truncate rounded-md text-slate-800 dark:text-slate-100 hover:bg-slate-50 dark:hover:bg-slate-700"
          @click="openOrganization(organization)"
        >
          {{ organization.name }}
        </button>
      </section>
    </div>
  </woot-modal>
</template>
