<script>
// KANBAN0725
import { mapGetters } from 'vuex';
import { getSidebarItems } from './config/default-sidebar';
import { useKeyboardEvents } from 'dashboard/composables/useKeyboardEvents';
import { useRoute, useRouter } from 'dashboard/composables/route';

import PrimarySidebar from './sidebarComponents/Primary.vue';
import SecondarySidebar from './sidebarComponents/Secondary.vue';
// import AddKanbanType from '../modals/AddKanbanType.vue'; // Ruta correcta: subir un nivel y entrar a modals
import { routesWithPermissions } from '../../routes';
import {
  getUserPermissions,
  hasPermissions,
} from '../../helper/permissionsHelper';

export default {
  components: {
    PrimarySidebar,
    SecondarySidebar,
   // AddKanbanType, // Registrar el modal
  },
  props: {
    showSecondarySidebar: {
      type: Boolean,
      default: true,
    },
    sidebarClassName: {
      type: String,
      default: '',
    },
  },
  setup(props, { emit }) {
    const route = useRoute();
    const router = useRouter();

    const toggleKeyShortcutModal = () => {
      emit('openKeyShortcutModal');
    };
    const closeKeyShortcutModal = () => {
      emit('closeKeyShortcutModal');
    };
    const isCurrentRouteSameAsNavigation = routeName => {
      return route.name === routeName;
    };
    const navigateToRoute = routeName => {
      if (!isCurrentRouteSameAsNavigation(routeName)) {
        router.push({ name: routeName });
      }
    };
    const keyboardEvents = {
      '$mod+Slash': {
        action: toggleKeyShortcutModal,
      },
      '$mod+Escape': {
        action: closeKeyShortcutModal,
      },
      'Alt+KeyC': {
        action: () => navigateToRoute('home'),
      },
      'Alt+KeyV': {
        action: () => navigateToRoute('contacts_dashboard'),
      },
      'Alt+KeyR': {
        action: () => navigateToRoute('account_overview_reports'),
      },
      'Alt+KeyS': {
        action: () => navigateToRoute('agent_list'),
      },
    };
    useKeyboardEvents(keyboardEvents);

    return {
      toggleKeyShortcutModal,
    };
  },
  data() {
    return {
      showOptionsMenu: false,
      // NUEVO: Estado para controlar el modal de kanban type
      showAddKanbanTypeModal: false,
    };
  },

  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      currentRole: 'getCurrentRole',
      currentUser: 'getCurrentUser',
      globalConfig: 'globalConfig/get',
      inboxes: 'inboxes/getInboxes',
      isACustomBrandedInstance: 'globalConfig/isACustomBrandedInstance',
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      isOnChatwootCloud: 'globalConfig/isOnChatwootCloud',
      labels: 'labels/getLabelsOnSidebar',
      teams: 'teams/getMyTeams',
    }),

    // NUEVA: Computed property para kanbanTypes
    kanbanTypes() {
      console.log('🔄 Sidebar: Computando kanbanTypes desde store...');
      
      const storeData = this.$store.state.kanbanTypeProcesses;
      console.log('📊 Sidebar: Store data:', storeData);
      
      if (!storeData || !storeData.records) {
        console.log('❌ Sidebar: No hay datos en el store');
        return [];
      }

      const types = Object.values(storeData.records).map(record => ({
        id: record.id,
        name: record.process_name,
        color: record.color || '#3b82f6', // Color por defecto
        default: record.default,
        is_system: record.is_system,
        account_id: record.account_id,
        created_at: record.created_at,
        updated_at: record.updated_at,
        kanban_processes: record.kanban_processes || [],
      }));

      console.log('✅ Sidebar: Kanban types mapeados:', types);
      return types;
    },

    activeCustomView() {
      if (this.activePrimaryMenu.key === 'contacts') {
        return 'contact';
      }
      if (this.activePrimaryMenu.key === 'conversations') {
        return 'conversation';
      }
      return '';
    },
    customViews() {
      return this.$store.getters['customViews/getCustomViewsByFilterType'](
        this.activeCustomView
      );
    },
    isConversationOrContactActive() {
      return (
        this.activePrimaryMenu.key === 'contacts' ||
        this.activePrimaryMenu.key === 'conversations'
      );
    },
    sideMenuConfig() {
      return getSidebarItems(this.accountId);
    },
    primaryMenuItems() {
      const userPermissions = getUserPermissions(
        this.currentUser,
        this.accountId
      );
      const menuItems = this.sideMenuConfig.primaryMenu;
      return menuItems.filter(menuItem => {
        if (
          menuItem.key === 'contacts' &&
          this.currentRole === 'agent' &&
          this.hideContactsForAgents
        ) {
          return false;
        }
        const isAvailableForTheUser = hasPermissions(
          routesWithPermissions[menuItem.toStateName],
          userPermissions
        );

        if (!isAvailableForTheUser) {
          return false;
        }
        if (
          menuItem.alwaysVisibleOnChatwootInstances &&
          !this.isACustomBrandedInstance
        ) {
          return true;
        }
        if (menuItem.featureFlag) {
          return this.isFeatureEnabledonAccount(
            this.accountId,
            menuItem.featureFlag
          );
        }
        return true;
      });
    },
    activeSecondaryMenu() {
      const { secondaryMenu } = this.sideMenuConfig;
      const { name: currentRoute } = this.$route;

      console.log('🔍 Debug Sidebar - Ruta actual:', currentRoute);
      console.log('🔍 Debug Sidebar - Menús secundarios:', secondaryMenu);

      const activeSecondaryMenu =
        secondaryMenu.find(menuItem => {
          const isRouteIncluded = menuItem.routes.includes(currentRoute);
          console.log(`🔍 Debug Sidebar - Menu ${menuItem.parentNav}:`, {
            routes: menuItem.routes,
            currentRoute,
            isIncluded: isRouteIncluded
          });
          return isRouteIncluded;
        }) || {};

      console.log('🔍 Debug Sidebar - Menu activo encontrado:', activeSecondaryMenu);
      return activeSecondaryMenu;
    },
    activePrimaryMenu() {
      const activePrimaryMenu =
        this.primaryMenuItems.find(
          menuItem => menuItem.key === this.activeSecondaryMenu.parentNav
        ) || {};
      return activePrimaryMenu;
    },
    hideContactsForAgents() {
      return (
        this.isFeatureEnabledonAccount(
          this.accountId,
          'hide_contacts_for_agent'
        ) && this.currentRole !== 'administrator'
      );
    },

    // NUEVO: Computed para determinar si debemos mostrar el sidebar secundario
    shouldShowSecondarySidebar() {
      const currentRoute = this.$route.name;

      // Rutas que siempre muestran el sidebar sin importar la preferencia del usuario
      const alwaysShowRoutes = [
        'kanban_dashboard', 'kanban_board', 'kanban_processes', 'kanban_label', 'kanban_status', 'kanban_type',
        'gestorTickets_index', 'gestorTickets_detail', 'gestorTickets_rules', 'gestorTickets_metrics', // @tickets_cases
      ];
      if (alwaysShowRoutes.includes(currentRoute)) return true;

      // Para el resto, respetar la preferencia del usuario
      if (!this.showSecondarySidebar) return false;
      return Object.keys(this.activeSecondaryMenu).length > 0;
    },
  },

  watch: {
    activeCustomView() {
      this.fetchCustomViews();
    },
    // NUEVO: Watch para recargar kanbanTypes cuando cambie la cuenta
    accountId: {
      handler(newAccountId) {
        if (newAccountId) {
          this.loadKanbanTypes();
        }
      },
      immediate: true,
    },
  },

  mounted() {
    this.$store.dispatch('labels/get');
    this.$store.dispatch('inboxes/get');
    this.$store.dispatch('notifications/unReadCount');
    this.$store.dispatch('teams/get');
    this.$store.dispatch('attributes/get');
    this.fetchCustomViews();
    // NUEVO: Cargar kanban types
    this.loadKanbanTypes();

    // DEBUG: Verificar configuración del sidebar
    console.log('🔍 Debug Sidebar mounted:');
    console.log('- Ruta actual:', this.$route.name);
    console.log('- activeSecondaryMenu:', this.activeSecondaryMenu);
    console.log('- shouldShowSecondarySidebar:', this.shouldShowSecondarySidebar);
  },

  methods: {
    fetchCustomViews() {
      if (this.isConversationOrContactActive) {
        this.$store.dispatch('customViews/get', this.activeCustomView);
      }
    },

    // NUEVO: Método para cargar kanban types
    async loadKanbanTypes() {
      try {
        console.log('🔄 Sidebar: Cargando kanbanTypes...');
        await this.$store.dispatch('kanbanTypeProcesses/get');
        console.log('✅ Sidebar: kanbanTypes cargados correctamente');
      } catch (error) {
        console.error('❌ Sidebar: Error cargando kanbanTypes:', error);
      }
    },

    // NUEVO: Método para manejar la creación de nuevos tipos
    showAddKanbanTypePopup() {
          console.log('AQUI🔄 Sidebar: Crear nuevo tipo de proceso');
          console.log('🔄 Sidebar: showAddKanbanTypeModal antes:', this.showAddKanbanTypeModal);
          this.showAddKanbanTypeModal = true;
          console.log('🔄 Sidebar: showAddKanbanTypeModal después:', this.showAddKanbanTypeModal); 
    },

    // NUEVO: Método para cerrar el modal y recargar datos
    onKanbanTypeModalClose() {
      this.showAddKanbanTypeModal = false;
      // Recargar los tipos de proceso
      this.loadKanbanTypes();
    },

    toggleSupportChatWindow() {
      window.$chatwoot.toggle();
    },
    toggleAccountModal() {
      this.$emit('toggleAccountModal');
    },
    showAddLabelPopup() {
      this.$emit('showAddLabelPopup');
    },
    openNotificationPanel() {
      this.$emit('openNotificationPanel');
    },
  },
};
</script>

