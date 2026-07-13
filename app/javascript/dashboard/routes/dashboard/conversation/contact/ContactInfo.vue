<!-- DEV0002 -->
<!-- app/javascript/dashboard/routes/dashboard/conversation/contact/ContactInfo.vue -->
<!--
  ============================================================
  proyecto@contacts_notes
  ============================================================
  Archivo: ContactInfo.vue
  Descripción: Info del contacto en panel de conversación.
               Modificado: import + registro de ContactNotesCrudModal,
               estado showNotesCrudModal, botón "Notes" (warning/note icon),
               renderizado del modal al pie del template.
  ============================================================
-->
<script>
/* eslint no-console: ["error", { allow: ["log","warn", "error"] }] */
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { useAdmin } from 'dashboard/composables/useAdmin';
import ContactInfoRow from './ContactInfoRow.vue';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import SocialIcons from './SocialIcons.vue';
import EditContact from './EditContact.vue';
import NewConversation from './NewConversation.vue';
import NewPrivateConversation from './NewPrivateConversation.vue'; // proyecto@conversation_private
import NewConversationFromContacts from './NewConversationFromContacts.vue'; // proyecto@conversation_private
import ContactMergeModal from 'dashboard/modules/contact/ContactMergeModal.vue';
import ContactNotesCrudModal from './ContactNotesCrudModal.vue'; // proyecto@contacts_notes
import { getCountryFlag } from 'dashboard/helper/flag';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import {
  isAConversationRoute,
  isAInboxViewRoute,
  getConversationDashboardRoute,
} from '../../../../helper/routeHelpers';

import Synchronizer from './Synchronizer';
import ScheduleMessageModal from 'dashboard/components/widgets/conversation/ScheduleMessageModal';
import CreateEventModal from 'dashboard/components/GoogleCalendar/CreateEventModal.vue'; // google_calendar
import { FEATURE_FLAGS } from 'dashboard/featureFlags'; // google_calendar

