<!--
  Plan-Organizaciones O1 — página de la organización: sus datos, los contactos ligados
  (agregar / quitar), el cambio de etapa (Marcar como cliente / Regresar a prospecto: solo
  cambia la etapa, lo demás queda igual) y la bitácora de quién lo cambió.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import OrganizationsAPI from 'dashboard/api/organizations';
import Spinner from 'shared/components/Spinner.vue';
import ContactPicker from 'dashboard/views/gestorTickets/ContactPicker.vue';
import OrganizationForm from './OrganizationForm.vue';
import OrganizationActivity from './OrganizationActivity.vue';
import {
  formatDate,
  organizationAccess,
  stageChipClass,
} from './organizationHelpers';

export default {
  name: 'OrganizationDetail',
  components: {
    Spinner,
    ContactPicker,
    OrganizationForm,
    OrganizationActivity,
  },
  data() {
    return {
      organization: null,
      loading: true,
      showForm: false,
      picked: null,
      busy: false,
    };
  },
  computed: {
    ...mapGetters({ currentUser: 'getCurrentUser' }),
    access() {
      return organizationAccess(this.currentUser, this.$route.params.accountId);
    },
    organizationId() {
      return Number(this.$route.params.organizationId);
    },
    isCustomer() {
      return this.organization.stage === 'customer';
    },
    rows() {
      const org = this.organization;
      return [
        { key: 'TAX_ID', value: org.tax_id },
        { key: 'INDUSTRY', value: org.industry },
        { key: 'WEBSITE', value: org.website },
        { key: 'EMAIL_DOMAIN', value: org.email_domain },
        { key: 'PHONE', value: org.phone_number },
        { key: 'ADDRESS', value: org.address },
        { key: 'OWNER', value: org.owner && org.owner.name },
        { key: 'PROSPECT_SINCE', value: formatDate(org.became_prospect_at) },
        { key: 'CUSTOMER_SINCE', value: formatDate(org.became_customer_at) },
        { key: 'NOTES', value: org.notes },
      ].filter(row => row.value);
    },
  },
  watch: {
    organizationId: 'fetch',
    // Al elegir un contacto en el buscador, se liga.
    picked(contact) {
      if (contact) this.addContact(contact);
    },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    stageChipClass,
    formatDate,
    async fetch() {
      this.loading = true;
      try {
        const { data } = await OrganizationsAPI.find(this.organizationId);
        this.organization = data.organization;
      } catch {
        this.organization = null;
      } finally {
        this.loading = false;
      }
    },
    async run(request) {
      this.busy = true;
      try {
        const { data } = await request();
        this.organization = data.organization;
        useAlert(this.$t('ORGANIZATIONS.SAVED'));
      } catch (error) {
        useAlert(
          error?.response?.data?.error || this.$t('ORGANIZATIONS.ERROR')
        );
      } finally {
        this.busy = false;
      }
    },
    changeStage() {
      const stage = this.isCustomer ? 'prospect' : 'customer';
      this.run(() => OrganizationsAPI.changeStage(this.organizationId, stage));
    },
    async addContact(contact) {
      await this.run(() =>
        OrganizationsAPI.addContact(this.organizationId, contact.id)
      );
      this.picked = null;
    },
    removeContact(contact) {
      // eslint-disable-next-line no-alert
      const ok = window.confirm(
        this.$t('ORGANIZATIONS.REMOVE_CONTACT_CONFIRM', { name: contact.name })
      );
      if (!ok) return;
      this.run(() =>
        OrganizationsAPI.removeContact(this.organizationId, contact.id)
      );
    },
    contactEventText(event) {
      const d = event.data;
      if (event.action === 'contact_joined') {
        return this.$t(
          d.moved
            ? 'ORGANIZATIONS.EVENTS.JOINED_WITH'
            : 'ORGANIZATIONS.EVENTS.JOINED',
          { contact: d.contact_name, from: d.from }
        );
      }
      const to = d.to || this.$t('ORGANIZATIONS.EVENTS.NOWHERE');
      return d.moved
        ? this.$t('ORGANIZATIONS.EVENTS.LEFT_WITH', {
            contact: d.contact_name,
            to,
          })
        : this.$t('ORGANIZATIONS.EVENTS.LEFT', {
            contact: d.contact_name,
            to,
            replacement: d.replacement_name,
          });
    },
    async destroy() {
      // eslint-disable-next-line no-alert
      if (!window.confirm(this.$t('ORGANIZATIONS.DELETE_CONFIRM'))) return;
      try {
        await OrganizationsAPI.remove(this.organizationId);
        useAlert(this.$t('ORGANIZATIONS.DELETED'));
        this.$router.push({
          name: 'organizations_list',
          params: { accountId: this.$route.params.accountId },
        });
      } catch {
        useAlert(this.$t('ORGANIZATIONS.ERROR'));
      }
    },
    openContact(contact) {
      this.$router.push({
        name: 'contact_profile_dashboard',
        params: {
          accountId: this.$route.params.accountId,
          contactId: contact.id,
        },
      });
    },
    onSaved(organization) {
      this.showForm = false;
      this.organization = { ...this.organization, ...organization };
    },
    // «Pasó de Prospecto a Cliente» o «Se creó como Prospecto», y el motivo si fue automático.
    // «Luis se fue a Globex (sus cosas quedan aquí con Ana)» / «Luis llegó desde Acme».
    eventText(event) {
      const { from, to, reason } = event.data || {};
      if (event.action === 'contact_left' || event.action === 'contact_joined')
        return this.contactEventText(event);
      const text =
        event.action === 'created'
          ? this.$t('ORGANIZATIONS.EVENTS.CREATED', {
              to: this.$t(`ORGANIZATIONS.STAGES.${to}`),
            })
          : this.$t('ORGANIZATIONS.EVENTS.STAGE', {
              from: this.$t(`ORGANIZATIONS.STAGES.${from}`),
              to: this.$t(`ORGANIZATIONS.STAGES.${to}`),
            });
      return reason
        ? `${text} (${this.$t(`ORGANIZATIONS.RULES.REASONS.${reason}`)})`
        : text;
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 w-full h-full overflow-hidden bg-white dark:bg-slate-900"
  >
    <Spinner v-if="loading" class="mt-8" />
    <p
      v-else-if="!organization"
      class="py-12 text-sm text-center text-slate-500 dark:text-slate-400"
    >
      {{ $t('ORGANIZATIONS.NOT_FOUND') }}
    </p>
    <template v-else>
      <header
        class="flex flex-wrap items-start justify-between gap-3 px-6 pt-5 pb-3 border-b border-slate-50 dark:border-slate-800"
      >
        <div>
          <router-link
            :to="{
              name: 'organizations_list',
              params: { accountId: $route.params.accountId },
            }"
            class="inline-flex items-center gap-1 text-xs text-slate-500 hover:underline"
          >
            <fluent-icon icon="chevron-left" size="12" />
            {{ $t('ORGANIZATIONS.TITLE') }}
          </router-link>
          <h1
            class="flex items-center gap-2 m-0 text-xl font-bold text-slate-800 dark:text-slate-100"
          >
            {{ organization.name }}
            <span
              class="px-2 py-0.5 text-xs font-medium rounded-full"
              :class="stageChipClass(organization.stage)"
            >
              {{ $t(`ORGANIZATIONS.STAGES.${organization.stage}`) }}
            </span>
          </h1>
          <p class="m-0 text-sm text-slate-600 dark:text-slate-300">
            {{ $t(`ORGANIZATIONS.KINDS.${organization.kind}`) }}
          </p>
        </div>
        <div v-if="access.canEdit" class="flex items-center gap-2">
          <woot-button
            size="small"
            :color-scheme="isCustomer ? 'secondary' : 'success'"
            :variant="isCustomer ? 'smooth' : 'solid'"
            :is-loading="busy"
            @click="changeStage"
          >
            {{
              isCustomer
                ? $t('ORGANIZATIONS.BACK_TO_PROSPECT')
                : $t('ORGANIZATIONS.MARK_CUSTOMER')
            }}
          </woot-button>
          <woot-button
            size="small"
            variant="smooth"
            color-scheme="secondary"
            icon="edit"
            @click="showForm = true"
          >
            {{ $t('ORGANIZATIONS.EDIT') }}
          </woot-button>
          <woot-button
            size="small"
            variant="clear"
            color-scheme="alert"
            icon="delete"
            :title="$t('ORGANIZATIONS.DELETE')"
            @click="destroy"
          />
        </div>
      </header>

      <div class="flex flex-col flex-1 min-h-0 overflow-y-auto md:flex-row">
        <!-- Datos -->
        <aside
          class="flex-shrink-0 p-4 border-b md:w-80 md:border-b-0 ltr:md:border-r rtl:md:border-l border-slate-50 dark:border-slate-800/50"
        >
          <h3
            class="mb-2 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
          >
            {{ $t('ORGANIZATIONS.DATA') }}
          </h3>
          <dl class="flex flex-col gap-2 m-0">
            <div
              v-for="row in rows"
              :key="row.key"
              class="grid grid-cols-[7.5rem_1fr] gap-2 text-sm"
            >
              <dt class="text-slate-500 dark:text-slate-400">
                {{ $t(`ORGANIZATIONS.FIELDS.${row.key}`) }}
              </dt>
              <dd
                class="m-0 break-words whitespace-pre-line text-slate-800 dark:text-slate-100"
              >
                {{ row.value }}
              </dd>
            </div>
          </dl>
        </aside>

        <main class="flex flex-col flex-1 min-w-0 gap-6 p-4">
          <!-- Contactos ligados -->
          <section>
            <h3
              class="mb-2 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
            >
              {{
                $t('ORGANIZATIONS.CONTACTS', {
                  count: organization.contacts.length,
                })
              }}
            </h3>
            <p
              v-if="!organization.contacts.length"
              class="m-0 mb-2 text-sm text-slate-500"
            >
              {{ $t('ORGANIZATIONS.NO_CONTACTS') }}
            </p>
            <ul class="flex flex-col gap-1 p-0 m-0 mb-3 list-none">
              <li
                v-for="contact in organization.contacts"
                :key="contact.id"
                class="flex items-center gap-2 px-3 py-2 text-sm rounded-md bg-slate-25 dark:bg-slate-800"
              >
                <button
                  type="button"
                  class="p-0 font-medium text-left text-woot-600 dark:text-woot-300 hover:underline"
                  @click="openContact(contact)"
                >
                  {{ contact.name }}
                </button>
                <span class="text-xs text-slate-500 truncate">
                  {{ contact.email || contact.phone_number }}
                </span>
                <woot-button
                  v-if="access.canEdit"
                  class="ml-auto"
                  size="tiny"
                  variant="clear"
                  color-scheme="secondary"
                  icon="dismiss"
                  :title="$t('ORGANIZATIONS.REMOVE_CONTACT')"
                  @click="removeContact(contact)"
                />
              </li>
            </ul>
            <div v-if="access.canEdit" class="max-w-md">
              <span class="text-xs text-slate-500">
                {{ $t('ORGANIZATIONS.ADD_CONTACT') }}
              </span>
              <ContactPicker v-model="picked" />
            </div>
          </section>

          <!-- Plan-Organizaciones O2 — lo de todos sus contactos -->
          <OrganizationActivity :organization-id="organizationId" />

          <!-- Bitácora -->
          <section v-if="organization.events.length">
            <h3
              class="mb-2 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
            >
              {{ $t('ORGANIZATIONS.HISTORY') }}
            </h3>
            <ul class="flex flex-col gap-1 p-0 m-0 text-sm list-none">
              <li
                v-for="event in organization.events"
                :key="event.id"
                class="text-slate-600 dark:text-slate-300"
              >
                <span class="text-xs text-slate-500">
                  {{ formatDate(event.created_at) }}
                </span>
                · {{ eventText(event) }}
                <template v-if="event.user"> · {{ event.user.name }} </template>
              </li>
            </ul>
          </section>
        </main>
      </div>

      <OrganizationForm
        :show="showForm"
        :organization="organization"
        @close="showForm = false"
        @saved="onSaved"
      />
    </template>
  </div>
</template>
