<script>
import TemplatesPicker from './TemplatesPicker.vue';
import TemplateParser from './TemplateParser.vue';
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
    show: {
      type: Boolean,
      default: true,
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
    modalHeaderContent() {
      return this.selectedWaTemplate
        ? this.$t('WHATSAPP_TEMPLATES.MODAL.TEMPLATE_SELECTED_SUBTITLE', {
            templateName: this.selectedWaTemplate.name,
          })
        : this.$t('WHATSAPP_TEMPLATES.MODAL.SUBTITLE');
    },
  },
  methods: {
    pickTemplate(template) {
      this.selectedWaTemplate = template;
    },
    onResetTemplate() {
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

<!-- eslint-disable vue/no-mutating-props -->
<template>
  <woot-modal :show.sync="show" :on-close="onClose" size="modal-big">
    <woot-modal-header
      :header-title="$t('WHATSAPP_TEMPLATES.MODAL.TITLE')"
      :header-content="modalHeaderContent"
    />
    <div class="row modal-content">
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
        @resetTemplate="onResetTemplate"
        @sendMessage="onSendMessage"
      />
    </div>
  </woot-modal>
</template>

<style scoped>
.modal-content {
  padding: 1.5625rem 2rem;
}
</style>
