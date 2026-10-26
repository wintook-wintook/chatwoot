<script>
// diag/llamadas_whatsapp (F5) — «Llamar» en la cabecera de la conversación.
// Solo si la bandeja permite llamadas salientes (inbox.whatsapp_calls.outbound, que
// manda el servidor). Llamar sin permiso del cliente lo pide (aviso en el widget).
import { mapGetters } from 'vuex';

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
    canCall() {
      const inbox = this.getInbox(this.conversation.inbox_id) || {};
      return Boolean(inbox.whatsapp_calls && inbox.whatsapp_calls.outbound);
    },
    isBusy() {
      return Boolean(this.active || this.incoming);
    },
  },
  methods: {
    call() {
      this.$store.dispatch('whatsappCalls/call', this.conversation);
    },
  },
};
</script>

<template>
  <woot-button
    v-if="canCall"
    v-tooltip.top="$t('WHATSAPP_CALLS.WIDGET.CALL_BUTTON_HINT')"
    icon="call"
    variant="smooth"
    color-scheme="success"
    size="small"
    :is-disabled="isBusy"
    @click="call"
  >
    {{ $t('WHATSAPP_CALLS.WIDGET.CALL_BUTTON') }}
  </woot-button>
</template>