export default {
  components: {
    ContactInfoRow,
    EditContact,
    Thumbnail,
    SocialIcons,
    NewConversation,
    NewPrivateConversation,
    NewConversationFromContacts,
    ContactMergeModal,
    ContactNotesCrudModal, // proyecto@contacts_notes
    ScheduleMessageModal,
    CreateEventModal, // google_calendar
  },

  mixins: [Synchronizer],
  props: {
    contact: {
      type: Object,
      default: () => ({}),
    },
    showAvatar: {
      type: Boolean,
      default: true,
    },
    showCloseButton: {
      type: Boolean,
      default: true,
    },
    closeIconName: {
      type: String,
      default: 'chevron-right',
    },
    conversationId: {
      type: [Number, String],
      required: true,
    },
    showAlert: {
      type: Boolean,
      default: false,
    },
  },
  setup() {
    const { isAdmin } = useAdmin();
    return {
      isAdmin,
    };
  },
  data() {
    return {
      showEditModal: false,
      showConversationModal: false,
      showMergeModal: false,
      showDeleteModal: false,
      showNotesCrudModal: false, // proyecto@contacts_notes
      showCreateEventModal: false, // google_calendar
      crmContact: {},
      showScheduleModal: false,
      showPrivateConversationModal: false, // proyecto@conversation_private
      showNewConversationFromContacts: false, // proyecto@conversation_private
      contactFoundInCRM: false,
      isInitializing: false,
      suppressAlerts: false, // ← NUEVO: Flag para suprimir alertas
      // kanbanTypeProcess: 0,
    };
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
      uiFlags: 'contacts/getUIFlags',
      currentChat: 'getSelectedChat',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      accountId: 'getCurrentAccountId',
    }),

    // Estos se actualizarán automáticamente cuando el store cambie
    integrations() {
      return this.$store.getters['integrations/getAppIntegrations'];
    },
    crmzeusIntegration() {
      return this.integrations.find(integration => integration.id === 'crmzeus');
    },
    isIntegrationEnabled() {
      return this.crmzeusIntegration?.enabled || false;
    },

    contactProfileLink() {
      return `/app/accounts/${this.$route.params.accountId}/contacts/${this.contact.id}`;
    },
    additionalAttributes() {
      return this.contact.additional_attributes || {};
    },
    idContactoCRMzeus() {
      const { custom_attributes = {} } = this.contact || {};
      const { idcontacto_crmzeus = 0 } = custom_attributes;
      return `Contacto CRMZeus: ${idcontacto_crmzeus}`;
    },
    idOrganizacionCRMzeus() {
      const { custom_attributes = {} } = this.contact || {};
      const { idorganizacion_crmzeus = 0 } = custom_attributes;
      return `Organizacion CRMZeus: ${idorganizacion_crmzeus}`;
    },
    location() {
      const {
        country = '',
        city = '',
        country_code: countryCode,
      } = this.additionalAttributes;
      const cityAndCountry = [city, country].filter(item => !!item).join(', ');

      if (!cityAndCountry) {
        return '';
      }
      return this.findCountryFlag(countryCode, cityAndCountry);
    },
    socialProfiles() {
      const {
        social_profiles: socialProfiles,
        screen_name: twitterScreenName,
      } = this.additionalAttributes;

      return {
        twitter: twitterScreenName,
        phone: this.contact.phone_number,
        ...(socialProfiles || {}),
      };
    },
    confirmDeleteMessage() {
      return ` ${this.contact.name}?`;
    },
    // Verificar si el contacto está sincronizado
    isSynchronized() {
      const { custom_attributes = {} } = this.contact || {};
      const { idcontacto_crmzeus = 0, idorganizacion_crmzeus = 0 } =
        custom_attributes;
      return idcontacto_crmzeus > 0 && idorganizacion_crmzeus > 0;
    },
    // google_calendar
    showCalendarButton() {
      return !!(
        this.conversationId &&
        this.isFeatureEnabledonAccount(this.accountId, FEATURE_FLAGS.GOOGLE_CALENDAR)
      );
    },
    calendarPrefillEmail() {
      return this.contact?.email || '';
    },
  },
  watch: {
    async contact() {
      this.initializeContactData(); //Sincronizador
      // const kanbanInfo = await this.$store.dispatch(
      //   'kanbanTypeProcesses/getConversationKanbanInfo',
      //   this.currentChat.id
      // );
      // this.kanbanTypeProcess = kanbanInfo.kanban_type_process_id || 0;
      // console.log(`this.kanbanTypeProcess ???? ${this.kanbanTypeProcess}`)
    }
  },
  async mounted() {
    // Primero ejecuta la acción y espera a que termine
    // await this.$store.dispatch('integrations/get');

    // // Ahora obtén los datos actualizados
    // const integrationCRMZeus = this.$store.getters['integrations/getAppIntegrations'];
    // console.log(`integrationCRMZeus`)
    // console.log(integrationCRMZeus)

    // 1. Cargar datos del servidor
    await this.$store.dispatch('integrations/get');

    // 2. Ahora los computed ya tienen los datos actualizados
    console.log('Integraciones cargadas:', this.integrations);
    console.log('CRMZeus encontrado:', this.crmzeusIntegration);
    console.log('¿Está habilitado?:', this.isIntegrationEnabled);
  },
  methods: {
    dynamicTime,
    async testGetConversation() {
      try {
        // const result = await this.$store.dispatch('conversations/getConversation', 8);
        // console.log('Resultado de getConversation:', result);

        // Después de cargar, verificar si ya está en el store
        console.log('Conversaciones en store después de cargar:');
        this.$store.state.conversations.allConversations.forEach(conv => {
          console.log(`ID: ${conv.id}, Display ID: ${conv.display_id}`);
        });

        // Verificar la conversación específica
        const conv = this.$store.state.conversations.allConversations.find(c => c.display_id === 8);
        console.log('Conversación display_id 8 después de cargar:', conv);

      } catch (error) {
        console.error('Error en getConversation:', error);
      }
    },
    handleSuppressAlerts(suppress) {
      this.suppressAlerts = suppress;
      // console.log(`Alertas ${suppress ? 'suprimidas' : 'reactivadas'}`);
    },
    async initializeContactData() {
      console.log("suppressAlerts", this.suppressAlerts)
      try {
        if (this.isInitializing)
          return;
        this.isInitializing = true;
        console.log('Inicializando datos del contacto...');
        if (!this.contact) {
          if (this.showAlert && !this.suppressAlerts) {
            console.warn('No hay contacto disponible para inicializar');
            useAlert(this.$t('CONTACT.ERRORS.NO_CONTACT_AVAILABLE'));
          }
          this.crmContact = {};
          return;
        }
        if (!this.integration?.enabled) {
          console.log('Sin integración habilitada');
          this.crmContact = {};
          return;
        }

        // const valuesByPhone  = await this.searchContactCRMZeusByPhone(this.contact);
        // console.log("valuesByPhone", valuesByPhone)

        // Caso 1: Contacto sincronizado - buscar por ID
        if (this.isSynchronized) {
          const dataContactId = await this.searchContactCRMZeusById(this.contact)
          this.contactFoundInCRM = dataContactId.success;
          this.crmContact = dataContactId.data

          console.log("isSynchronized")
          console.log("dataContactId")
          console.log(dataContactId)

          console.log("this.contactFoundInCRM")
          console.log(this.contactFoundInCRM)

          console.log("this.crmContact")
          console.log(this.crmContact)

          if (dataContactId.success) {
            if (this.showAlert && !this.suppressAlerts) {
              useAlert(dataContactId.message, 'success');
              useAlert(this.$t('CONTACT.SUCCESS.FOUND_IN_CRM'), 'success');
            }
            return;
          }
          if (!dataContactId.success) {
            useAlert(dataContactId.message, 'success');
            const dataContactPhone = await this.searchContactCRMZeusByPhone(this.contact)
            if (dataContactPhone.success) {
              this.contactFoundInCRM = dataContactPhone.success;
              this.crmContact = dataContactPhone.data
              if (this.showAlert && !this.suppressAlerts) {
                useAlert(dataContactPhone.message, 'success');
                useAlert(this.$t('CONTACT.SUCCESS.FOUND_IN_CRM'), 'success');
              }
              return;
            }
            const dataContactEmail = await this.searchContactCRMZeusByEmail(this.contact)
            if (dataContactEmail.success) {
              this.contactFoundInCRM = dataContactEmail.success;
              this.crmContact = dataContactEmail.data
              if (this.showAlert && !this.suppressAlerts) {
                useAlert(dataContactEmail.message, 'success');
                useAlert(this.$t('CONTACT.SUCCESS.FOUND_IN_CRM'), 'success');
              }
              return;
            }
          }
          return;
        }

        const dataContactPhone_ = await this.searchContactCRMZeusByPhone(this.contact)
        if (dataContactPhone_.success) {
          this.contactFoundInCRM = dataContactPhone_.success;
          this.crmContact = dataContactPhone_.data
          console.log("dataContactPhone_")
          console.log(dataContactPhone_)
          return;
        }
        const dataContactEmail_ = await this.searchContactCRMZeusByEmail(this.contact)
        if (dataContactEmail_.success) {
          this.contactFoundInCRM = dataContactEmail_.success;
          this.crmContact = dataContactEmail_.data
          console.log("dataContactEmail_")
          console.log(dataContactPhone_)
          return;
        }

      } catch (error) {
        console.error('Error al inicializar datos del contacto:', error);
        this.crmContact = {};
        useAlert(this.$t('CONTACT.ERRORS.INITIALIZATION_FAILED'));
      } finally {
        this.isInitializing = false; // Siempre restablecer el flag
        // this.crmContact = {};
      }
    },

    // Método auxiliar para validar si el contacto es válido
    isValidContact(contact) {
      return (
        contact &&
        typeof contact === 'object' &&
        Object.keys(contact).length > 0
      ); // o cualquier campo que consideres esencial
    },





    // Modificar para pasar el estado de contactFoundInCRM
    toggleEditModal() {
      this.showEditModal = !this.showEditModal;
    },
    toggleMergeModal() {
      this.showMergeModal = !this.showMergeModal;
    },
    onPanelToggle() {
      this.$emit('togglePanel');
    },
    toggleConversationModal() {
      this.showConversationModal = !this.showConversationModal;
      this.$emitter.emit(
        BUS_EVENTS.NEW_CONVERSATION_MODAL,
        this.showConversationModal
      );
    },
    // proyecto@conversation_private - abre/cierra modal de conversación privada desde contactos
    togglePrivateConversationModal() {
      this.showPrivateConversationModal = !this.showPrivateConversationModal;
    },
    toggleDeleteModal() {
      this.showDeleteModal = !this.showDeleteModal;
    },
    confirmDeletion() {
      this.deleteContact(this.contact);
      this.closeDelete();
    },
    closeDelete() {
      this.showDeleteModal = false;
      this.showConversationModal = false;
      this.showEditModal = false;
    },
    findCountryFlag(countryCode, cityAndCountry) {
      try {
        const countryFlag = countryCode ? getCountryFlag(countryCode) : '🌎';
        return `${cityAndCountry} ${countryFlag}`;
      } catch (error) {
        return '';
      }
    },
    async deleteContact({ id }) {
      try {
        await this.$store.dispatch('contacts/delete', id);
        this.$emit('panelClose');
        useAlert(this.$t('DELETE_CONTACT.API.SUCCESS_MESSAGE'));

        if (isAConversationRoute(this.$route.name)) {
          this.$router.push({
            name: getConversationDashboardRoute(this.$route.name),
          });
        } else if (isAInboxViewRoute(this.$route.name)) {
          this.$router.push({
            name: 'inbox_view',
          });
        } else if (this.$route.name !== 'contacts_dashboard') {
          this.$router.push({
            name: 'contacts_dashboard',
          });
        }
      } catch (error) {
        useAlert(
          error.message
            ? error.message
            : this.$t('DELETE_CONTACT.API.ERROR_MESSAGE')
        );
      }
    },
    openMergeModal() {
      this.toggleMergeModal();
    },
    openScheduleModal() {
      this.showScheduleModal = true;
    },
  },
  // Escuchar eventos del mixin
  created() {
    this.$on('contact-found-in-crm', found => {
      this.contactFoundInCRM = found;
    });
  }
};
</script>

