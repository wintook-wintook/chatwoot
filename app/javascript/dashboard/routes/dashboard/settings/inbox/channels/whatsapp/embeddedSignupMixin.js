// diag/waba F3 — la ventana oficial de Meta (Embedded Signup) para «Reconectar con Meta».
// Misma lógica que CloudEmbededSignupWhatsapp.vue (el alta, que no se toca): carga el SDK de
// Facebook, abre FB.login con el config_id y junta el `code` con los datos que Meta manda por
// postMessage (business_id, waba_id, phone_number_id). Cuando tiene las dos cosas llama
// `this.onSignupComplete({ code, business_id, waba_id, phone_number_id })` del componente.
import { mapGetters } from 'vuex';

const FB_API_VERSION = 'v22.0';

export default {
  data() {
    // signupStarted: solo la instancia que abrió la ventana procesa la respuesta de Meta (puede
    // haber dos en pantalla: el aviso rojo y el botón del Diagnóstico).
    return {
      signupCode: null,
      signupData: null,
      signupOpen: false,
      signupStarted: false,
    };
  },
  computed: {
    ...mapGetters({ globalConfig: 'globalConfig/get' }),
    signupAppId() {
      return this.globalConfig.whatsappEmbeddedFacebookAppId;
    },
    signupConfigId() {
      return this.globalConfig.whatsappEmbeddedFacebookConfigId;
    },
    signupAvailable() {
      return !!(this.signupAppId && this.signupConfigId);
    },
  },
  mounted() {
    window.addEventListener('message', this.onSignupMessage);
    if (this.signupAppId) this.loadFacebookSdk();
  },
  beforeDestroy() {
    window.removeEventListener('message', this.onSignupMessage);
  },
  methods: {
    loadFacebookSdk() {
      const init = () =>
        window.FB.init({
          appId: this.signupAppId,
          autoLogAppEvents: true,
          xfbml: true,
          version: FB_API_VERSION,
        });
      if (window.FB) {
        init();
        return;
      }
      window.fbAsyncInit = init;
      if (document.getElementById('facebook-jssdk')) return;
      const script = document.createElement('script');
      script.id = 'facebook-jssdk';
      script.src = 'https://connect.facebook.net/en_US/sdk.js';
      script.async = true;
      script.defer = true;
      script.crossOrigin = 'anonymous';
      document.head.appendChild(script);
    },
    onSignupMessage(event) {
      if (!String(event.origin).endsWith('facebook.com')) return;
      let data;
      try {
        data =
          typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
      } catch {
        return;
      }
      if (!data || data.type !== 'WA_EMBEDDED_SIGNUP' || !this.signupStarted) {
        return;
      }
      if (data.event === 'CANCEL' || data.event === 'error') {
        this.resetSignup();
        this.onSignupCancel(data.error_message);
        return;
      }
      const info = data.data || {};
      if (info.business_id && info.waba_id) {
        this.signupData = {
          business_id: info.business_id,
          waba_id: info.waba_id,
          phone_number_id: info.phone_number_id || '',
        };
        this.maybeFinishSignup();
      }
    },
    openSignup() {
      if (!window.FB) return false;
      this.resetSignup();
      this.signupOpen = true;
      this.signupStarted = true;
      window.FB.login(
        response => {
          this.signupOpen = false;
          const code =
            response && response.authResponse && response.authResponse.code;
          if (!code) {
            this.resetSignup();
            this.onSignupCancel();
            return;
          }
          this.signupCode = code;
          this.maybeFinishSignup();
        },
        {
          config_id: this.signupConfigId,
          response_type: 'code',
          override_default_response_type: true,
          extras: {
            setup: {},
            featureType: 'whatsapp_business_app_onboarding',
            sessionInfoVersion: '3',
          },
        }
      );
      return true;
    },
    maybeFinishSignup() {
      if (!this.signupCode || !this.signupData) return;
      const payload = { code: this.signupCode, ...this.signupData };
      this.resetSignup();
      this.onSignupComplete(payload);
    },
    resetSignup() {
      this.signupCode = null;
      this.signupData = null;
      this.signupOpen = false;
      this.signupStarted = false;
    },
    // El componente los redefine.
    onSignupComplete() {},
    onSignupCancel() {},
  },
};
