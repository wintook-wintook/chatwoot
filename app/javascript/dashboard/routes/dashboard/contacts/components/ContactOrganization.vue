<!--
  Plan-Organizaciones O1 — página del contacto › su organización y etapa. Sin
  organización: «Convertir en prospecto» (la crea con su empresa escrita o su nombre) o
  ligarlo a una que ya existe (lo suyo sin organización pasa a ella). Con organización: el
  enlace a su página, «Cambiar de organización» (ChangeOrganizationModal) y «Quitar»
  (con confirmación).
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import OrganizationsAPI from 'dashboard/api/organizations';
import OrganizationForm from 'dashboard/views/organizations/OrganizationForm.vue';
import ChangeOrganizationModal from './ChangeOrganizationModal.vue';
import {
  organizationAccess,
  stageChipClass,
} from 'dashboard/views/organizations/organizationHelpers';

export default {
  name: 'ContactOrganization',
  components: { OrganizationForm, ChangeOrganizationModal },
  props: {
    contact: { type: Object, required: true },
  },
  data() {
    return {
      organization: null,
      showForm: false,
      showChange: false,
      linking: false,
      query: '',
      results: [],
      timer: null,
    };
  },
  computed: {
    ...mapGetters({ currentUser: 'getCurrentUser' }),
    access() {
      return organizationAccess(this.currentUser, this.$route.params.accountId);
    },
  },
  watch: {
    'contact.organization_id': { immediate: true, handler: 'fetch' },
  },
  beforeDestroy() {
    clearTimeout(this.timer);
  },
  methods: {
    stageChipClass,
    async fetch() {
      const id = this.contact.organization_id;
      if (!id) {
        this.organization = null;
        return;
      }
      try {
        const { data } = await OrganizationsAPI.find(id);
        this.organization = data.organization;
      } catch {
        this.organization = null;
      }
    },
    // La ficha del contacto (y su organization_id) se vuelve a pedir.
    refreshContact() {
      this.$store.dispatch('contacts/show', { id: this.contact.id });
    },
    onSaved() {
      this.showForm = false;
      this.refreshContact();
    },
    onSearch() {
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
    async link(organization) {
      try {
        await OrganizationsAPI.addContact(organization.id, this.contact.id);
        this.linking = false;
        this.query = '';
        this.results = [];
        this.refreshContact();
      } catch {
        useAlert(this.$t('ORGANIZATIONS.ERROR'));
      }
    },
    onChanged() {
      this.showChange = false;
      this.refreshContact();
    },
    async unlink() {
      // eslint-disable-next-line no-alert
      const ok = window.confirm(
        this.$t('ORGANIZATIONS.CONTACT.UNLINK_CONFIRM', {
          name: this.organization.name,
        })
      );
      if (!ok) return;
      try {
        await OrganizationsAPI.removeContact(
          this.organization.id,
          this.contact.id
        );
        this.refreshContact();
      } catch {
        useAlert(this.$t('ORGANIZATIONS.ERROR'));
      }
    },
    open() {
      this.$router.push({
        name: 'organization_detail',
        params: {
          accountId: this.$route.params.accountId,
          organizationId: this.organization.id,
        },
      });
    },
  },
};
</script>

<template>
  <section>
    <h3
      class="mb-2 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
    >
      {{ $t('ORGANIZATIONS.CONTACT.TITLE') }}
    </h3>

    <div v-if="organization" class="flex flex-col gap-1 text-sm">
      <span class="flex items-center gap-2">
        <button
          type="button"
          class="p-0 font-medium text-left text-woot-600 dark:text-woot-300 hover:underline"
          @click="open"
        >
          {{ organization.name }}
        </button>
        <span
          class="px-2 py-0.5 text-xs font-medium rounded-full"
          :class="stageChipClass(organization.stage)"
        >
          {{ $t(`ORGANIZATIONS.STAGES.${organization.stage}`) }}
        </span>
      </span>
      <span class="text-xs text-slate-500">
        {{ $t(`ORGANIZATIONS.KINDS.${organization.kind}`) }}
      </span>
      <div v-if="access.canEdit" class="flex flex-wrap gap-3 mt-1">
        <button
          type="button"
          class="p-0 text-xs text-woot-600 dark:text-woot-300 hover:underline"
          @click="showChange = true"
        >
          {{ $t('ORGANIZATIONS.CONTACT.CHANGE') }}
        </button>
        <button
          type="button"
          class="p-0 text-xs text-slate-500 hover:underline"
          @click="unlink"
        >
          {{ $t('ORGANIZATIONS.CONTACT.UNLINK') }}
        </button>
      </div>
    </div>

    <div v-else class="flex flex-col gap-2 text-sm">
      <p class="m-0 text-slate-500 dark:text-slate-400">
        {{ $t('ORGANIZATIONS.CONTACT.NONE') }}
      </p>
      <template v-if="access.canEdit">
        <woot-button size="small" icon="add" @click="showForm = true">
          {{ $t('ORGANIZATIONS.CONTACT.CONVERT') }}
        </woot-button>
        <button
          v-if="!linking"
          type="button"
          class="self-start p-0 text-xs text-woot-600 dark:text-woot-300 hover:underline"
          @click="linking = true"
        >
          {{ $t('ORGANIZATIONS.CONTACT.LINK_EXISTING') }}
        </button>
        <div v-else class="relative">
          <input
            v-model="query"
            type="search"
            class="!mb-0"
            :placeholder="$t('ORGANIZATIONS.CONTACT.SEARCH')"
            @input="onSearch"
          />
          <ul
            v-if="results.length"
            class="absolute z-10 w-full p-1 m-0 mt-1 list-none bg-white border rounded-md shadow dark:bg-slate-800 border-slate-100 dark:border-slate-700"
          >
            <li v-for="result in results" :key="result.id">
              <button
                type="button"
                class="w-full px-2 py-1 text-sm text-left rounded hover:bg-slate-50 dark:hover:bg-slate-700"
                @click="link(result)"
              >
                {{ result.name }}
                <span class="text-xs text-slate-500">
                  · {{ $t(`ORGANIZATIONS.STAGES.${result.stage}`) }}
                </span>
              </button>
            </li>
          </ul>
        </div>
      </template>
    </div>

    <ChangeOrganizationModal
      v-if="showChange"
      :show="showChange"
      :contact="contact"
      @close="showChange = false"
      @changed="onChanged"
    />
    <OrganizationForm
      :show="showForm"
      :contact="contact"
      @close="showForm = false"
      @saved="onSaved"
    />
  </section>
</template>
