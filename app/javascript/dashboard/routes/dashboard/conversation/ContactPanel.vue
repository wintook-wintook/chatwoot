<!-- 
  ================================================================================
  proyecto@CONTACT_PANEL
  ================================================================================
  Archivo: ContactPanel.vue (INTEGRADO - ESTILOS COMPATIBLES)
  Descripción: Panel de contacto con integración del sistema de seguimientos
               Compatible con versiones anteriores de Tailwind CSS
  ================================================================================
-->

<script>
import { mapGetters } from 'vuex';
import { useUISettings } from 'dashboard/composables/useUISettings';
import AccordionItem from 'dashboard/components/Accordion/AccordionItem.vue';
import ContactConversations from './ContactConversations.vue';
import ConversationAction from './ConversationAction.vue';
import ConversationParticipant from './ConversationParticipant.vue';

import ContactInfo from './contact/ContactInfo.vue';
import ConversationInfo from './ConversationInfo.vue';
import CustomAttributes from './customAttributes/CustomAttributes.vue';
import draggable from 'vuedraggable';
import MacrosList from './Macros/List.vue';
import Modal from 'dashboard/components/Modal.vue';

// ============================================================
// proyecto@CONTACT_PANEL - NUEVO: Importar componentes
// ============================================================
import ContactTrackingModal from 'dashboard/components/contacts/ContactTracking/ContactTrackingModal.vue';

