<!--
  @tickets_cases — botones de la pestaña «Conversación» del caso: ligar (o
  agregar otra) conversación, programar mensaje y «Delegar seguimiento», que abre el
  Seguimiento IA (el agente nuevo con herramientas); dentro, «Vista anterior» abre el
  agente de seguimiento de siempre.
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
import AiFollowUpModal from './AiFollowUpModal.vue';
import AiFollowUpStatus from './AiFollowUpStatus.vue';
import { whoFollows } from 'dashboard/helper/followUpEntry';

const T = 'CASE_TICKETS.CONVERSATION_ACTIONS';
const F = 'ASSISTANT.AI_FOLLOW_UP';

export default {
  name: 'CaseConversationActions',
  components: {
    LinkConversationModal,
    ScheduleMessageModal,
    ContactTrackingModal,
    AiFollowUpModal,
    AiFollowUpStatus,
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
      showFollowUp: false,
      followUpLive: false, // hay un Seguimiento IA corriendo → botón verde
      customAgents: false, // la empresa tiene agentes a medida → se elige quién da el seguimiento
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
      const missing = [];
      const botOk =
        bot &&
        bot.enabled &&
        (bot.hooks || []).some(
          h => h.status === true && h.inbox && h.inbox.id === Number(inboxId)
        );
      if (!botOk)
        missing.push(this.$t('CONTACT_PANEL.INTEGRATION_WARNING.TRACKING_BOT'));
      return missing.concat(this.missingOpenai);
    },
    // Seguimiento IA solo necesita OpenAI activo (no el bot de seguimientos de la bandeja).
    missingOpenai() {
      const openai = (this.apps || []).find(a => a.id === 'openai');
      const aiOk =
        openai &&
        openai.enabled &&
        (openai.hooks || []).some(h => h.status === true);
      return aiOk ? [] : [this.$t('CONTACT_PANEL.INTEGRATION_WARNING.OPENAI')];
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
    f(key, params) {
      return this.$t(`${F}.${key}`, params);
    },
    openLegacy() {
      this.showFollowUp = false;
      this.run('legacy');
    },
    onFollowUpCreated(followUp) {
      this.showFollowUp = false;
      this.$refs.followUpStatus?.set(followUp);
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
    async run(action) {
      if (!this.displayId) {
        this.openLink(action);
        return;
      }
      if (!this.conversation) return; // todavía cargando
      if (action === 'schedule') {
        this.showSchedule = true;
        return;
      }
      // «Delegar» abre el Seguimiento IA (solo OpenAI); 'legacy' = «Vista anterior», el de siempre.
      const missing =
        action === 'legacy' ? this.missingIntegrations : this.missingOpenai;
      if (missing.length) {
        useAlert(this.t('DELEGATE_MISSING', { missing: missing.join(', ') }));
        return;
      }
      if (action === 'legacy') {
        this.showTracking = true;
        return;
      }
      // Ya corre un agente a medida para este cliente: se abre ese.
      const who = await whoFollows({ case_id: this.ticket.id });
      if (who.custom && !this.missingIntegrations.length) {
        this.showTracking = true;
        return;
      }
      this.customAgents = !!who.custom_agents;
      this.showFollowUp = true;
    },
  },
};
</script>

<template>
  <div class="flex flex-wrap items-center gap-2">
    <!-- Plan Actividad del caso — con principal, se agregan adicionales (el correo…) -->
    <woot-button size="small" variant="smooth" icon="link" @click="openLink()">
      {{ t(displayId ? 'ADD' : 'LINK') }}
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
      v-tooltip="f('BUTTON_HINT')"
      size="small"
      variant="smooth"
      :color-scheme="followUpLive ? 'success' : 'secondary'"
      icon="bot"
      @click="run('delegate')"
    >
      {{ f('BUTTON') }}
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
    <AiFollowUpModal
      v-if="showFollowUp && conversation"
      :show="showFollowUp"
      :ticket="ticket"
      :conversation-id="displayId"
      :custom-agents="customAgents"
      @close="showFollowUp = false"
      @created="onFollowUpCreated"
      @legacy="openLegacy"
    />
    <!-- Seguimiento IA: en qué va y pausar / reanudar / cancelar -->
    <AiFollowUpStatus
      ref="followUpStatus"
      :case-id="ticket.id"
      @change="followUpLive = $event"
    />
  </div>
</template>
