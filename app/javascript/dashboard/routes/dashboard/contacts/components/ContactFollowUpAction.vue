<!--
  Ficha del contacto — «Delegar seguimiento» (Seguimiento IA) y el que está corriendo en
  cualquiera de sus conversaciones. En el formulario se elige la conversación; «Vista
  anterior» abre el agente de seguimiento de siempre sobre esa conversación.
  Sin conversaciones: se elige la bandeja (WhatsApp, SMS o correo) y al delegar se crea la
  conversación ahí, asignada a quien delega.
-->
<script>
import { useAlert } from 'dashboard/composables';
import ContactAPI from 'dashboard/api/contacts';
import AiFollowUpsAPI from 'dashboard/api/aiFollowUps';
import ContactTrackingModal from 'dashboard/components/contacts/ContactTracking/ContactTrackingModal.vue';
import AiFollowUpModal from 'dashboard/views/gestorTickets/conversation/AiFollowUpModal.vue';
import AiFollowUpStatus from 'dashboard/views/gestorTickets/conversation/AiFollowUpStatus.vue';

const F = 'ASSISTANT.AI_FOLLOW_UP';

export default {
  name: 'ContactFollowUpAction',
  components: { ContactTrackingModal, AiFollowUpModal, AiFollowUpStatus },
  props: {
    contactId: { type: Number, required: true },
  },
  data() {
    return {
      conversations: [],
      inboxes: [], // sin conversaciones: dónde abrir la nueva
      showNew: false,
      live: false, // hay un Seguimiento IA corriendo → botón verde
      legacyChat: null, // conversación para la vista anterior
    };
  },
  computed: {
    options() {
      return this.conversations.map(c => {
        const inbox = this.$store.getters['inboxes/getInbox'](c.inbox_id);
        return {
          id: c.id,
          label: [`#${c.id}`, inbox && inbox.name, c.status]
            .filter(Boolean)
            .join(' · '),
        };
      });
    },
    openaiOk() {
      const apps = this.$store.getters['integrations/getAppIntegrations'] || [];
      const openai = apps.find(a => a.id === 'openai');
      return (
        openai &&
        openai.enabled &&
        (openai.hooks || []).some(h => h.status === true)
      );
    },
  },
  watch: {
    contactId: { immediate: true, handler: 'loadConversations' },
  },
  mounted() {
    const apps = this.$store.getters['integrations/getAppIntegrations'] || [];
    if (!apps.length) this.$store.dispatch('integrations/get');
  },
  methods: {
    f(key, params) {
      return this.$t(`${F}.${key}`, params);
    },
    async loadConversations() {
      try {
        const { data } = await ContactAPI.getConversations(this.contactId);
        // La más reciente primero: es la que queda elegida en el formulario.
        this.conversations = (data.payload || [])
          .slice()
          .sort(
            (a, b) => (b.last_activity_at || 0) - (a.last_activity_at || 0)
          );
      } catch (_e) {
        this.conversations = [];
      }
    },
    async open() {
      if (!this.openaiOk) {
        useAlert(
          this.$t('CASE_TICKETS.CONVERSATION_ACTIONS.DELEGATE_MISSING', {
            missing: this.$t('CONTACT_PANEL.INTEGRATION_WARNING.OPENAI'),
          })
        );
        return;
      }
      if (!this.conversations.length) {
        try {
          const { data } = await AiFollowUpsAPI.inboxes(this.contactId);
          this.inboxes = data.payload || [];
        } catch {
          this.inboxes = [];
        }
        if (!this.inboxes.length) {
          useAlert(this.f('NO_REACHABLE_INBOX'));
          return;
        }
      }
      this.showNew = true;
    },
    onCreated(followUp) {
      this.showNew = false;
      if (!this.conversations.length) this.loadConversations();
      this.$refs.status?.set(followUp);
    },
    openLegacy(conversationId) {
      this.showNew = false;
      const chat = this.conversations.find(c => c.id === conversationId);
      this.legacyChat = chat ? { ...chat, display_id: chat.id } : null;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2 px-4 pt-4">
    <woot-button
      v-tooltip="f('BUTTON_HINT')"
      variant="smooth"
      size="small"
      icon="bot"
      :color-scheme="live ? 'success' : 'primary'"
      class="w-full"
      @click="open"
    >
      {{ f('BUTTON') }}
    </woot-button>
    <AiFollowUpStatus
      ref="status"
      :contact-id="contactId"
      @change="live = $event"
    />

    <AiFollowUpModal
      v-if="showNew"
      :show="showNew"
      :conversations="options"
      :new-contact-id="conversations.length ? null : contactId"
      :inboxes="conversations.length ? null : inboxes"
      @close="showNew = false"
      @created="onCreated"
      @legacy="openLegacy"
    />
    <ContactTrackingModal
      v-if="legacyChat"
      :show="!!legacyChat"
      :contact-id="contactId"
      :conversation-id="legacyChat.id"
      :current-chat="legacyChat"
      @close="legacyChat = null"
    />
  </div>
</template>