export default {
  components: {
    AccordionItem,
    ContactConversations,
    ContactInfo,
    ConversationInfo,
    CustomAttributes,
    ConversationAction,
    ConversationParticipant,
    Draggable: draggable,
    MacrosList,
    // ============================================================
    // proyecto@CONTACT_PANEL - NUEVO: Registrar componente
    // ============================================================
    ContactTrackingModal,
    Modal,
  },
  props: {
    conversationId: {
      type: [Number, String],
      required: true,
    },
    inboxId: {
      type: Number,
      default: undefined,
    },
    onToggle: {
      type: Function,
      default: () => { },
    },
  },
  setup() {
    const {
      updateUISettings,
      isContactSidebarItemOpen,
      conversationSidebarItemsOrder,
      toggleSidebarUIState,
    } = useUISettings();

    return {
      updateUISettings,
      isContactSidebarItemOpen,
      conversationSidebarItemsOrder,
      toggleSidebarUIState,
    };
  },
  data() {
    return {
      dragEnabled: true,
      conversationSidebarItems: [],
      dragging: false,
      // ============================================================
      // proyecto@CONTACT_PANEL - NUEVO: Estado del modal
      // ============================================================
      showTrackingModal: false,
      showIntegrationWarning: false, // ← NUEVO
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
    }),



    hasTrackingBotIntegration() {
      const currentInboxId = this.currentChat?.inbox_id;
      if (!currentInboxId) return false;

      const apps = this.$store.getters['integrations/getAppIntegrations'] || [];
      const trackingBotApp = apps.find(app => app.id === 'tracking_bot');

      if (!trackingBotApp || !trackingBotApp.enabled) return false;

      const hooks = trackingBotApp.hooks || [];
      return hooks.some(hook =>
        hook.status === true &&
        hook.inbox?.id === Number(currentInboxId)
      );
    },

    hasOpenAIIntegration() {
      const apps = this.$store.getters['integrations/getAppIntegrations'] || [];
      const openAIApp = apps.find(app => app.id === 'openai');

      if (!openAIApp || !openAIApp.enabled) return false;

      const hooks = openAIApp.hooks || [];
      return hooks.some(hook => hook.status === true);
    },

    missingIntegrationsMessage() {
      const missing = [];

      if (!this.hasTrackingBotIntegration) {
        missing.push('Bot de Seguimientos');
      }

      if (!this.hasOpenAIIntegration) {
        missing.push('OpenAI');
      }

      if (missing.length === 0) return '';

      return `Integraciones faltantes: ${missing.join(', ')}`;
    },





    conversationAdditionalAttributes() {
      return this.currentConversationMetaData.additional_attributes || {};
    },
    channelType() {
      return this.currentChat.meta?.channel;
    },
    contact() {
      return this.$store.getters['contacts/getContact'](this.contactId);
    },
    contactAdditionalAttributes() {
      return this.contact.additional_attributes || {};
    },
    contactId() {
      return this.currentChat.meta?.sender?.id;
    },
    currentConversationMetaData() {
      return this.$store.getters[
        'conversationMetadata/getConversationMetadata'
      ](this.conversationId);
    },
    hasContactAttributes() {
      const { custom_attributes: customAttributes } = this.contact;
      return customAttributes && Object.keys(customAttributes).length;
    },
    // ============================================================
    // proyecto@CONTACT_PANEL - NUEVO: Contador de seguimientos activos
    // ============================================================
    activeTrackingsCount() {
      if (!this.contactId) return 0;
      const trackings = this.$store.getters['contactTrackings/getTrackings'](this.contactId) || [];
      return trackings.filter(t =>
        ['pending', 'scheduled', 'active'].includes(t.status)
      ).length;
    },
    // ============================================================
    // proyecto@CONTACT_PANEL - NUEVO: Validar integraciones requeridas por inbox
    // ============================================================
    // hasRequiredIntegrations() {
    //   // Obtener el inbox actual de la conversación
    //   const currentInboxId = this.currentChat?.inbox_id;

    //   console.log("hasRequiredIntegrations", currentInboxId)
    //   if (!currentInboxId) {
    //     console.log('[ContactPanel] No inbox ID found');
    //     return false;
    //   }

    //   // Obtener hooks/integraciones de la cuenta
    //   const hooks = this.$store.getters['integrations/getAppIntegrations'] || [];

    //   console.log('[ContactPanel] Current inbox ID:', currentInboxId);
    //   console.log('[ContactPanel] All hooks:', hooks);

    //   // Verificar tracking_bot habilitado para este inbox
    //   const hasTrackingBot = hooks.some(hook =>
    //     hook.app_id === 'tracking_bot' &&
    //     hook.status === 'enabled' &&
    //     (!hook.inbox_id || hook.inbox_id === currentInboxId) // Global o específico del inbox
    //   );

    //   // Verificar openai habilitado (normalmente es global, no por inbox)
    //   const hasOpenAI = hooks.some(hook =>
    //     hook.app_id === 'openai' &&
    //     hook.status === 'enabled'
    //   );

    //   console.log('[ContactPanel] Has tracking_bot for inbox:', hasTrackingBot);
    //   console.log('[ContactPanel] Has openai:', hasOpenAI);

    //   return hasTrackingBot && hasOpenAI;
    // },
    // ============================================================
    // proyecto@CONTACT_PANEL - CORREGIDO: Validar integraciones
    // ============================================================


    // ============================================================
    // proyecto@CONTACT_PANEL - CORREGIDO: Validar integraciones
    // Estructura real: array de apps con hooks anidados
    // ============================================================
    hasRequiredIntegrations() {
      // 1. Verificar que tenemos un inbox ID
      const currentInboxId = this.currentChat?.inbox_id;
      if (!currentInboxId) {
        console.log('[ContactPanel] ❌ No inbox ID found');
        return false;
      }

      // 2. Obtener las apps de integraciones
      const apps = this.$store.getters['integrations/getAppIntegrations'];

      // Validar que existan apps
      if (!apps || !Array.isArray(apps) || apps.length === 0) {
        console.log('[ContactPanel] ❌ No apps found');
        return false;
      }

      console.log('[ContactPanel] 📋 Apps disponibles:', apps);
      console.log('[ContactPanel] 🏢 Current inbox ID:', currentInboxId);

      // 3. Buscar la app tracking_bot
      const trackingBotApp = apps.find(app => app.id === 'tracking_bot');

      if (!trackingBotApp) {
        console.log('[ContactPanel] ❌ tracking_bot app not found');
        return false;
      }

      console.log('[ContactPanel] 🤖 tracking_bot app:', trackingBotApp);

      // 4. Verificar que tracking_bot esté enabled
      if (!trackingBotApp.enabled) {
        console.log('[ContactPanel] ❌ tracking_bot is not enabled');
        return false;
      }

      // 5. Verificar que tenga hooks activos para este inbox
      const trackingBotHooks = trackingBotApp.hooks || [];
      const hasActiveHookForInbox = trackingBotHooks.some(hook => {
        const isActive = hook.status === true;
        const matchesInbox = hook.inbox?.id === Number(currentInboxId);

        console.log('[ContactPanel] 🔍 Checking tracking_bot hook:', {
          hookId: hook.id,
          inboxId: hook.inbox?.id,
          inboxName: hook.inbox?.name,
          status: hook.status,
          isActive,
          matchesInbox
        });

        return isActive && matchesInbox;
      });

      // 6. Buscar la app openai
      const openAIApp = apps.find(app => app.id === 'openai');

      if (!openAIApp) {
        console.log('[ContactPanel] ❌ openai app not found');
        return false;
      }

      console.log('[ContactPanel] 🧠 openai app:', openAIApp);

      // 7. Verificar que openai esté enabled
      if (!openAIApp.enabled) {
        console.log('[ContactPanel] ❌ openai is not enabled');
        return false;
      }

      // 8. Verificar que openai tenga al menos un hook activo
      const openAIHooks = openAIApp.hooks || [];
      const hasActiveOpenAIHook = openAIHooks.some(hook => hook.status === true);

      console.log('[ContactPanel] 🔍 OpenAI hooks:', openAIHooks);

      // 9. Resultado final
      const result = hasActiveHookForInbox && hasActiveOpenAIHook;

      console.log('[ContactPanel] ✅ Final check:', {
        inbox: currentInboxId,
        trackingBotEnabled: trackingBotApp.enabled,
        hasActiveHookForInbox,
        openAIEnabled: openAIApp.enabled,
        hasActiveOpenAIHook,
        RESULT: result
      });

      return result;
    },
    // ============================================================
    // proyecto@CONTACT_PANEL - CORREGIDO: Validar integraciones
    // ============================================================


    // ============================================================
    // proyecto@CONTACT_PANEL - NUEVO: Mostrar botón si hay contacto e integraciones
    // ============================================================
    showTrackingButton() {

      console.log("this.hasRequiredIntegrations", this.hasRequiredIntegrations)
      console.log("this.contact.id", this.contact.id)
      return this.contact.id;
    },
  },
  watch: {
    conversationId(newConversationId, prevConversationId) {
      if (newConversationId && newConversationId !== prevConversationId) {
        this.getContactDetails();
      }
    },
    contactId() {
      this.getContactDetails();
      // ============================================================
      // proyecto@CONTACT_PANEL - NUEVO: Cargar trackings al cambiar contacto
      // ============================================================
      this.loadContactTrackings();
    },
  },
  mounted() {
    this.$store.dispatch('integrations/get');
    this.conversationSidebarItems = this.conversationSidebarItemsOrder;
    this.getContactDetails();
    this.$store.dispatch('attributes/get', 0);
    // ============================================================
    // proyecto@CONTACT_PANEL - NUEVO: Cargar trackings al montar
    // ============================================================
    this.loadContactTrackings();
  },





  methods: {
    onPanelToggle() {
      this.onToggle();
    },
    getContactDetails() {
      if (this.contactId) {
        this.$store.dispatch('contacts/show', { id: this.contactId });
      }
    },
    getAttributesByModel() {
      if (this.contactId) {
        this.$store.dispatch('contacts/show', { id: this.contactId });
      }
    },
    openTranscriptModal() {
      this.showTranscriptModal = true;
    },
    onDragEnd() {
      this.dragging = false;
      this.updateUISettings({
        conversation_sidebar_items_order: this.conversationSidebarItems,
      });
    },

    // ============================================================
    // proyecto@CONTACT_PANEL - NUEVOS MÉTODOS
    // ============================================================

    /**
     * Abrir modal de seguimientos
     */
    openTrackingModal() {
      console.log('🔵 openTrackingModal called');
      console.log('🔵 contactId:', this.contactId);
      console.log('🔵 conversationId:', this.conversationId);
      this.showTrackingModal = true;
      console.log('🔵 showTrackingModal:', this.showTrackingModal);
    },

    handleTrackingClick() {
      if (!this.hasRequiredIntegrations) {
        // alert(
        //   'Las integraciones requeridas no están activas.\n\n' +
        //   'Debes habilitar Tracking Bot y OpenAI para usar esta función.'
        // );
        alert(JSON.stringify({
          trackingBot: this.hasRequiredIntegrations,
          inbox: this.currentChat?.inbox_id,
        }, null, 2));
        return;
      }

      // Si todo OK
      this.openTrackingModal();
    },

    /**
     * Cerrar modal de seguimientos
     */
    closeTrackingModal() {
      this.showTrackingModal = false;
      // Recargar trackings después de cerrar el modal
      this.loadContactTrackings();
    },

    /**
     * Cargar seguimientos del contacto
     */
    async loadContactTrackings() {
      if (!this.contactId) return;

      try {
        await this.$store.dispatch('contactTrackings/fetch', {
          contactId: this.contactId,
          conversationId: this.conversationId,
        });
      } catch (error) {
        console.error('proyecto@CONTACT_PANEL - Error loading trackings:', error);
      }
    },

    handleTrackingClick() {
      // Si no hay integraciones activas, mostrar advertencia
      if (!this.hasRequiredIntegrations) {
        this.showIntegrationWarning = true;
        return;
      }

      // Si todo está OK, abrir modal de tracking
      this.openTrackingModal();
    },

    closeIntegrationWarning() {
      this.showIntegrationWarning = false;
    },

    goToIntegrations() {
      this.showIntegrationWarning = false;

      // Navegar a integraciones
      this.$router.push({
        name: 'settings_integrations',
      });
    },
  },
};
</script>

