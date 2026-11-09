<script>
import { mapGetters } from 'vuex';
import PrimaryNavItem from './PrimaryNavItem.vue';
import OptionsMenu from './OptionsMenu.vue';
import AgentDetails from './AgentDetails.vue';
import QuickActions from './QuickActions.vue';
import NotificationBell from './NotificationBell.vue';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { ACCOUNT_EVENTS } from '../../../helper/AnalyticsHelper/events';
import WebphoneMinimized from './WebphoneMinimized.vue';

export default {
  components: {
    PrimaryNavItem,
    OptionsMenu,
    AgentDetails,
    QuickActions,
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
    // A dónde lleva el logo: Inicio (Mi resumen); sin casos, Conversaciones.
    homePath() {
      const home =
        this.menuItems.find(item => item.key === 'inicio') ||
        this.menuItems.find(item => item.key === 'conversations');
      return home ? home.toState : '';
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
      <QuickActions
        :logo-source="logoSource"
        :name="installationName"
        :home-path="homePath"
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
      <!-- El perfil va justo debajo de Ajustes; su menú se abre a la derecha de la foto. -->
      <div class="relative flex justify-center w-10 mt-1">
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
    <div class="flex flex-col items-center justify-end pb-6">
      <WebphoneMinimized />
      <!-- Dali y Ayuda viven en la barra de arriba (AssistantTopBar); Dali también con Ctrl + J. -->
    </div>
  </div>
</template>
