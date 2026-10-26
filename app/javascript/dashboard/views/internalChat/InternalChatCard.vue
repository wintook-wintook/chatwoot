<script>
// feat/chat_interno — UNA SALA EN LA LISTA con la tarjeta REAL de Chatwoot
// (ConversationCard en modo `standalone`): foto, nombre, último mensaje, hace cuánto y
// globo de no leídos idénticos a una conversación. Ver adapters.js.
import ConversationCard from 'dashboard/components/widgets/conversation/ConversationCard.vue';
import { roomContact, toChat } from './adapters';

export default {
  components: { ConversationCard },
  props: {
    room: { type: Object, required: true },
    currentUserId: { type: Number, required: true },
    isActive: { type: Boolean, default: false },
  },
  emits: ['select'],
  computed: {
    generalLabel() {
      return this.$t('INTERNAL_CHAT.GENERAL');
    },
    chat() {
      return toChat(this.room, this.currentUserId, this.generalLabel);
    },
    standalone() {
      return {
        contact: roomContact(this.room, this.currentUserId, this.generalLabel),
        isActive: this.isActive,
        onSelect: () => this.$emit('select', this.room),
      };
    },
  },
};
</script>

<template>
  <ConversationCard
    :chat="chat"
    :standalone="standalone"
    hide-inbox-name
    :enable-context-menu="false"
  />
</template>