<template>
  <div
    class="overflow-y-auto bg-white border-l dark:bg-slate-900 text-slate-900 dark:text-slate-300 border-slate-50 dark:border-slate-800/50 rtl:border-l-0 rtl:border-r contact--panel">
    <ContactInfo :contact="contact" :conversation-id="conversationId" :channel-type="channelType"
      @toggle-panel="onPanelToggle" />

    <!-- ============================================================ -->
    <!-- proyecto@CONTACT_PANEL - NUEVO: Botón Programar Seguimiento -->
    <!-- Condición: Solo mostrar si hay contacto Y están habilitadas las integraciones tracking_bot y openai -->
    <!-- ============================================================ -->
    <div v-if="this.contact.id" class="tracking-action-section">
      <woot-button variant="smooth" size="small" color-scheme="secondary" icon="calendar-clock" class="tracking-button"
        @click="handleTrackingClick">
        {{ $t('CONTACT_PANEL.SCHEDULE_TRACKING') }}
        <span v-if="activeTrackingsCount > 0" class="tracking-badge">
          {{ activeTrackingsCount }}
        </span>
      </woot-button>
    </div>
    <!-- ============================================================ -->
    <!-- FIN: Botón Programar Seguimiento                             -->
    <!-- ============================================================ -->

    <Draggable :list="conversationSidebarItems" :disabled="!dragEnabled" animation="200" class="list-group"
      ghost-class="ghost" handle=".drag-handle" @start="dragging = true" @end="onDragEnd">
      <transition-group>
        <div v-for="element in conversationSidebarItems" :key="element.name" class="bg-white dark:bg-gray-800">
          <div v-if="element.name === 'conversation_actions'" class="conversation--actions">
            <AccordionItem :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_ACTIONS')"
              :is-open="isContactSidebarItemOpen('is_conv_actions_open')" @click="
                value => toggleSidebarUIState('is_conv_actions_open', value)
              ">
              <ConversationAction :conversation-id="conversationId" :inbox-id="inboxId" />
            </AccordionItem>
          </div>

          <div v-else-if="element.name === 'conversation_participants'" class="conversation--actions">
            <AccordionItem :title="$t('CONVERSATION_PARTICIPANTS.SIDEBAR_TITLE')"
              :is-open="isContactSidebarItemOpen('is_conv_participants_open')" @click="
                value =>
                  toggleSidebarUIState('is_conv_participants_open', value)
              ">
              <ConversationParticipant :conversation-id="conversationId" :inbox-id="inboxId" />
            </AccordionItem>
          </div>

          <div v-else-if="element.name === 'conversation_info'">
            <AccordionItem :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONVERSATION_INFO')"
              :is-open="isContactSidebarItemOpen('is_conv_details_open')" compact @click="
                value => toggleSidebarUIState('is_conv_details_open', value)
              ">
              <ConversationInfo :conversation-attributes="conversationAdditionalAttributes"
                :contact-attributes="contactAdditionalAttributes" />
            </AccordionItem>
          </div>

          <div v-else-if="element.name === 'contact_attributes'">
            <AccordionItem :title="$t('CONVERSATION_SIDEBAR.ACCORDION.CONTACT_ATTRIBUTES')"
              :is-open="isContactSidebarItemOpen('is_contact_attributes_open')" compact @click="
                value =>
                  toggleSidebarUIState('is_contact_attributes_open', value)
              ">
              <CustomAttributes attribute-type="contact_attribute" attribute-from="conversation_contact_panel"
                :contact-id="contact.id" :empty-state-message="$t('CONVERSATION_CUSTOM_ATTRIBUTES.NO_RECORDS_FOUND')
                  " />
            </AccordionItem>
          </div>

          <div v-else-if="element.name === 'previous_conversation'">
            <AccordionItem v-if="contact.id" :title="$t('CONVERSATION_SIDEBAR.ACCORDION.PREVIOUS_CONVERSATION')
              " :is-open="isContactSidebarItemOpen('is_previous_conv_open')" @click="
                value => toggleSidebarUIState('is_previous_conv_open', value)
              ">
              <ContactConversations :contact-id="contact.id" :conversation-id="conversationId" />
            </AccordionItem>
          </div>

          <woot-feature-toggle v-else-if="element.name === 'macros'" feature-key="macros">
            <AccordionItem :title="$t('CONVERSATION_SIDEBAR.ACCORDION.MACROS')"
              :is-open="isContactSidebarItemOpen('is_macro_open')" compact
              @click="value => toggleSidebarUIState('is_macro_open', value)">
              <MacrosList :conversation-id="conversationId" />
            </AccordionItem>
          </woot-feature-toggle>
        </div>
      </transition-group>
    </Draggable>

    <!-- ============================================================ -->
    <!-- proyecto@CONTACT_PANEL - NUEVO: Modal de Seguimientos     -->
    <!-- ============================================================ -->
    <!-- <ContactTrackingModal v-if="showTrackingModal && contact.id" :show="showTrackingModal" :contact-id="contact.id"
      :conversation-id="conversationId" :current-chat="currentChat" @close="closeTrackingModal" /> -->
    <!-- ============================================================ -->
    <!-- FIN: Modal de Seguimientos                                   -->
    <!-- ============================================================ -->
    <!-- En ContactPanel.vue -->
    <template>
      <ContactTrackingModal :show="showTrackingModal" :contact-id="contact.id" :conversation-id="conversationId"
        :current-chat="currentChat" @close="closeTrackingModal" />
    </template>


    <!-- Modal de Advertencia de Integraciones -->
    <Modal :show.sync="showIntegrationWarning" :on-close="closeIntegrationWarning">
      <div class="flex flex-col h-auto overflow-auto">
        <woot-modal-header :header-title="$t('CONTACT_PANEL.INTEGRATION_WARNING.TITLE')">
          <p>
            {{ $t('CONTACT_PANEL.INTEGRATION_WARNING.MESSAGE') }}
          </p>

          <!-- Lista de integraciones faltantes -->
          <div class="mt-4 space-y-2">
            <div v-if="!hasTrackingBotIntegration"
              class="flex items-center gap-2 p-3 bg-red-50 dark:bg-red-900/20 rounded-lg border border-red-200 dark:border-red-800">
              <span class="text-red-600 dark:text-red-400">❌</span>
              <span class="font-medium text-red-800 dark:text-red-200">
                {{ $t('CONTACT_PANEL.INTEGRATION_WARNING.TRACKING_BOT') }}
              </span>
            </div>

            <div v-if="!hasOpenAIIntegration"
              class="flex items-center gap-2 p-3 bg-red-50 dark:bg-red-900/20 rounded-lg border border-red-200 dark:border-red-800">
              <span class="text-red-600 dark:text-red-400">❌</span>
              <span class="font-medium text-red-800 dark:text-red-200">
                {{ $t('CONTACT_PANEL.INTEGRATION_WARNING.OPENAI') }}
              </span>
            </div>
          </div>

          <!-- Instrucciones -->
          <div class="mt-4 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-200 dark:border-blue-800 w-full">
            <p class="font-medium text-blue-900 dark:text-blue-100 mb-2">
              {{ $t('CONTACT_PANEL.INTEGRATION_WARNING.INSTRUCTIONS_TITLE') }}
            </p>
            <ol class="list-decimal list-inside space-y-1 text-sm text-blue-800 dark:text-blue-200">
              <li>{{ $t('CONTACT_PANEL.INTEGRATION_WARNING.STEP_1') }}</li>
              <li>{{ $t('CONTACT_PANEL.INTEGRATION_WARNING.STEP_2') }}</li>
              <li>{{ $t('CONTACT_PANEL.INTEGRATION_WARNING.STEP_3') }}</li>
            </ol>
          </div>
        </woot-modal-header>

        <div class="flex flex-col p-8">
          <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
            <div>
              <woot-button color-scheme="primary" @click.prevent="closeIntegrationWarning">
                {{ $t('CONTACT_PANEL.INTEGRATION_WARNING.ACCEPT') }}
              </woot-button>
            </div>
          </div>
        </div>
      </div>
    </Modal>

  </div>
