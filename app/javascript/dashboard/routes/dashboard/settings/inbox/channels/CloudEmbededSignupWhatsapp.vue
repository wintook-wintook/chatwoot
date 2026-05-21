<script>
// proyecto@waba_chatwoot — componente reescrito con flujo OAuth correcto
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import router from '../../../../index';

const FB_API_VERSION = 'v22.0';

export default {
  data() {
    return {
      authCode: null,
      businessData: null,
      isAuthenticating: false,
      isProcessing: false,
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'inboxes/getUIFlags',
      globalConfig: 'globalConfig/get',
    }),
    appId() {
      return this.globalConfig.whatsappEmbeddedFacebookAppId;
    },
    configId() {
      return this.globalConfig.whatsappEmbeddedFacebookConfigId;
    },
    isConnected() {
      return this.authCode !== null && this.businessData !== null;
    },
  },
  mounted() {
    window.addEventListener('message', this.handleSignupMessage);
    if (this.appId) {
      this.setupFacebookSdk();
    }
  },
  beforeUnmount() {
    window.removeEventListener('message', this.handleSignupMessage);
  },
  methods: {
    setupFacebookSdk() {
      const init = () => {
        window.FB.init({
          appId: this.appId,
          autoLogAppEvents: true,
          xfbml: true,
          version: FB_API_VERSION,
        });
      };

      if (window.FB) {
        init();
        return;
      }

      window.fbAsyncInit = init;

      if (!document.getElementById('facebook-jssdk')) {
        const script = document.createElement('script');
        script.id = 'facebook-jssdk';
        script.src = 'https://connect.facebook.net/en_US/sdk.js';
        script.async = true;
        script.defer = true;
        script.crossOrigin = 'anonymous';
        document.head.appendChild(script);
      }
    },
    handleSignupMessage(event) {
      if (!event.origin.endsWith('facebook.com')) return;

      let data;
      try {
        data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
      } catch {
        return;
      }

      if (data.type !== 'WA_EMBEDDED_SIGNUP') return;

      const { event: signupEvent } = data;

      if (signupEvent === 'FINISH' || signupEvent === 'FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING') {
        const { business_id, waba_id, phone_number_id } = data.data || {};
        if (business_id && waba_id) {
          this.businessData = { business_id, waba_id, phone_number_id: phone_number_id || '' };
          if (this.authCode) {
            this.completeSignupFlow();
          }
        }
      } else if (signupEvent === 'CANCEL') {
        this.resetState();
      } else if (signupEvent === 'error') {
        useAlert(data.error_message || this.$t('INBOX_MGMT.ADD.WHATSAPP_EMBEDDED.CONNECT_CANCELLED'));
        this.resetState();
      }
    },
    async launchEmbeddedSignup() {
      if (!window.FB) {
        useAlert(this.$t('INBOX_MGMT.ADD.WHATSAPP_EMBEDDED.SDK_NOT_LOADED'));
        return;
      }
      this.isAuthenticating = true;
      window.FB.login(
        response => {
          this.isAuthenticating = false;
          if (response?.authResponse?.code) {
            this.authCode = response.authResponse.code;
            if (this.businessData) {
              this.completeSignupFlow();
            }
          } else {
            useAlert(this.$t('INBOX_MGMT.ADD.WHATSAPP_EMBEDDED.CONNECT_CANCELLED'));
          }
        },
        {
          config_id: this.configId,
          response_type: 'code',
          override_default_response_type: true,
          extras: {
            setup: {},
            featureType: 'whatsapp_business_app_onboarding',
            sessionInfoVersion: '3',
          },
        }
      );
    },
    async completeSignupFlow() {
      this.isProcessing = true;
      try {
        const inbox = await this.$store.dispatch(
          'inboxes/createWhatsAppEmbeddedSignup',
          {
            code: this.authCode,
            business_id: this.businessData.business_id,
            waba_id: this.businessData.waba_id,
            phone_number_id: this.businessData.phone_number_id,
          }
        );
        router.replace({
          name: 'settings_inboxes_add_agents',
          params: { page: 'new', inbox_id: inbox.id },
        });
      } catch (error) {
        useAlert(error.message || this.$t('INBOX_MGMT.ADD.WHATSAPP.API.ERROR_MESSAGE'));
        this.resetState();
      } finally {
        this.isProcessing = false;
      }
    },
    resetState() {
      this.authCode = null;
      this.businessData = null;
      this.isAuthenticating = false;
      this.isProcessing = false;
    },
  },
};
</script>

<template>
  <div class="w-[65%] flex-shrink-0 flex-grow-0 max-w-[65%]">
    <p class="text-sm text-slate-600 dark:text-slate-300 mb-4">
      {{ $t('INBOX_MGMT.ADD.WHATSAPP_EMBEDDED.DESCRIPTION') }}
    </p>

    <div v-if="isProcessing" class="flex items-center gap-2 text-sm text-slate-500">
      <span class="animate-spin">⟳</span>
      {{ $t('INBOX_MGMT.ADD.WHATSAPP_EMBEDDED.PROCESSING') }}
    </div>

    <template v-else>
      <woot-button
        type="button"
        :disabled="!appId || isAuthenticating || isConnected"
        :loading="isAuthenticating"
        @click="launchEmbeddedSignup"
      >
        <span v-if="isConnected">
          ✓ {{ $t('INBOX_MGMT.ADD.WHATSAPP_EMBEDDED.CONNECTED') }}
        </span>
        <span v-else>
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_EMBEDDED.CONNECT_BUTTON') }}
        </span>
      </woot-button>

      <p v-if="!appId" class="text-xs text-red-500 mt-2">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP_EMBEDDED.APP_ID_MISSING') }}
      </p>
    </template>
  </div>
</template>
