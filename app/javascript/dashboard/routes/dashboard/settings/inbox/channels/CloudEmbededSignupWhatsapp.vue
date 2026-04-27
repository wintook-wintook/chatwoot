<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required } from '@vuelidate/validators';
import router from '../../../../index';
import { isPhoneE164OrEmpty } from 'shared/helpers/Validators';

const FB_API_VERSION = 'v20.0';

export default {
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      inboxName: '',
      phoneNumber: '',
      phoneNumberId: '',
      businessAccountId: '',
      fbSdkLoaded: false,
      isConnecting: false,
      isConnected: false,
      isFetchingPhone: false,
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
    apiToken() {
      return this.globalConfig.whatsappEmbeddedFacebookToken;
    },
  },
  validations: {
    inboxName: { required },
    phoneNumber: { required, isPhoneE164OrEmpty },
    phoneNumberId: { required },
    businessAccountId: { required },
  },
  mounted() {
    if (this.appId) {
      this.loadFbSdk();
    }
    window.addEventListener('message', this.onFbMessage);
  },
  beforeUnmount() {
    window.removeEventListener('message', this.onFbMessage);
  },
  methods: {
    loadFbSdk() {
      const init = () => {
        window.FB.init({
          appId: this.appId,
          version: FB_API_VERSION,
          xfbml: false,
          cookie: false,
        });
        this.fbSdkLoaded = true;
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
        document.head.appendChild(script);
      }
    },
    onFbMessage(event) {
      if (event.origin !== 'https://www.facebook.com') return;
      try {
        const data = JSON.parse(event.data);
        if (data.type === 'WA_EMBEDDED_SIGNUP') {
          const { phone_number_id, waba_id } = data.data || {};
          if (phone_number_id) {
            this.phoneNumberId = String(phone_number_id);
            this.fetchPhoneNumber(phone_number_id);
          }
          if (waba_id) {
            this.businessAccountId = String(waba_id);
          }
        }
      } catch {
        // mensaje no-JSON de Facebook, ignorar
      }
    },
    launchSignup() {
      this.isConnecting = true;
      window.FB.login(
        response => {
          this.isConnecting = false;
          if (response.authResponse) {
            this.isConnected = true;
          } else {
            useAlert(
              this.$t('INBOX_MGMT.ADD.WHATSAPP_EMBEDDED.CONNECT_CANCELLED')
            );
          }
        },
        {
          config_id: this.configId,
          response_type: 'code',
          override_default_response_type: true,
          extras: {
            setup: {},
            featureName: 'whatsapp_embedded_signup',
            sessionInfoVersion: 2,
          },
        }
      );
    },
    async fetchPhoneNumber(phoneNumberId) {
      if (!this.apiToken || !phoneNumberId) return;
      this.isFetchingPhone = true;
      try {
        const res = await fetch(
          `https://graph.facebook.com/${FB_API_VERSION}/${phoneNumberId}?fields=display_phone_number&access_token=${this.apiToken}`
        );
        const json = await res.json();
        if (json.display_phone_number) {
          this.phoneNumber = '+' + json.display_phone_number.replace(/[^\d]/g, '');
        }
      } catch {
        // el usuario puede ingresarlo manualmente
      } finally {
        this.isFetchingPhone = false;
      }
    },
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) return;
      try {
        const channel = await this.$store.dispatch('inboxes/createChannel', {
          name: this.inboxName,
          channel: {
            type: 'whatsapp',
            phone_number: this.phoneNumber,
            provider: 'whatsapp_cloud',
            provider_config: {
              api_key: this.apiToken,
              phone_number_id: this.phoneNumberId,
              business_account_id: this.businessAccountId,
            },
          },
        });
        router.replace({
          name: 'settings_inboxes_add_agents',
          params: { page: 'new', inbox_id: channel.id },
        });
      } catch (error) {
        useAlert(
          error.message || this.$t('INBOX_MGMT.ADD.WHATSAPP.API.ERROR_MESSAGE')
        );
      }
    },
  },
};
</script>

<template>
  <form class="flex flex-wrap mx-0" @submit.prevent="createChannel()">
    <div class="w-[65%] flex-shrink-0 flex-grow-0 max-w-[65%] mb-6">
      <p class="text-sm text-slate-600 dark:text-slate-300 mb-4">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP_EMBEDDED.DESCRIPTION') }}
      </p>
      <woot-button
        type="button"
        :disabled="!fbSdkLoaded || isConnecting || isConnected"
        :loading="isConnecting"
        @click="launchSignup"
      >
        <span v-if="isConnected">
          ✓ {{ $t('INBOX_MGMT.ADD.WHATSAPP_EMBEDDED.CONNECTED') }}
        </span>
        <span v-else>
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_EMBEDDED.CONNECT_BUTTON') }}
        </span>
      </woot-button>
    </div>

    <template v-if="isConnected || phoneNumberId">
      <div class="w-[65%] flex-shrink-0 flex-grow-0 max-w-[65%]">
        <label :class="{ error: v$.inboxName.$error }">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.LABEL') }}
          <input
            v-model.trim="inboxName"
            type="text"
            :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.PLACEHOLDER')"
            @blur="v$.inboxName.$touch"
          />
          <span v-if="v$.inboxName.$error" class="message">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.ERROR') }}
          </span>
        </label>
      </div>

      <div class="w-[65%] flex-shrink-0 flex-grow-0 max-w-[65%]">
        <label :class="{ error: v$.phoneNumber.$error }">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.LABEL') }}
          <input
            v-model.trim="phoneNumber"
            type="text"
            :placeholder="
              isFetchingPhone
                ? $t('INBOX_MGMT.ADD.WHATSAPP_EMBEDDED.FETCHING_PHONE')
                : $t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.PLACEHOLDER')
            "
            :disabled="isFetchingPhone"
            @blur="v$.phoneNumber.$touch"
          />
          <span v-if="v$.phoneNumber.$error" class="message">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER.ERROR') }}
          </span>
        </label>
      </div>

      <div class="w-[65%] flex-shrink-0 flex-grow-0 max-w-[65%]">
        <label>
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.PHONE_NUMBER_ID.LABEL') }}
          <input
            v-model.trim="phoneNumberId"
            type="text"
            readonly
            class="cursor-default bg-slate-50 dark:bg-slate-800"
          />
        </label>
      </div>

      <div class="w-[65%] flex-shrink-0 flex-grow-0 max-w-[65%]">
        <label>
          {{ $t('INBOX_MGMT.ADD.WHATSAPP.BUSINESS_ACCOUNT_ID.LABEL') }}
          <input
            v-model.trim="businessAccountId"
            type="text"
            readonly
            class="cursor-default bg-slate-50 dark:bg-slate-800"
          />
        </label>
      </div>

      <div class="w-full">
        <woot-submit-button
          :loading="uiFlags.isCreating"
          :button-text="$t('INBOX_MGMT.ADD.WHATSAPP.SUBMIT_BUTTON')"
        />
      </div>
    </template>
  </form>
</template>