<template>
  <div class="relative items-center w-full p-4 bg-white dark:bg-slate-900">
    <div class="flex flex-col w-full gap-2 text-left rtl:text-right">
      <div class="flex flex-row justify-between">
        <Thumbnail v-if="showAvatar" :src="contact.thumbnail" size="56px" :username="contact.name"
          :status="contact.availability_status" />
        <woot-button v-if="showCloseButton" :icon="closeIconName" class="clear secondary rtl:rotate-180"
          @click="onPanelToggle" />
      </div>

      <div class="flex flex-col items-start gap-1.5 min-w-0 w-full">
        <div v-if="showAvatar" class="flex items-start w-full min-w-0 gap-2">
          <h3
            class="flex-shrink max-w-full min-w-0 my-0 text-base capitalize break-words text-slate-800 dark:text-slate-100">
            {{ crmContact.name ||  contact.name }}
          </h3>
          <div class="flex flex-row items-center gap-1">
            <fluent-icon v-if="contact.created_at" v-tooltip.left="`${$t('CONTACT_PANEL.CREATED_AT_LABEL')} ${dynamicTime(
              contact.created_at
            )}`
              " icon="info" size="14" class="mt-0.5" />
            <a :href="contactProfileLink" class="text-base" target="_blank" rel="noopener nofollow noreferrer">
              <woot-button size="tiny" icon="open" variant="clear" color-scheme="secondary" />
            </a>
          </div>
        </div>

        <p v-if="additionalAttributes.description" class="break-words mb-0.5">
          {{ additionalAttributes.description }}
        </p>
        <div class="flex flex-col items-start w-full gap-2">
          <ContactInfoRow :href="contact.email ? `mailto:${contact.email}` : ''" :value="contact.email" icon="mail"
            emoji="✉️" :title="$t('CONTACT_PANEL.EMAIL_ADDRESS')" show-copy />
          <ContactInfoRow :href="contact.phone_number ? `tel:${contact.phone_number}` : ''"
            :value="contact.phone_number" icon="call" emoji="📞" :title="$t('CONTACT_PANEL.PHONE_NUMBER')" show-copy />
          <ContactInfoRow v-if="contact.identifier" :value="contact.identifier" icon="contact-identify" emoji="🪪"
            :title="$t('CONTACT_PANEL.IDENTIFIER')" />
          <ContactInfoRow :value="additionalAttributes.company_name" icon="building-bank" emoji="🏢"
            :title="$t('CONTACT_PANEL.COMPANY')" />
          <ContactInfoRow v-if="location || additionalAttributes.location"
            :value="location || additionalAttributes.location" icon="map" emoji="🌍"
            :title="$t('CONTACT_PANEL.LOCATION')" />
          <SocialIcons :social-profiles="socialProfiles" />

          <ContactInfoRow v-if="isIntegrationEnabled" :value="idContactoCRMzeus" icon="contact-identify"
            :title="'ID Contacto CRMZeus'" />
          <ContactInfoRow v-if="isIntegrationEnabled" :value="idOrganizacionCRMzeus" icon="building-bank"
            :title="'ID Organizacion CRMZeus'" />

        </div>
      </div>
      <div class="flex items-center w-full mt-0.5 gap-2">
        <woot-button v-tooltip="$t('CONTACT_PANEL.NEW_MESSAGE')" :title="$t('CONTACT_PANEL.NEW_MESSAGE')" icon="chat"
          size="small" @click="toggleConversationModal" />

        <woot-button v-if="conversationId" v-tooltip="'Programacion : envio de mensaje...'"
          :title="$t('CONTACT_PANEL.NEW_MESSAGE')" icon="clock" size="small" color-scheme="success"
          @click="openScheduleModal" />

        <woot-button v-tooltip="$t('EDIT_CONTACT.BUTTON_LABEL')" :title="$t('EDIT_CONTACT.BUTTON_LABEL')" icon="edit"
          variant="smooth" size="small" @click="toggleEditModal" />
        <woot-button v-tooltip="$t('CONTACT_PANEL.MERGE_CONTACT')" :title="$t('CONTACT_PANEL.MERGE_CONTACT')"
          icon="merge" variant="smooth" size="small" color-scheme="secondary" :disabled="uiFlags.isMerging"
          @click="openMergeModal" />

        <!-- proyecto@contacts_notes - botón para abrir modal CRUD de notas -->
        <woot-button
          v-tooltip="$t('NOTES.HEADER.TITLE')"
          :title="$t('NOTES.HEADER.TITLE')"
          icon="document"
          variant="smooth"
          size="small"
          color-scheme="secondary"
          @click="showNotesCrudModal = true"
        />

         <!-- proyecto@conversation_private - botón solo en contactos (sin conversationId): inicia nota privada -->
         <woot-button v-if="!conversationId" v-tooltip="$t('CONTACT_PANEL.PRIVATE_CONVERSATION')" :title="$t('CONTACT_PANEL.PRIVATE_CONVERSATION')"
          icon="lock-closed" size="small" color-scheme="warning" @click="togglePrivateConversationModal" />

        <!-- proyecto@conversation_private - botón solo en conversaciones (con conversationId): seleccionar contacto nuevo -->
        <woot-button v-if="conversationId" v-tooltip="$t('NEW_CONVERSATION.FROM_CONTACTS.BUTTON')" :title="$t('NEW_CONVERSATION.FROM_CONTACTS.BUTTON')"
          icon="chat" size="small" color-scheme="warning" @click="showNewConversationFromContacts = true" />

        <!-- google_calendar - crear evento desde conversación -->
        <woot-button
          v-if="showCalendarButton"
          v-tooltip="$t('GOOGLE_CALENDAR.CREATE_FROM_CONVERSATION')"
          icon="calendar"
          variant="smooth"
          size="small"
          @click="showCreateEventModal = true"
        />

        <woot-button v-if="isAdmin" v-tooltip="$t('DELETE_CONTACT.BUTTON_LABEL')"
          :title="$t('DELETE_CONTACT.BUTTON_LABEL')" icon="delete" variant="smooth" size="small" color-scheme="alert"
          :disabled="uiFlags.isDeleting" @click="toggleDeleteModal" />

      </div>
      <EditContact v-if="showEditModal" :show="showEditModal" :contact="contact" :crm-contact="crmContact"
        :contact-found-in-crm="contactFoundInCRM" @cancel="toggleEditModal" @suppress-alerts="handleSuppressAlerts" 
        :is-integration-enabled="isIntegrationEnabled" />
      <NewConversation v-if="contact.id" :show="showConversationModal" :contact="contact"
        @cancel="toggleConversationModal" />
      <!-- proyecto@conversation_private - modal conversación privada (desde contactos) -->
      <NewPrivateConversation v-if="contact.id" :show="showPrivateConversationModal" :contact="contact"
        @cancel="togglePrivateConversationModal" />
      <!-- proyecto@conversation_private - modal selección de contacto nuevo (desde conversaciones) -->
      <NewConversationFromContacts
        :show="showNewConversationFromContacts"
        @cancel="showNewConversationFromContacts = false"
      />
      <ContactMergeModal v-if="showMergeModal" :primary-contact="contact" :show="showMergeModal"
        @close="toggleMergeModal" />
    </div>
    <!-- proyecto@contacts_notes - modal CRUD completo de notas del contacto -->
    <ContactNotesCrudModal
      v-if="showNotesCrudModal && contact.id"
      :show="showNotesCrudModal"
      :contact-id="contact.id"
      :contact-name="contact.name"
      @close="showNotesCrudModal = false"
    />
    <!-- google_calendar - modal crear evento desde conversación -->
    <CreateEventModal
      v-if="showCalendarButton"
      :show="showCreateEventModal"
      :prefill-email="calendarPrefillEmail"
      @close="showCreateEventModal = false"
      @created="showCreateEventModal = false"
    />

    <woot-delete-modal v-if="showDeleteModal" :show.sync="showDeleteModal" :on-close="closeDelete"
      :on-confirm="confirmDeletion" :title="$t('DELETE_CONTACT.CONFIRM.TITLE')"
      :message="$t('DELETE_CONTACT.CONFIRM.MESSAGE')" :message-value="confirmDeleteMessage"
      :confirm-text="$t('DELETE_CONTACT.CONFIRM.YES')" :reject-text="$t('DELETE_CONTACT.CONFIRM.NO')" />

    <schedule-message-modal :show="showScheduleModal" :conversation-id="conversationId" :current-user="currentUser"
      :inbox-id="currentChat.inbox_id" @close="showScheduleModal = false" />
  </div>
</template>
