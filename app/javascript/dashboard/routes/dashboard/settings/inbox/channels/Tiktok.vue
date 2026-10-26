<script>
import { useAlert } from 'dashboard/composables';
import Banner from 'dashboard/components/ui/Banner.vue';
import tiktokClient from '../../../../../api/channel/tiktokClient';

// Motivos con los que Tiktok::CallbacksController devuelve al usuario aquí.
const ERROR_REASONS = [
  'denied',
  'invalid_state',
  'missing_code',
  'ungranted_scopes',
  'already_connected',
  'failed',
];

export default {
  components: { Banner },
  data() {
    return { isRequestingAuthorization: false, errorReason: '' };
  },
  computed: {
    errorMessage() {
      if (!this.errorReason) return '';
      return this.$t(
        `INBOX_MGMT.ADD.TIKTOK.ERROR.${this.errorReason.toUpperCase()}`
      );
    },
  },
  mounted() {
    const reason = new URLSearchParams(window.location.search).get('error');
    // Solo se muestran los motivos que conocemos: el parámetro llega por la URL y
    // pintarlo tal cual permitiría inyectar texto arbitrario en la pantalla.
    if (ERROR_REASONS.includes(reason)) {
      this.errorReason = reason;
    }
    // Se limpia la URL para que al recargar no reaparezca el error de un intento viejo.
    window.history.replaceState({}, document.title, window.location.pathname);
  },
  methods: {
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
  <div
    class="border border-slate-25 dark:border-slate-800/60 bg-white dark:bg-slate-900 h-full p-6 w-full max-w-full md:w-3/4 md:max-w-[75%] flex-shrink-0 flex-grow-0"
  >
    <div class="h-full pt-[20%] text-center">
      <Banner
        v-if="errorMessage"
        color-scheme="alert"
        class="justify-start mb-6 text-left rounded-md"
        :banner-message="errorMessage"
      />
      <form @submit.prevent="requestAuthorization">
        <woot-submit-button
          icon="brand-tiktok"
          :button-text="$t('INBOX_MGMT.ADD.TIKTOK.CONTINUE_WITH_TIKTOK')"
          type="submit"
          :loading="isRequestingAuthorization"
        />
      </form>
      <p class="p-6">{{ $t('INBOX_MGMT.ADD.TIKTOK.HELP') }}</p>
    </div>
  </div>
</template>
