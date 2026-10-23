<script>
import InboxReconnectionRequired from '../components/InboxReconnectionRequired.vue';
import { useAlert } from 'dashboard/composables';
import instagramClient from '../../../../../api/channel/instagramClient';

export default {
  components: {
    InboxReconnectionRequired,
  },
  methods: {
    // Instagram no tiene un SDK de reautorización como Facebook: se rehace el mismo OAuth.
    // El callback reconoce la cuenta por su IGSID y actualiza el canal existente en vez de
    // crear uno nuevo.
    async startReauthorization() {
      try {
        const {
          data: { url },
        } = await instagramClient.generateAuthorization();
        window.location.href = url;
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.ADD.INSTAGRAM.ERROR_MESSAGE'));
      }
    },
  },
};
</script>

<template>
  <InboxReconnectionRequired
    class="mx-8 mt-5"
    @reauthorize="startReauthorization"
  />
</template>
