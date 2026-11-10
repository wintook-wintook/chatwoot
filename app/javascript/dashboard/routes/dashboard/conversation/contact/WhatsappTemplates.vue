<script>
import { chatVariableContext } from 'dashboard/helper/whatsappTemplateVariables';
import TemplatesPicker from 'dashboard/components/widgets/conversation/WhatsappTemplates/TemplatesPicker.vue';
import TemplateParser from 'dashboard/components/widgets/conversation/WhatsappTemplates/TemplateParser.vue';
export default {
  components: {
    TemplatesPicker,
    TemplateParser,
  },
  props: {
    inboxId: {
      type: Number,
      default: undefined,
    },
    contact: {
      type: Object,
      default: null,
    },
  },
  data() {
    return {
      selectedWaTemplate: null,
    };
  },
  computed: {
    // feat/plantillas_whatsapp_mejoras F2: en WhatsApp Cloud la plantilla sale completa.
    isCloud() {
      const inbox = this.$store.getters['inboxes/getInbox'](this.inboxId);
      return Boolean(inbox && inbox.provider === 'whatsapp_cloud');
    },
    variableContext() {
      return chatVariableContext({
        contact: this.contact,
        inbox: this.$store.getters['inboxes/getInbox'](this.inboxId),
        currentUser: this.$store.getters.getCurrentUser,
      });
    },
  },
  methods: {
    pickTemplate(template) {
      this.$emit('pickTemplate', true);
      this.selectedWaTemplate = template;
    },
    onResetTemplate() {
      this.$emit('pickTemplate', false);
      this.selectedWaTemplate = null;
    },
    onSendMessage(message) {
      this.$emit('onSend', message);
    },
    onClose() {
      this.$emit('cancel');
    },
  },
};
</script>

<template>
  <div class="flex flex-wrap mx-0">
    <TemplatesPicker
      v-if="!selectedWaTemplate"
      :inbox-id="inboxId"
      @onSelect="pickTemplate"
    />
    <TemplateParser
      v-else
      :template="selectedWaTemplate"
      :full-template="isCloud"
      :inbox-id="inboxId"
      :variable-context="variableContext"
      @resetTemplate="onResetTemplate"
      @sendMessage="onSendMessage"
    />
  </div>
</template>