</template>

<style lang="scss" scoped>
::v-deep {
  .contact--profile {
    @apply pb-3 border-b border-solid border-slate-75 dark:border-slate-700;
  }

  .conversation--actions .multiselect-wrap--small {
    .multiselect {
      @apply box-border pl-6;
    }

    .multiselect__element {
      span {
        @apply w-full;
      }
    }
  }
}

// ============================================================
// proyecto@CONTACT_PANEL - NUEVOS ESTILOS (CSS Puro Compatible)
// ============================================================

.tracking-action-section {
  padding: var(--space-normal);
  border-bottom: 1px solid var(--color-border);
}

.tracking-button {
  width: 100%;
  position: relative;

  .tracking-badge {
    position: absolute;
    top: -4px;
    right: -4px;
    display: flex;
    align-items: center;
    justify-content: center;
    min-width: 18px;
    height: 18px;
    padding: 0 4px;
    font-size: var(--font-size-mini);
    font-weight: var(--font-weight-bold);
    background-color: var(--g-500);
    color: var(--color-white);
    border-radius: var(--border-radius-rounded);
  }
}

// Estilos para la versión accordion (si se usa en el futuro)
.tracking-accordion-content {
  padding: var(--space-normal);
}

.tracking-mini-list {
  margin-top: var(--space-small);
}

.tracking-items {
  display: flex;
  flex-direction: column;
  gap: var(--space-smaller);
}

.tracking-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-small);
  border-radius: var(--border-radius-normal);
  background-color: var(--color-background);
  cursor: pointer;
  transition: background-color 0.2s;

  &:hover {
    background-color: var(--color-background-light);
  }
}

.tracking-objective {
  font-size: var(--font-size-small);
  color: var(--color-body);
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.tracking-status {
  font-size: var(--font-size-mini);
  padding: var(--space-micro) var(--space-smaller);
  border-radius: var(--border-radius-small);
  font-weight: var(--font-weight-medium);
  margin-left: var(--space-small);

  &.status-pending {
    background-color: var(--y-100);
    color: var(--y-800);
  }

  &.status-scheduled {
    background-color: var(--b-100);
    color: var(--b-800);
  }

  &.status-active {
    background-color: var(--g-100);
    color: var(--g-800);
  }
}
</style>