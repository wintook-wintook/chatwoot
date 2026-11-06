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
import ContactOwnerField from './ContactOwnerField.vue'; // Responsable fijo del contacto
import ContactOptOutField from './ContactOptOutField.vue'; // prospeccion V4: no contactar
import ContactProspectScore from './ContactProspectScore.vue'; // prospeccion P4: puntuación
import ContactMoreActions from './ContactMoreActions.vue';
import ContactLabel from 'dashboard/routes/dashboard/contacts/components/ContactLabels.vue';
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
import { backQuery } from 'dashboard/views/gestorTickets/backLink'; // Plan-Catalogo-Cotizaciones
import QuickTaskModal from 'dashboard/views/gestorTickets/tasks/QuickTaskModal.vue'; // crear tarea desde el panel

export default {
  components: {
    QuickTaskModal,
    ContactOwnerField,
    ContactOptOutField,
    ContactProspectScore,
    ContactMoreActions,
    ContactLabel,
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
    // 'panel' (columna angosta: conversación) o 'header' (a todo lo ancho:
    // página del contacto). Las acciones y sus modales son los mismos.
    layout: {
      type: String,
      default: 'panel',
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
      showTaskModal: false,
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
      return this.integrations.find(
        integration => integration.id === 'crmzeus'
      );
    },
    isIntegrationEnabled() {
      return this.crmzeusIntegration?.enabled || false;
    },

    isHeader() {
      return this.layout === 'header';
    },
    // Acciones que no son las principales (Mensaje, Editar): van en «Más».
    moreActions() {
      // Programar mensaje, cotizar y crear tarea van a la vista, como íconos (panelActions).
      // 2026-11-06: se quitaron de aquí Mensaje, Nueva conversación (privada con otro contacto) y
      // Crear evento de calendario; la nota privada quedó solo en la ficha del contacto.
      const list = [
        {
          key: 'merge',
          icon: 'merge',
          label: this.$t('CONTACT_PANEL.MERGE_CONTACT'),
          disabled: this.uiFlags.isMerging,
        },
      ];
      if (this.isAdmin) {
        list.push({
          key: 'delete',
          icon: 'delete',
          label: this.$t('DELETE_CONTACT.BUTTON_LABEL'),
          danger: true,
          disabled: this.uiFlags.isDeleting,
        });
      }
      return list;
    },
    // Panel de la conversación: las acciones de todos los días, solo ícono (con su nombre
    // al pasar el mouse), en la línea de la foto: editar, tarea, cotizar, programar mensaje, notas y «···».
    // «Mensaje» (conversación nueva) solo está en la ficha del contacto.
    panelActions() {
      const cases = this.isFeatureEnabledonAccount(
        this.accountId,
        FEATURE_FLAGS.CASE_MANAGEMENT
      );
      return [
        {
          key: 'edit',
          icon: 'edit',
          label: this.$t('CONTACT_PANEL.ACTIONS.EDIT'),
        },
        cases && {
          key: 'task',
          icon: 'checkmark-circle',
          label: this.$t('CONTACT_PANEL.ACTIONS.TASK'),
        },
        cases && {
          key: 'quote',
          icon: 'receipt',
          label: this.$t('QUOTES.PANEL.NEW'),
        },
        this.conversationId && {
          key: 'schedule',
          icon: 'clock',
          label: this.$t('CONTACT_PANEL.ACTIONS.SCHEDULE'),
        },
        {
          key: 'notes',
          icon: 'document',
          label: this.$t('NOTES.HEADER.TITLE'),
        },
      ].filter(Boolean);
    },
    // Página del contacto: en el encabezado lo que se hace CON el contacto;
    // lo que se crea PARA él (caso, cotización, nota) está en su pestaña.
    //   Mensaje → hablar con él · Nueva nota privada → conversación privada, interna
    //   Editar    → sus datos
    //   ···       → lo delicado y poco frecuente (fusionar, eliminar)
    headerMoreActions() {
      const list = [
        {
          key: 'merge',
          icon: 'merge',
          label: this.$t('CONTACT_PANEL.MERGE_CONTACT'),
          disabled: this.uiFlags.isMerging,
        },
      ];
      if (this.isAdmin) {
        list.push({
          key: 'delete',
          icon: 'delete',
          label: this.$t('DELETE_CONTACT.BUTTON_LABEL'),
          danger: true,
          disabled: this.uiFlags.isDeleting,
        });
      }
      return list;
    },
    // En el encabezado no va el enlace wa.me: abre el WhatsApp personal y no
    // queda en Wintook; para escribirle está «Mensaje» (la línea de la empresa).
    headerSocialProfiles() {
      const { phone, ...rest } = this.socialProfiles;
      return rest;
    },
    contactProfileLink() {
      return `/app/accounts/${this.$route.params.accountId}/contacts/${this.contact.id}`;
    },
    additionalAttributes() {
      return this.contact.additional_attributes || {};
    },
    // Empresa · ubicación, en una línea bajo el nombre (antes eran dos renglones).
    subtitle() {
      return [
        this.additionalAttributes.company_name,
        this.location || this.additionalAttributes.location,
      ]
        .filter(Boolean)
        .join(' · ');
    },
    crmzeusContactId() {
      return (
        Number((this.contact.custom_attributes || {}).idcontacto_crmzeus) || 0
      );
    },
    crmzeusOrganizationId() {
      return (
        Number((this.contact.custom_attributes || {}).idorganizacion_crmzeus) ||
        0
      );
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
        this.isFeatureEnabledonAccount(
          this.accountId,
          FEATURE_FLAGS.GOOGLE_CALENDAR
        )
      );
    },
    calendarPrefillEmail() {
      return this.contact?.email || '';
    },
  },
  watch: {
    async contact() {
      this.initializeContactData(); // Sincronizador
      // const kanbanInfo = await this.$store.dispatch(
      //   'kanbanTypeProcesses/getConversationKanbanInfo',
      //   this.currentChat.id
      // );
      // this.kanbanTypeProcess = kanbanInfo.kanban_type_process_id || 0;
      // console.log(`this.kanbanTypeProcess ???? ${this.kanbanTypeProcess}`)
    },
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
  // Escuchar eventos del mixin
  created() {
    this.$on('contact-found-in-crm', found => {
      this.contactFoundInCRM = found;
    });
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
        const conv = this.$store.state.conversations.allConversations.find(
          c => c.display_id === 8
        );
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
      console.log('suppressAlerts', this.suppressAlerts);
      try {
        if (this.isInitializing) return;
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
          const dataContactId = await this.searchContactCRMZeusById(
            this.contact
          );
          this.contactFoundInCRM = dataContactId.success;
          this.crmContact = dataContactId.data;

          console.log('isSynchronized');
          console.log('dataContactId');
          console.log(dataContactId);

          console.log('this.contactFoundInCRM');
          console.log(this.contactFoundInCRM);

          console.log('this.crmContact');
          console.log(this.crmContact);

          if (dataContactId.success) {
            if (this.showAlert && !this.suppressAlerts) {
              useAlert(dataContactId.message, 'success');
              useAlert(this.$t('CONTACT.SUCCESS.FOUND_IN_CRM'), 'success');
            }
            return;
          }
          if (!dataContactId.success) {
            useAlert(dataContactId.message, 'success');
            const dataContactPhone = await this.searchContactCRMZeusByPhone(
              this.contact
            );
            if (dataContactPhone.success) {
              this.contactFoundInCRM = dataContactPhone.success;
              this.crmContact = dataContactPhone.data;
              if (this.showAlert && !this.suppressAlerts) {
                useAlert(dataContactPhone.message, 'success');
                useAlert(this.$t('CONTACT.SUCCESS.FOUND_IN_CRM'), 'success');
              }
              return;
            }
            const dataContactEmail = await this.searchContactCRMZeusByEmail(
              this.contact
            );
            if (dataContactEmail.success) {
              this.contactFoundInCRM = dataContactEmail.success;
              this.crmContact = dataContactEmail.data;
              if (this.showAlert && !this.suppressAlerts) {
                useAlert(dataContactEmail.message, 'success');
                useAlert(this.$t('CONTACT.SUCCESS.FOUND_IN_CRM'), 'success');
              }
              return;
            }
          }
          return;
        }

        const crmByPhone = await this.searchContactCRMZeusByPhone(this.contact);
        if (crmByPhone.success) {
          this.contactFoundInCRM = crmByPhone.success;
          this.crmContact = crmByPhone.data;
          console.log('crmByPhone');
          console.log(crmByPhone);
          return;
        }
        const crmByEmail = await this.searchContactCRMZeusByEmail(this.contact);
        if (crmByEmail.success) {
          this.contactFoundInCRM = crmByEmail.success;
          this.crmContact = crmByEmail.data;
          console.log('crmByEmail');
          console.log(crmByPhone);
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
    runMoreAction(key) {
      const handlers = {
        merge: this.openMergeModal,
        notes: () => {
          this.showNotesCrudModal = true;
        },
        schedule: this.openScheduleModal,
        fromContacts: () => {
          this.showNewConversationFromContacts = true;
        },
        private: this.togglePrivateConversationModal,
        calendar: () => {
          this.showCreateEventModal = true;
        },
        quote: () => {
          this.$router.push({
            name: 'gestorTickets_quote_new',
            params: { accountId: this.accountId },
            query: { contact_id: this.contact.id, ...backQuery(this.$route) },
          });
        },
        delete: this.toggleDeleteModal,
        message: this.toggleConversationModal,
        edit: this.toggleEditModal,
        task: () => {
          this.showTaskModal = true;
        },
      };
      if (handlers[key]) handlers[key]();
    },
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
};
</script>

<template>
  <div
    class="relative items-center w-full p-4 bg-white dark:bg-slate-900"
    :class="{ 'border-b border-slate-50 dark:border-slate-800/50': isHeader }"
  >
    <!-- Panel de la conversación, compacto: foto chica y al lado nombre, empresa y las acciones -->
    <div
      v-if="!isHeader"
      class="flex flex-col w-full gap-2 text-left rtl:text-right"
    >
      <div class="flex items-start w-full gap-3">
        <Thumbnail
          v-if="showAvatar"
          :src="contact.thumbnail"
          size="40px"
          :username="contact.name"
          :status="contact.availability_status"
        />
        <div class="flex flex-col flex-1 min-w-0 gap-0.5">
          <div class="flex items-center w-full min-w-0 gap-1">
            <h3
              v-if="showAvatar"
              class="min-w-0 my-0 text-sm font-semibold capitalize truncate text-slate-800 dark:text-slate-100"
              :title="`${$t('CONTACT_PANEL.CREATED_AT_LABEL')} ${dynamicTime(
                contact.created_at
              )}`"
            >
              {{ crmContact.name || contact.name }}
            </h3>
            <a
              v-if="showAvatar"
              :href="contactProfileLink"
              target="_blank"
              rel="noopener nofollow noreferrer"
              class="flex-shrink-0"
            >
              <woot-button
                size="tiny"
                icon="open"
                variant="clear"
                color-scheme="secondary"
              />
            </a>
            <woot-button
              v-if="showCloseButton"
              :icon="closeIconName"
              size="tiny"
              class="clear secondary rtl:rotate-180 ltr:ml-auto rtl:mr-auto"
              @click="onPanelToggle"
            />
          </div>
          <p
            v-if="subtitle"
            class="mb-0 text-xs truncate text-slate-500 dark:text-slate-400"
            :title="subtitle"
          >
            {{ subtitle }}
          </p>
          <!-- Acciones, solo ícono: editar · tarea · cotizar · programar · ··· -->
          <div class="flex flex-wrap items-center gap-1 mt-1">
            <woot-button
              v-for="action in panelActions"
              :key="action.key"
              v-tooltip.top="action.label"
              :icon="action.icon"
              size="small"
              variant="smooth"
              color-scheme="secondary"
              :aria-label="action.label"
              @click="runMoreAction(action.key)"
            />
            <ContactMoreActions
              icon-only
              :actions="moreActions"
              @select="runMoreAction"
            />
          </div>
        </div>
      </div>

      <p
        v-if="additionalAttributes.description"
        class="mb-0 text-xs break-words text-slate-600 dark:text-slate-300"
      >
        {{ additionalAttributes.description }}
      </p>
      <!-- Datos: solo los que tienen valor (correo y teléfono siempre, para poder copiarlos o ver que faltan) -->
      <div class="flex flex-col items-start w-full gap-1">
        <ContactInfoRow
          :href="contact.email ? `mailto:${contact.email}` : ''"
          :value="contact.email"
          icon="mail"
          emoji="✉️"
          :title="$t('CONTACT_PANEL.EMAIL_ADDRESS')"
          show-copy
        />
        <ContactInfoRow
          :href="contact.phone_number ? `tel:${contact.phone_number}` : ''"
          :value="contact.phone_number"
          icon="call"
          emoji="📞"
          :title="$t('CONTACT_PANEL.PHONE_NUMBER')"
          show-copy
        />
        <ContactInfoRow
          v-if="contact.identifier"
          :value="contact.identifier"
          icon="contact-identify"
          emoji="🪪"
          :title="$t('CONTACT_PANEL.IDENTIFIER')"
        />
        <SocialIcons :social-profiles="socialProfiles" />

        <ContactInfoRow
          v-if="isIntegrationEnabled && crmzeusContactId"
          :value="idContactoCRMzeus"
          icon="contact-identify"
          :title="$t('CONTACT_PANEL.CRMZEUS_CONTACT_ID')"
        />
        <ContactInfoRow
          v-if="isIntegrationEnabled && crmzeusOrganizationId"
          :value="idOrganizacionCRMzeus"
          icon="building-bank"
          :title="$t('CONTACT_PANEL.CRMZEUS_ORG_ID')"
        />

        <!-- Avisos de no contactar y calificación. El responsable fijo solo está en la ficha del contacto. -->
        <ContactOptOutField v-if="contact.id" :contact="contact" />
        <ContactProspectScore v-if="contact.id" :contact-id="contact.id" />
      </div>
    </div>
    <!-- Encabezado de la página del contacto: lo esencial a lo ancho -->
    <div v-else class="flex flex-col gap-4 md:flex-row md:items-start">
      <Thumbnail
        :src="contact.thumbnail"
        size="56px"
        :username="contact.name"
        :status="contact.availability_status"
      />
      <div class="flex flex-col flex-1 min-w-0 gap-2">
        <div class="flex flex-wrap items-baseline gap-x-2">
          <h2
            class="m-0 text-xl font-semibold capitalize break-words text-slate-800 dark:text-slate-100"
          >
            {{ crmContact.name || contact.name }}
          </h2>
          <span
            v-if="additionalAttributes.company_name"
            class="text-sm text-slate-600 dark:text-slate-300"
          >
            · {{ additionalAttributes.company_name }}
          </span>
        </div>
        <div class="flex flex-wrap items-center gap-x-8 gap-y-1.5">
          <ContactInfoRow
            class="!w-auto"
            :href="contact.email ? `mailto:${contact.email}` : ''"
            :value="contact.email"
            icon="mail"
            emoji="✉️"
            :title="$t('CONTACT_PANEL.EMAIL_ADDRESS')"
            :empty-text="$t('CONTACT_PAGE.NO_EMAIL')"
            show-copy
          />
          <ContactInfoRow
            class="!w-auto"
            :href="contact.phone_number ? `tel:${contact.phone_number}` : ''"
            :value="contact.phone_number"
            icon="call"
            emoji="📞"
            :title="$t('CONTACT_PANEL.PHONE_NUMBER')"
            :empty-text="$t('CONTACT_PAGE.NO_PHONE')"
            show-copy
          />
          <ContactInfoRow
            v-if="contact.identifier"
            class="!w-auto"
            :value="contact.identifier"
            icon="contact-identify"
            emoji="🪪"
            :title="$t('CONTACT_PANEL.IDENTIFIER')"
          />
          <ContactInfoRow
            v-if="isIntegrationEnabled"
            class="!w-auto"
            :value="idContactoCRMzeus"
            icon="contact-identify"
            :title="$t('CONTACT_PANEL.CRMZEUS_CONTACT_ID')"
          />
          <ContactInfoRow
            v-if="isIntegrationEnabled"
            class="!w-auto"
            :value="idOrganizacionCRMzeus"
            icon="building-bank"
            :title="$t('CONTACT_PANEL.CRMZEUS_ORG_ID')"
          />
          <SocialIcons :social-profiles="headerSocialProfiles" />
        </div>
        <div class="flex flex-wrap items-start gap-x-8 gap-y-2">
          <div class="w-full sm:w-auto sm:min-w-[20rem]">
            <ContactOwnerField v-if="contact.id" :contact-id="contact.id" />
            <ContactOptOutField v-if="contact.id" :contact="contact" />
            <ContactProspectScore v-if="contact.id" :contact-id="contact.id" />
          </div>
          <div class="flex items-start flex-1 min-w-[16rem] gap-2">
            <span
              class="flex items-center flex-shrink-0 h-7 gap-2 text-sm text-slate-600 dark:text-slate-300"
            >
              <fluent-icon
                icon="tag"
                size="16"
                class="text-slate-500 dark:text-slate-400"
              />
              {{ $t('CONTACT_PAGE.LABELS') }}
            </span>
            <ContactLabel
              v-if="contact.id"
              :contact-id="contact.id"
              :add-text="$t('CONTACT_PAGE.ADD_LABEL')"
            />
          </div>
        </div>
      </div>
      <!-- Mensaje · Nueva nota privada · Editar · ··· (fusionar, eliminar); crear va en cada pestaña -->
      <div class="flex flex-wrap items-center flex-shrink-0 gap-2">
        <woot-button icon="chat" size="small" @click="toggleConversationModal">
          {{ $t('CONTACT_PANEL.ACTIONS.MESSAGE') }}
        </woot-button>
        <!-- Conversación privada (interna) con este contacto: solo aquí, en la ficha -->
        <woot-button
          icon="lock-closed"
          variant="smooth"
          size="small"
          color-scheme="secondary"
          @click="togglePrivateConversationModal"
        >
          {{ $t('CONTACT_PANEL.ACTIONS.PRIVATE_NOTE') }}
        </woot-button>
        <woot-button
          icon="edit"
          variant="smooth"
          size="small"
          color-scheme="secondary"
          @click="toggleEditModal"
        >
          {{ $t('CONTACT_PANEL.ACTIONS.EDIT') }}
        </woot-button>
        <ContactMoreActions
          icon-only
          :actions="headerMoreActions"
          @select="runMoreAction"
        />
      </div>
    </div>
    <!-- Modales de las acciones (los comparten el panel y el encabezado) -->
    <EditContact
      v-if="showEditModal"
      :show="showEditModal"
      :contact="contact"
      :crm-contact="crmContact"
      :contact-found-in-crm="contactFoundInCRM"
      :is-integration-enabled="isIntegrationEnabled"
      @cancel="toggleEditModal"
      @suppress-alerts="handleSuppressAlerts"
    />
    <NewConversation
      v-if="contact.id"
      :show="showConversationModal"
      :contact="contact"
      @cancel="toggleConversationModal"
    />
    <!-- proyecto@conversation_private - modal conversación privada (desde contactos) -->
    <NewPrivateConversation
      v-if="contact.id"
      :show="showPrivateConversationModal"
      :contact="contact"
      @cancel="togglePrivateConversationModal"
    />
    <!-- proyecto@conversation_private - modal selección de contacto nuevo (desde conversaciones) -->
    <NewConversationFromContacts
      :show="showNewConversationFromContacts"
      @cancel="showNewConversationFromContacts = false"
    />
    <QuickTaskModal
      v-if="showTaskModal"
      :show="showTaskModal"
      :preset-contact="contact"
      @close="showTaskModal = false"
    />
    <ContactMergeModal
      v-if="showMergeModal"
      :primary-contact="contact"
      :show="showMergeModal"
      @close="toggleMergeModal"
    />
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
      :prefill-contact="contact"
      @close="showCreateEventModal = false"
      @created="showCreateEventModal = false"
    />

    <woot-delete-modal
      v-if="showDeleteModal"
      :show.sync="showDeleteModal"
      :on-close="closeDelete"
      :on-confirm="confirmDeletion"
      :title="$t('DELETE_CONTACT.CONFIRM.TITLE')"
      :message="$t('DELETE_CONTACT.CONFIRM.MESSAGE')"
      :message-value="confirmDeleteMessage"
      :confirm-text="$t('DELETE_CONTACT.CONFIRM.YES')"
      :reject-text="$t('DELETE_CONTACT.CONFIRM.NO')"
    />

    <ScheduleMessageModal
      :show="showScheduleModal"
      :conversation-id="conversationId"
      :current-user="currentUser"
      :current-chat="currentChat"
      :inbox-id="currentChat.inbox_id"
      @close="showScheduleModal = false"
    />
  </div>
</template>
