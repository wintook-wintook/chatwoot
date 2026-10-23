<!--
  @tickets_cases — botones de la pestaña «Conversación» del caso: ligar
  conversación, programar mensaje y «Delegar a agente IA» (seguimiento).
  Siempre visibles. Programar y delegar necesitan la conversación (su bandeja y
  su canal): si el caso no tiene, primero se liga o se crea y después se abre lo
  que se pidió. Reusa las ventanitas de la ficha del contacto tal cual.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ConversationAPI from 'dashboard/api/inbox/conversation';
import ScheduleMessageModal from 'dashboard/components/widgets/conversation/ScheduleMessageModal';
import ContactTrackingModal from 'dashboard/components/contacts/ContactTracking/ContactTrackingModal.vue';
import LinkConversationModal from './LinkConversationModal.vue';

const T = 'CASE_TICKETS.CONVERSATION_ACTIONS';

export default {
  name: 'CaseConversationActions',
  components: {
    LinkConversationModal,
    ScheduleMessageModal,
    ContactTrackingModal,
  },
  props: {
    ticket: { type: Object, required: true },
  },
  emits: ['linked'],
  data() {
    return {
      conversation: null, // la conversación completa (bandeja, canal) para las ventanitas
      showLink: false,
      showSchedule: false,
      showTracking: false,
      pendingAction: null, // 'schedule' | 'delegate': se abre al quedar ligada
    };
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
      apps: 'integrations/getAppIntegrations',
    }),
    displayId() {
      return this.ticket.conversation_display_id || null;
    },
    hasContact() {
      return !!this.ticket.contact_id;
    },
    // Mismo criterio que la ficha del contacto: bot de seguimientos activo en
    // la bandeja de la conversación y OpenAI activo.
    missingIntegrations() {
      const apps = this.apps || [];
      const inboxId = this.conversation && this.conversation.inbox_id;
      const bot = apps.find(a => a.id === 'tracking_bot');
      const openai = apps.find(a => a.id === 'openai');
      const missing = [];
      const botOk =
        bot &&
        bot.enabled &&
        (bot.hooks || []).some(
          h => h.status === true && h.inbox && h.inbox.id === Number(inboxId)
        );
      if (!botOk)
        missing.push(this.$t('CONTACT_PANEL.INTEGRATION_WARNING.TRACKING_BOT'));
      const aiOk =
        openai &&
        openai.enabled &&
        (openai.hooks || []).some(h => h.status === true);
      if (!aiOk)
        missing.push(this.$t('CONTACT_PANEL.INTEGRATION_WARNING.OPENAI'));
      return missing;
    },
  },
  watch: {
    displayId: {
      immediate: true,
      handler: 'loadConversation',
    },
  },
  mounted() {
    if (!(this.apps || []).length) this.$store.dispatch('integrations/get');
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    async loadConversation() {
      this.conversation = null;
      if (!this.displayId) return;
      try {
        const { data } = await ConversationAPI.show(this.displayId);
        this.conversation = data;
      } catch (_e) {
        this.conversation = null;
      }
      if (this.pendingAction) {
        const action = this.pendingAction;
        this.pendingAction = null;
        this.run(action);
      }
    },
    // Botón «Ligar conversación», o programar/delegar sin conversación.
    openLink(action = null) {
      if (!this.hasContact) {
        useAlert(this.t('NEED_CONTACT'));
        return;
      }
      this.pendingAction = action;
      this.showLink = true;
    },
    onLinked() {
      this.showLink = false;
      this.$emit('linked'); // el detalle recarga el caso → llega el displayId
    },
    closeLink() {
      this.showLink = false;
      this.pendingAction = null;
    },
    run(action) {
      if (!this.displayId) {
        this.openLink(action);
        return;
      }
      if (!this.conversation) return; // todavía cargando
      if (action === 'schedule') {
        this.showSchedule = true;
        return;
      }
      if (this.missingIntegrations.length) {
        useAlert(
          this.t('DELEGATE_MISSING', {
            missing: this.missingIntegrations.join(', '),
          })
        );
        return;
      }
      this.showTracking = true;
    },
  },
};
</script>

<template>
  <div class="flex flex-wrap items-center gap-2">
    <woot-button
      v-if="!displayId"
      size="small"
      variant="smooth"
      icon="link"
      @click="openLink()"
    >
      {{ t('LINK') }}
    </woot-button>
    <woot-button
      v-tooltip="t('SCHEDULE_HINT')"
      size="small"
      variant="smooth"
      color-scheme="secondary"
      icon="clock"
      @click="run('schedule')"
    >
      {{ t('SCHEDULE') }}
    </woot-button>
    <woot-button
      v-tooltip="t('DELEGATE_HINT')"
      size="small"
      variant="smooth"
      color-scheme="secondary"
      icon="calendar-clock"
      @click="run('delegate')"
    >
      {{ t('DELEGATE') }}
    </woot-button>

    <LinkConversationModal
      v-if="showLink"
      :show="showLink"
      :ticket="ticket"
      @close="closeLink"
      @linked="onLinked"
    />
    <ScheduleMessageModal
      v-if="showSchedule && conversation"
      :show="showSchedule"
      :conversation-id="displayId"
      :current-user="currentUser"
      :current-chat="conversation"
      :inbox-id="conversation.inbox_id"
      @close="showSchedule = false"
    />
    <ContactTrackingModal
      v-if="showTracking && conversation"
      :show="showTracking"
      :contact-id="ticket.contact_id"
      :conversation-id="displayId"
      :current-chat="conversation"
      @close="showTracking = false"
    />
  </div>
</template>
