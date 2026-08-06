<script>
import { useAlert } from 'dashboard/composables';
import InboxReconnectionRequired from '../../components/InboxReconnectionRequired.vue';
import tiktokClient from 'dashboard/api/channel/tiktokClient';

export default {
  components: { InboxReconnectionRequired },
  data() {
    return { isRequestingAuthorization: false };
  },
  methods: {
    // Reautorizar es rehacer el mismo OAuth: el callback reconoce la cuenta por su
    // business_id y refresca las credenciales en vez de crear otro inbox.
    async requestAuthorization() {
      try {
        this.isRequestingAuthorization = true;
        const {
          data: { url },
        } = await tiktokClient.generateAuthorization();
        window.location.href = url;
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.ADD.TIKTOK.ERROR.FAILED'));
        this.isRequestingAuthorization = false;
      }
    },
  },
};
</script>

<template>
  <InboxReconnectionRequired class="mx-6" @reauthorize="requestAuthorization" />
</template>
