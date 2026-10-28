<script>
// diag/llamadas_whatsapp (F5) — «Llamar» en la cabecera de la conversación.
// Aparece siempre en las conversaciones de WhatsApp: activo si la bandeja permite
// llamadas salientes (inbox.whatsapp_calls.outbound, que manda el servidor) y, si no,
// desactivado con el motivo al pasar el mouse (llamadas sin activar en la bandeja, o una
// conexión que no las admite: solo la API oficial de Meta las tiene). Llamar sin permiso
// del cliente lo pide (aviso en el widget).
import { mapGetters } from 'vuex';
import { INBOX_TYPES } from 'shared/mixins/inboxMixin';

export default {
  props: {
    conversation: { type: Object, required: true },
  },
  computed: {
    ...mapGetters({
      getInbox: 'inboxes/getInbox',
      active: 'whatsappCalls/getActive',
      incoming: 'whatsappCalls/getIncoming',
    }),
    inbox() {
      return this.getInbox(this.conversation.inbox_id) || {};
    },
    isWhatsApp() {
      const { channel_type: type, medium } = this.inbox;
      return (
        type === INBOX_TYPES.WHATSAPP ||
        (type === INBOX_TYPES.TWILIO && medium === 'whatsapp')
      );
    },
    // El servidor solo manda whatsapp_calls en las bandejas que pueden tener llamadas.
    supportsCalls() {
      return Boolean(this.inbox.whatsapp_calls);
    },
    canCall() {
      return this.supportsCalls && Boolean(this.inbox.whatsapp_calls.outbound);
    },
    isBusy() {
      return Boolean(this.active || this.incoming);
    },
    isDisabled() {
      return !this.canCall || this.isBusy;
    },
    hint() {
      if (!this.supportsCalls)
        return this.$t('WHATSAPP_CALLS.WIDGET.CALL_BUTTON_UNSUPPORTED');
      if (!this.canCall)
        return this.$t('WHATSAPP_CALLS.WIDGET.CALL_BUTTON_OFF', {
          inbox: this.inbox.name,
        });
      if (this.isBusy) return this.$t('WHATSAPP_CALLS.WIDGET.CALL_BUTTON_BUSY');
      return this.$t('WHATSAPP_CALLS.WIDGET.CALL_BUTTON_HINT');
    },
  },
  methods: {
    call() {
      if (this.isDisabled) return;
      this.$store.dispatch('whatsappCalls/call', this.conversation);
    },
  },
};
</script>

<template>
  <!-- El aviso va en el contenedor: un botón desactivado no muestra su tooltip. -->
  <span v-if="isWhatsApp" v-tooltip.top="hint" class="inline-flex">
    <button
      type="button"
      class="inline-flex items-center gap-1.5 h-8 px-3 text-sm font-medium border rounded-full transition-colors"
      :class="
        isDisabled
          ? 'cursor-not-allowed border-slate-100 bg-slate-25 text-slate-400 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-500'
          : 'border-green-200 bg-green-50 text-green-700 hover:bg-green-100 hover:border-green-300 dark:border-green-800 dark:bg-green-900/30 dark:text-green-300 dark:hover:bg-green-900/50'
      "
      :disabled="isDisabled"
      :aria-label="hint"
      @click="call"
    >
      <span
        v-if="isBusy && canCall"
        class="w-2 h-2 bg-green-500 rounded-full animate-pulse"
      />
      <fluent-icon v-else icon="call" size="14" />
      {{
        isBusy && canCall
          ? $t('WHATSAPP_CALLS.WIDGET.CALL_BUTTON_IN_CALL')
          : $t('WHATSAPP_CALLS.WIDGET.CALL_BUTTON')
      }}
    </button>
  </span>
</template>
