<script>
import { mapGetters } from 'vuex';
import Logo from './Logo.vue';
import PrimaryNavItem from './PrimaryNavItem.vue';
import OptionsMenu from './OptionsMenu.vue';
import AgentDetails from './AgentDetails.vue';
import NotificationBell from './NotificationBell.vue';
import wootConstants from 'dashboard/constants/globals';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { ACCOUNT_EVENTS } from '../../../helper/AnalyticsHelper/events';
import WebphoneMinimized from './WebphoneMinimized.vue';

export default {
  components: {
    Logo,
    PrimaryNavItem,
    OptionsMenu,
    AgentDetails,
    NotificationBell,
    WebphoneMinimized,
  },
  props: {
    logoSource: {
      type: String,
      default: '',
    },
    installationName: {
      type: String,
      default: '',
    },
    accountId: {
      type: Number,
      default: 0,
    },
    menuItems: {
      type: Array,
      default: () => [],
    },
    activeMenuItem: {
      type: String,
      default: '',
    },
  },
  data() {
    return {
      helpDocsURL: window.chatwootConfig?.helpDocsURL || wootConstants.DOCS_URL,
      showOptionsMenu: false,
    };
  },
  computed: {
    ...mapGetters({ notificationMetadata: 'notifications/getMeta' }),
    // Los avisos sin leer van en el ícono de Inicio (su menú tiene Notificaciones).
    unreadNotifications() {
      const { unreadCount } = this.notificationMetadata;
      if (!unreadCount) return '';
      return unreadCount < 100 ? `${unreadCount}` : '99+';
    },
    // Sin Inicio (cuenta sin casos) no hay dónde verlos: vuelve la campanita.
    hasHomeArea() {
      return this.menuItems.some(item => item.key === 'inicio');
    },
  },
  methods: {
    frontendURL,
    toggleOptions() {
      this.showOptionsMenu = !this.showOptionsMenu;
    },
    toggleAccountModal() {
      this.$emit('toggleAccounts');
    },
    toggleSupportChatWindow() {
      window.$chatwoot.toggle();
    },
    openNotificationPanel() {
      this.$track(ACCOUNT_EVENTS.OPENED_NOTIFICATIONS);
      this.$emit('openNotificationPanel');
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col justify-between w-16 h-full bg-white border-r dark:bg-slate-900 border-slate-50 dark:border-slate-800/50 rtl:border-l rtl:border-r-0"
  >
    <div class="flex flex-col items-center">
      <Logo
        :source="logoSource"
        :name="installationName"
        :account-id="accountId"
        class="m-4 mb-2"
      />
      <NotificationBell
        v-if="!hasHomeArea"
        class="!mb-2"
        @openNotificationPanel="openNotificationPanel"
      />
      <PrimaryNavItem
        v-for="menuItem in menuItems"
        :key="menuItem.toState"
        :icon="menuItem.icon"
        :name="menuItem.label"
        :to="menuItem.toState"
        :area="menuItem.key"
        :count="menuItem.key === 'inicio' ? unreadNotifications : ''"
        :is-child-menu-active="menuItem.key === activeMenuItem"
      />
    </div>
    <div class="flex flex-col items-center justify-end pb-6">
      <WebphoneMinimized />
      <!-- El foro de Kontrolya (antes el manual de Chatwoot, solo sin marca propia). -->
      <PrimaryNavItem
        icon="chat-help"
        name="DOCS"
        open-in-new-page
        :to="helpDocsURL"
      />
      <AgentDetails @toggleMenu="toggleOptions" />
      <OptionsMenu
        :show="showOptionsMenu"
        @toggleAccounts="toggleAccountModal"
        @showSupportChatWindow="toggleSupportChatWindow"
        @openKeyShortcutModal="$emit('openKeyShortcutModal')"
        @close="toggleOptions"
      />
    </div>
  </div>
</template>