<template>
  <aside class="flex h-full">
    <PrimarySidebar
      :logo-source="globalConfig.logoThumbnail"
      :installation-name="globalConfig.installationName"
      :is-a-custom-branded-instance="isACustomBrandedInstance"
      :account-id="accountId"
      :menu-items="primaryMenuItems"
      :active-menu-item="activePrimaryMenu.key"
      @toggleAccounts="toggleAccountModal"
      @openKeyShortcutModal="toggleKeyShortcutModal"
      @openNotificationPanel="openNotificationPanel"
    />
    <SecondarySidebar
      v-if="shouldShowSecondarySidebar"
      :class="sidebarClassName"
      :account-id="accountId"
      :inboxes="inboxes"
      :labels="labels"
      :teams="teams"
      :custom-views="customViews"
      :kanban-types="kanbanTypes"
      :menu-config="activeSecondaryMenu"
      :current-user="currentUser"
      :is-on-chatwoot-cloud="isOnChatwootCloud"
      @addLabel="showAddLabelPopup"
      @addKanbanType="showAddKanbanTypePopup"
      @toggleAccounts="toggleAccountModal"
    />

    <!-- Modal para crear nuevo tipo de proceso -->
    <!-- <woot-modal
      v-if="showAddKanbanTypeModal"
      :show="showAddKanbanTypeModal"
      @close="onKanbanTypeModalClose"
    >
      <AddKanbanType @close="onKanbanTypeModalClose" />
    </woot-modal> -->
  </aside>
</template>