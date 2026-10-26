<script>
import { useAlert } from 'dashboard/composables';
import instagramClient from '../../../../../api/channel/instagramClient';

export default {
  data() {
    return { isRequestingAuthorization: false };
  },
  mounted() {
    // El callback devuelve al agente aquí con ?error= cuando algo sale mal, porque en ese
    // punto no hay sesión con la que mostrar un mensaje desde el backend.
    const { error } = this.$route.query;
    if (error) {
      useAlert(
        this.$t(`INBOX_MGMT.ADD.INSTAGRAM.ERROR.${error.toUpperCase()}`)
      );
    }
  },
  methods: {
    async requestAuthorization() {
      try {
        this.isRequestingAuthorization = true;
        const {
          data: { url },
        } = await instagramClient.generateAuthorization();
        window.location.href = url;
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.ADD.INSTAGRAM.ERROR_MESSAGE'));
      } finally {
        this.isRequestingAuthorization = false;
      }
    },
  },
};
</script>

<template>
  <div
    class="border border-slate-25 dark:border-slate-800/60 bg-white dark:bg-slate-900 h-full p-6 w-full max-w-full md:w-3/4 md:max-w-[75%] flex-shrink-0 flex-grow-0"
  >
    <div class="login-init h-full text-center">
      <form @submit.prevent="requestAuthorization">
        <woot-submit-button
          icon="brand-instagram"
          :button-text="$t('INBOX_MGMT.ADD.INSTAGRAM.SIGN_IN')"
          type="submit"
          :loading="isRequestingAuthorization"
        />
      </form>
      <p>{{ $t('INBOX_MGMT.ADD.INSTAGRAM.HELP') }}</p>
    </div>
  </div>
</template>

<style scoped lang="scss">
.login-init {
  @apply pt-[30%] text-center;
  p {
    @apply p-6;
  }
  > a > img {
    @apply w-60;
  }
}
</style>
