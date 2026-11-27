<!--
  CrmZeus C2 — pestaña «Contactos»: contactos de Wintook ligados a la organización.
  Se busca un contacto existente y se liga; desligar no lo borra de Wintook. Un contacto
  que ya está en otra organización aparece deshabilitado con el nombre de esa organización.
-->
<script>
import { useAlert } from 'dashboard/composables';
import CrmOrganizations from 'dashboard/api/crmOrganizations';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import { errorMessage } from './crmHelpers';

export default {
  name: 'CrmContactsPanel',
  components: { Thumbnail },
  props: {
    organizationId: { type: [Number, String], required: true },
    canEdit: { type: Boolean, default: false },
  },
  data() {
    return {
      contacts: [],
      loading: true,
      query: '',
      results: [],
      open: false,
      searching: false,
      debounce: null,
      linking: false,
      toUnlink: null,
    };
  },
  mounted() {
    this.fetch();
  },
  beforeDestroy() {
    clearTimeout(this.debounce);
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await CrmOrganizations.contacts(this.organizationId);
        this.contacts = data.contacts;
      } finally {
        this.loading = false;
      }
    },
    contactRoute(contact) {
      return {
        name: 'contact_profile_dashboard',
        params: {
          accountId: this.$route.params.accountId,
          contactId: contact.id,
        },
      };
    },
    details(contact) {
      return [contact.email, contact.phone_number].filter(Boolean).join(' · ');
    },
    // En esta organización, en otra, o libre para ligar.
    linkedElsewhere(result) {
      const org = result.crm_organization;
      return org && String(org.id) !== String(this.organizationId) ? org : null;
    },
    alreadyHere(result) {
      const org = result.crm_organization;
      return !!org && String(org.id) === String(this.organizationId);
    },
    onInput() {
      this.open = true;
      clearTimeout(this.debounce);
      this.debounce = setTimeout(this.search, 300);
    },
    async search() {
      const q = this.query.trim();
      if (!q) {
        this.results = [];
        return;
      }
      this.searching = true;
      try {
        const { data } = await CrmOrganizations.searchContacts(
          this.organizationId,
          q
        );
        this.results = data.contacts;
      } finally {
        this.searching = false;
      }
    },
    closeResults() {
      // Deja tiempo al clic de un resultado antes de cerrar la lista.
      setTimeout(() => {
        this.open = false;
      }, 200);
    },
    async link(result) {
      if (
        this.linking ||
        this.linkedElsewhere(result) ||
        this.alreadyHere(result)
      )
        return;
      this.linking = true;
      try {
        await CrmOrganizations.linkContact(this.organizationId, result.id);
        useAlert(this.$t('CRM_ZEUS.CONTACTS.LINKED', { name: result.name }));
        this.query = '';
        this.results = [];
        this.open = false;
        this.fetch();
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      } finally {
        this.linking = false;
      }
    },
    async unlink(contact) {
      this.toUnlink = contact;
      const confirmed = await this.$refs.unlinkDialog.showConfirmation();
      this.toUnlink = null;
      if (!confirmed) return;
      try {
        await CrmOrganizations.unlinkContact(this.organizationId, contact.id);
        this.fetch();
      } catch (error) {
        useAlert(errorMessage(error, this.$t('CRM_ZEUS.ERROR')));
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
      {{ $t('CRM_ZEUS.CONTACTS.HINT') }}
    </p>

    <div v-if="canEdit" class="relative w-full">
      <input
        v-model="query"
        type="search"
        class="!mb-0 !w-full"
        :placeholder="$t('CRM_ZEUS.CONTACTS.SEARCH')"
        @input="onInput"
        @focus="open = true"
        @blur="closeResults"
      />
      <ul
        v-if="open && query.trim()"
        class="absolute z-20 w-full p-1 mt-1 overflow-auto bg-white border rounded-md shadow-lg max-h-72 dark:bg-slate-800 border-slate-100 dark:border-slate-700"
      >
        <li
          v-for="result in results"
          :key="result.id"
          class="flex items-center gap-2 px-3 py-1.5 text-sm rounded"
          :class="
            linkedElsewhere(result) || alreadyHere(result)
              ? 'opacity-60 cursor-not-allowed'
              : 'cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-700'
          "
          @mousedown.prevent="link(result)"
        >
          <Thumbnail
            :src="result.thumbnail"
            :username="result.name"
            size="24px"
          />
          <span class="flex flex-col flex-1 min-w-0">
            <span class="truncate text-slate-800 dark:text-slate-100">
              {{ result.name }}
            </span>
            <span class="text-xs truncate text-slate-500">
              {{ details(result) }}
            </span>
          </span>
          <span
            v-if="alreadyHere(result)"
            class="text-xs text-slate-500 whitespace-nowrap"
          >
            {{ $t('CRM_ZEUS.CONTACTS.ALREADY_HERE') }}
          </span>
          <span
            v-else-if="linkedElsewhere(result)"
            class="text-xs text-slate-500 whitespace-nowrap"
          >
            {{
              $t('CRM_ZEUS.CONTACTS.IN_OTHER', {
                name: linkedElsewhere(result).trade_name,
              })
            }}
          </span>
        </li>
        <li v-if="searching" class="px-3 py-1.5 text-sm text-slate-500">
          {{ $t('CRM_ZEUS.LOADING') }}
        </li>
        <li
          v-else-if="!results.length"
          class="px-3 py-1.5 text-sm text-slate-500"
        >
          {{ $t('CRM_ZEUS.CONTACTS.NONE_FOUND') }}
        </li>
      </ul>
    </div>

    <p v-if="loading" class="text-sm text-slate-500">
      {{ $t('CRM_ZEUS.LOADING') }}
    </p>
    <p
      v-else-if="!contacts.length"
      class="py-6 text-sm text-center text-slate-500"
    >
      {{ $t('CRM_ZEUS.CONTACTS.EMPTY') }}
    </p>
    <table v-else class="w-full text-sm">
      <thead>
        <tr class="text-left border-b text-slate-500 border-slate-50">
          <th class="px-3 py-2 font-medium">
            {{ $t('CRM_ZEUS.CONTACTS.COLUMNS.NAME') }}
          </th>
          <th class="px-3 py-2 font-medium">
            {{ $t('CRM_ZEUS.CONTACTS.COLUMNS.EMAIL') }}
          </th>
          <th class="px-3 py-2 font-medium">
            {{ $t('CRM_ZEUS.CONTACTS.COLUMNS.PHONE') }}
          </th>
          <th class="px-3 py-2 font-medium" />
        </tr>
      </thead>
      <tbody class="divide-y divide-slate-50 dark:divide-slate-800">
        <tr v-for="contact in contacts" :key="contact.id">
          <td class="px-3 py-2">
            <router-link
              :to="contactRoute(contact)"
              class="flex items-center gap-2 font-medium text-slate-800 dark:text-slate-100 hover:underline"
            >
              <Thumbnail
                :src="contact.thumbnail"
                :username="contact.name"
                size="28px"
              />
              {{ contact.name || '—' }}
            </router-link>
          </td>
          <td class="px-3 py-2">{{ contact.email || '—' }}</td>
          <td class="px-3 py-2">{{ contact.phone_number || '—' }}</td>
          <td class="px-3 py-2 text-right">
            <woot-button
              v-if="canEdit"
              size="tiny"
              variant="clear"
              color-scheme="alert"
              icon="dismiss"
              :title="$t('CRM_ZEUS.CONTACTS.UNLINK')"
              @click="unlink(contact)"
            />
          </td>
        </tr>
      </tbody>
    </table>

    <woot-confirm-modal
      ref="unlinkDialog"
      :title="$t('CRM_ZEUS.CONTACTS.UNLINK_TITLE')"
      :description="
        $t('CRM_ZEUS.CONTACTS.CONFIRM_UNLINK', {
          name: toUnlink ? toUnlink.name : '',
        })
      "
      :confirm-label="$t('CRM_ZEUS.CONTACTS.UNLINK')"
      :cancel-label="$t('CRM_ZEUS.CANCEL')"
    />
  </div>
</template>
