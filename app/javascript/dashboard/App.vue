<script>
import { mapGetters } from 'vuex';
import router from '../dashboard/routes';
import AddAccountModal from '../dashboard/components/layout/sidebarComponents/AddAccountModal.vue';
import LoadingState from './components/widgets/LoadingState.vue';
import NetworkNotification from './components/NetworkNotification.vue';
import CaseToastNotification from './components/CaseToastNotification.vue';
import UpdateBanner from './components/app/UpdateBanner.vue';
import UpgradeBanner from './components/app/UpgradeBanner.vue';
import PaymentPendingBanner from './components/app/PaymentPendingBanner.vue';
import PendingEmailVerificationBanner from './components/app/PendingEmailVerificationBanner.vue';
import vueActionCable from './helper/actionCable';
import WootSnackbarBox from './components/SnackbarContainer.vue';
import {
  APPEARANCE_EVENT,
  applyColorTint,
  setColorTheme,
  setCompanyTint,
  syncAppearanceFromUser,
} from './helper/themeHelper';
import { isOnOnboardingView } from 'v3/helpers/RouteHelper';
import {
  registerSubscription,
  verifyServiceWorkerExistence,
} from './helper/pushHelper';
import ReconnectService from 'dashboard/helper/ReconnectService';
import Webphone from './components/layout/webphoneComponents/Webphone.vue';
import WhatsappCallWidget from './components/widgets/calls/WhatsappCallWidget.vue'; // diag/llamadas_whatsapp

export default {
  name: 'App',

  components: {
    AddAccountModal,
    LoadingState,
    NetworkNotification,
    CaseToastNotification,
    UpdateBanner,
    PaymentPendingBanner,
    WootSnackbarBox,
    UpgradeBanner,
    PendingEmailVerificationBanner,
    Webphone,
    WhatsappCallWidget,
  },
  data() {
    return {
      showAddAccountModal: false,
      latestChatwootVersion: null,
      reconnectService: null,
    };
  },

  computed: {
    ...mapGetters({
      getAccount: 'accounts/getAccount',
      isRTL: 'accounts/isRTL',
      currentUser: 'getCurrentUser',
      globalConfig: 'globalConfig/get',
      authUIFlags: 'getAuthUIFlags',
      accountUIFlags: 'accounts/getUIFlags',
      currentAccountId: 'getCurrentAccountId',
    }),
    hasAccounts() {
      const { accounts = [] } = this.currentUser || {};
      return accounts.length > 0;
    },
    companyTint() {
      const account = this.$store.getters['accounts/getAccount'](
        this.currentAccountId
      );
      return (account && account.brand && account.brand.tint) || '';
    },
    userAppearance() {
      const settings = (this.currentUser && this.currentUser.ui_settings) || {};
      const { appearance_mode: mode, appearance_tint: tint } = settings;
      return mode || tint ? `${mode || ''}|${tint || ''}` : '';
    },
    hideOnOnboardingView() {
      return !isOnOnboardingView(this.$route);
    },
  },

  watch: {
    currentUser() {
      if (!this.hasAccounts) {
        this.showAddAccountModal = true;
      }
    },
    // feat/apariencia: la apariencia guardada en el usuario gana a la del navegador
    // (al entrar y si cambia en otro dispositivo).
    // feat/apariencia B1: el color de la empresa (lo usa quien no eligió otro).
    companyTint: {
      immediate: true,
      handler(tint) {
        if (tint) setCompanyTint(tint);
      },
    },
    userAppearance: {
      immediate: true,
      handler(value) {
        if (value) syncAppearanceFromUser(this.currentUser.ui_settings);
      },
    },
    currentAccountId() {
      if (this.currentAccountId) {
        this.initializeAccount();
      }
    },
  },
  mounted() {
    this.initializeColorTheme();
    this.listenToThemeChanges();
    window.addEventListener(APPEARANCE_EVENT, this.saveAppearance);
    this.setLocale(window.chatwootConfig.selectedLocale);
  },
  beforeDestroy() {
    window.removeEventListener(APPEARANCE_EVENT, this.saveAppearance);
    if (this.reconnectService) {
      this.reconnectService.disconnect();
    }
  },
  methods: {
    initializeColorTheme() {
      setColorTheme(window.matchMedia('(prefers-color-scheme: dark)').matches);
      applyColorTint();
    },
    // feat/apariencia: lo que el agente elige en Perfil o en la barra de comandos.
    saveAppearance(event) {
      const { ui_settings: uiSettings = {} } = this.currentUser || {};
      this.$store.dispatch('updateUISettings', {
        uiSettings: { ...uiSettings, ...event.detail },
      });
    },
    listenToThemeChanges() {
      const mql = window.matchMedia('(prefers-color-scheme: dark)');
      mql.onchange = e => setColorTheme(e.matches);
    },
    setLocale(locale) {
      this.$root.$i18n.locale = locale;
    },
    async initializeAccount() {
      await this.$store.dispatch('accounts/get');
      this.$store.dispatch('setActiveAccount', {
        accountId: this.currentAccountId,
      });
      const { locale, latest_chatwoot_version: latestChatwootVersion } =
        this.getAccount(this.currentAccountId);
      const { pubsub_token: pubsubToken } = this.currentUser || {};
      this.setLocale(locale);
      this.latestChatwootVersion = latestChatwootVersion;
      vueActionCable.init(pubsubToken);
      this.reconnectService = new ReconnectService(this.$store, router);

      verifyServiceWorkerExistence(registration =>
        registration.pushManager.getSubscription().then(subscription => {
          if (subscription) {
            registerSubscription();
          }
        })
      );
    },
  },
};
</script>

<template>
  <div
    v-if="!authUIFlags.isFetching && !accountUIFlags.isFetchingItem"
    id="app"
    class="flex-grow-0 w-full h-full min-h-0 app-wrapper"
    :class="{ 'app-rtl--wrapper': isRTL }"
    :dir="isRTL ? 'rtl' : 'ltr'"
  >
    <Webphone />
    <WhatsappCallWidget v-if="currentAccountId" />
    <UpdateBanner :latest-chatwoot-version="latestChatwootVersion" />
    <template v-if="currentAccountId">
      <PendingEmailVerificationBanner v-if="hideOnOnboardingView" />
      <PaymentPendingBanner v-if="hideOnOnboardingView" />
      <UpgradeBanner />
    </template>
    <transition name="fade" mode="out-in">
      <router-view />
    </transition>
    <AddAccountModal :show="showAddAccountModal" :has-accounts="hasAccounts" />
    <WootSnackbarBox />
    <NetworkNotification />
    <CaseToastNotification />
  </div>
  <LoadingState v-else />
</template>

<style lang="scss">
@import './assets/scss/app';
</style>

<style src="vue-multiselect/dist/vue-multiselect.min.css"></style>
