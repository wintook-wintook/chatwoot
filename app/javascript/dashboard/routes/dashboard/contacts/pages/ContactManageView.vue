<!--
  Página del contacto (reacomodo 2026-10-24): a lo ancho en vez de una columna.
    · Encabezado: nombre, medios de contacto, responsable fijo, etiquetas y
      acciones con nombre (ContactInfo con layout="header").
    · Columna «Datos»: datos fijos y atributos personalizados, siempre a la vista.
    · Pestañas: Resumen · Conversaciones · Casos · Tareas · Equipos · Notas (la
      elegida queda en la dirección, ?tab=). Casos, Tareas y Equipos solo con
      case_management (Equipos: Plan-Trabajo-Campo R4).
  En pantallas angostas las tres partes quedan una debajo de otra.
-->
<script>
import { mapGetters } from 'vuex';
import ContactInfo from 'dashboard/routes/dashboard/conversation/contact/ContactInfo.vue';
import ContactConversations from 'dashboard/routes/dashboard/conversation/ContactConversations.vue';
import ContactNotes from 'dashboard/modules/notes/NotesOnContactPage.vue';
import SettingsHeader from '../../settings/SettingsHeader.vue';
import Spinner from 'shared/components/Spinner.vue';
import ContactDataColumn from '../components/ContactDataColumn.vue';
import ContactSummaryTab from '../components/ContactSummaryTab.vue';
import ContactCasesTab from '../components/ContactCasesTab.vue';
import ContactTasksTab from '../components/ContactTasksTab.vue';
import ContactAssetsTab from '../components/ContactAssetsTab.vue';
import ContactQuotesTab from '../components/ContactQuotesTab.vue';
import ContactContractsTab from '../components/ContactContractsTab.vue'; // Plan-Contratos R1
import ContactEventsTab from '../components/ContactEventsTab.vue'; // Plan-Eventos E1
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

const CASE_TABS = ['cases', 'quotes', 'tasks', 'assets'];

export default {
  components: {
    ContactInfo,
    ContactConversations,
    ContactNotes,
    SettingsHeader,
    Spinner,
    ContactDataColumn,
    ContactSummaryTab,
    ContactCasesTab,
    ContactTasksTab,
    ContactAssetsTab,
    ContactQuotesTab,
    ContactContractsTab,
    ContactEventsTab,
  },
  // Si se llegó desde otra pantalla de la app, «Regresar» vuelve ahí (con sus
  // filtros); abierto directo (enlace, pestaña nueva) va a la lista de contactos.
  beforeRouteEnter(to, from, next) {
    next(vm => {
      vm.cameFromApp = !!from.name;
    });
  },
  props: {
    contactId: {
      type: [String, Number],
      required: true,
    },
  },
  data() {
    return { cameFromApp: false };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'contacts/getUIFlags',
      accountId: 'getCurrentAccountId',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
    }),
    hasCases() {
      return this.isFeatureEnabledonAccount(
        this.accountId,
        FEATURE_FLAGS.CASE_MANAGEMENT
      );
    },
    tabs() {
      return [
        'summary',
        'conversations',
        'cases',
        'quotes',
        'tasks',
        'assets',
        'contracts',
        'events',
        'notes',
      ]
        .filter(key => this.hasCases || !CASE_TABS.includes(key))
        .map(key => ({
          key,
          name: this.$t(`CONTACT_PAGE.TABS.${key.toUpperCase()}`),
        }));
    },
    activeTab() {
      const { tab } = this.$route.query;
      return this.tabs.some(t => t.key === tab) ? tab : 'summary';
    },
    activeTabIndex() {
      return this.tabs.findIndex(t => t.key === this.activeTab);
    },
    contact() {
      return this.$store.getters['contacts/getContact'](this.contactId);
    },
    numericContactId() {
      return Number(this.contactId);
    },
    // '' = BackButton regresa con el historial.
    backUrl() {
      if (this.cameFromApp) return '';
      return `/app/accounts/${this.$route.params.accountId}/contacts`;
    },
    backLabel() {
      return this.cameFromApp
        ? this.$t('CONTACT_PAGE.BACK')
        : this.$t('CONTACT_PROFILE.BACK_BUTTON');
    },
  },
  mounted() {
    this.fetchContactDetails();
  },
  methods: {
    onClickTabChange(index) {
      this.openTab(this.tabs[index].key);
    },
    openTab(key) {
      if (key === this.activeTab) return;
      this.$router.replace({ query: { ...this.$route.query, tab: key } });
    },
    fetchContactDetails() {
      const { contactId: id } = this;
      this.$store.dispatch('contacts/show', { id });
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 h-full m-0 overflow-hidden bg-white dark:bg-slate-900"
  >
    <SettingsHeader
      button-route="new"
      header-title=""
      show-back-button
      :back-button-label="backLabel"
      :back-url="backUrl"
      :show-new-button="false"
    />

    <div v-if="uiFlags.isFetchingItem" class="h-full p-4 text-base text-center">
      <Spinner size="" />
      <span>{{ $t('CONTACT_PROFILE.LOADING') }}</span>
    </div>
    <div
      v-else-if="contact.id"
      class="flex flex-col flex-1 min-h-0 overflow-y-auto md:overflow-hidden"
    >
      <ContactInfo
        layout="header"
        :contact="contact"
        :show-close-button="false"
        conversation-id=""
      />
      <div class="flex flex-col flex-1 min-h-0 md:flex-row">
        <aside
          class="flex-shrink-0 border-b md:w-80 md:overflow-y-auto md:border-b-0 ltr:md:border-r rtl:md:border-l border-slate-50 dark:border-slate-800/50"
        >
          <ContactDataColumn :contact="contact" />
        </aside>
        <main class="flex flex-col flex-1 min-w-0 min-h-0">
          <woot-tabs
            :index="activeTabIndex"
            class="px-4"
            @change="onClickTabChange"
          >
            <woot-tabs-item
              v-for="tab in tabs"
              :key="tab.key"
              :name="tab.name"
              :show-badge="false"
            />
          </woot-tabs>
          <div
            class="flex-1 p-4 md:overflow-y-auto bg-slate-25 dark:bg-slate-800"
          >
            <ContactSummaryTab
              v-if="activeTab === 'summary'"
              :contact-id="numericContactId"
              @openTab="openTab"
            />
            <ContactConversations
              v-else-if="activeTab === 'conversations'"
              :contact-id="numericContactId"
              conversation-id=""
            />
            <ContactCasesTab
              v-else-if="activeTab === 'cases'"
              :contact-id="numericContactId"
            />
            <ContactQuotesTab
              v-else-if="activeTab === 'quotes'"
              :contact-id="numericContactId"
            />
            <ContactTasksTab
              v-else-if="activeTab === 'tasks'"
              :contact-id="numericContactId"
            />
            <ContactAssetsTab
              v-else-if="activeTab === 'assets'"
              :contact-id="numericContactId"
            />
            <ContactContractsTab
              v-else-if="activeTab === 'contracts'"
              :contact-id="numericContactId"
            />
            <ContactEventsTab
              v-else-if="activeTab === 'events'"
              :contact-id="numericContactId"
            />
            <ContactNotes v-else :contact-id="numericContactId" />
          </div>
        </main>
      </div>
    </div>
  </div>
</template>
