<script>
import { frontendURL } from '../../../helper/URLHelper';
import SecondaryNavItem from './SecondaryNavItem.vue';
import AccountContext from './AccountContext.vue';
import { mapGetters } from 'vuex';
import { FEATURE_FLAGS } from '../../../featureFlags';
import {
  getUserPermissions,
  hasPermissions,
} from '../../../helper/permissionsHelper';
import { routesWithPermissions } from '../../../routes';

export default {
  components: {
    AccountContext,
    SecondaryNavItem,
  },
  props: {
    accountId: {
      type: Number,
      default: 0,
    },
    labels: {
      type: Array,
      default: () => [],
    },
    inboxes: {
      type: Array,
      default: () => [],
    },
    teams: {
      type: Array,
      default: () => [],
    },
    customViews: {
      type: Array,
      default: () => [],
    },
    // Nueva prop para tipos de proceso kanban
    kanbanTypes: {
      type: Array,
      default: () => [],
    },
    menuConfig: {
      type: Object,
      default: () => {},
    },
    currentUser: {
      type: Object,
      default: () => {},
    },
    isOnChatwootCloud: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    // Acordeón del menú secundario: `toState` del único grupo colapsable
    // abierto (null = todos plegados).
    return {
      openGroup: null,
    };
  },
  computed: {
    ...mapGetters({
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      currentRole: 'getCurrentRole',
    }),
    hasSecondaryMenu() {
      return this.menuConfig.menuItems && this.menuConfig.menuItems.length;
    },
    contactCustomViews() {
      return this.customViews.filter(view => view.filter_type === 'contact');
    },
    accessibleMenuItems() {
      if (!this.currentRole) {
        return [];
      }
      const menuItemsFilteredByPermissions = this.menuConfig.menuItems.filter(
        menuItem => {
          const userPermissions = getUserPermissions(
            this.currentUser,
            this.accountId
          );
          return hasPermissions(
            routesWithPermissions[menuItem.toStateName],
            userPermissions
          );
        }
      );
      return menuItemsFilteredByPermissions.filter(item => {
        if (item.showOnlyOnCloud) {
          return this.isOnChatwootCloud;
        }
        return true;
      });
    },

    hideAllInboxForAgents() {
      return (
        this.isFeatureEnabledonAccount(
          this.accountId,
          'hide_all_inbox_for_agent'
        ) && this.currentRole !== 'administrator'
      );
    },
    
    inboxSection() {
      if (this.hideAllInboxForAgents && this.currentRole !== 'administrator') {
        return {};
      }
      return {
        icon: 'folder',
        label: 'INBOXES',
        hasSubMenu: true,
        newLink: this.showNewLink(FEATURE_FLAGS.INBOX_MANAGEMENT),
        newLinkTag: 'NEW_INBOX',
        key: 'inbox',
        toState: frontendURL(`accounts/${this.accountId}/settings/inboxes/new`),
        toStateName: 'settings_inbox_new',
        newLinkRouteName: 'settings_inbox_new',
        children: this.inboxes
          .map(inbox => ({
            id: inbox.id,
            label: inbox.name,
            truncateLabel: true,
            toState: frontendURL(
              `accounts/${this.accountId}/inbox/${inbox.id}`
            ),
            type: inbox.channel_type,
            phoneNumber: inbox.phone_number,
            reauthorizationRequired: inbox.reauthorization_required,
          }))
          .sort((a, b) =>
            a.label.toLowerCase() > b.label.toLowerCase() ? 1 : -1
          ),
      };
    },

    labelSection() {
      return {
        icon: 'number-symbol',
        label: 'LABELS',
        hasSubMenu: true,
        newLink: this.showNewLink(FEATURE_FLAGS.TEAM_MANAGEMENT),
        newLinkTag: 'NEW_LABEL',
        key: 'label',
        toState: frontendURL(`accounts/${this.accountId}/settings/labels`),
        toStateName: 'labels_list',
        showModalForNewItem: true,
        modalName: 'AddLabel',
        dataTestid: 'sidebar-new-label-button',
        children: this.labels.map(label => ({
          id: label.id,
          label: label.title,
          color: label.color,
          truncateLabel: true,
          toState: frontendURL(
            `accounts/${this.accountId}/label/${label.title}`
          ),
        })),
      };
    },

    contactLabelSection() {
      return {
        icon: 'number-symbol',
        label: 'TAGGED_WITH',
        hasSubMenu: true,
        key: 'label',
        newLink: this.showNewLink(FEATURE_FLAGS.TEAM_MANAGEMENT),
        newLinkTag: 'NEW_LABEL',
        toState: frontendURL(`accounts/${this.accountId}/settings/labels`),
        toStateName: 'labels_list',
        showModalForNewItem: true,
        modalName: 'AddLabel',
        children: this.labels.map(label => ({
          id: label.id,
          label: label.title,
          color: label.color,
          truncateLabel: true,
          toState: frontendURL(
            `accounts/${this.accountId}/labels/${label.title}/contacts`
          ),
        })),
      };
    },

    //KANBAN0725 - inicio
    kanbanLabelSection() {
      return {
        icon: 'number-symbol',
        label: 'LABELS',
        hasSubMenu: true,
        key: 'kanban_label',
        newLink: this.showNewLink(FEATURE_FLAGS.TEAM_MANAGEMENT),
        newLinkTag: 'NEW_LABEL',
        toState: frontendURL(`accounts/${this.accountId}/settings/labels`),
        toStateName: 'labels_list',
        showModalForNewItem: true,
        modalName: 'AddLabel',
        dataTestid: 'sidebar-kanban-new-label-button',
        children: this.labels.map(label => ({
          id: label.id,
          label: label.title,
          color: label.color,
          truncateLabel: true,
          toState: frontendURL(
            `accounts/${this.accountId}/kanban/label/${label.title}`
          ),
        })),
      };
    },
    //KANBAN0725 - fin

    //KANBAN0725 - INI para los estados
    kanbanStatesSection() {
      return {
        icon: 'workflow', // o 'status' o 'clipboard-flow'
        label: 'ESTADOS', // o 'KANBAN_STATES'
        hasSubMenu: true,
        key: 'kanban_states',
        // No necesita newLink ya que los estados son fijos
        children: [
          {
            id: 'open',
            label: 'AQUI CONTACTO INICIAL',
            color: '#3b82f6', // Azul para contacto inicial
            truncateLabel: false,
            toState: frontendURL(
              `accounts/${this.accountId}/kanban/status/open`
            ),
          },
          {
            id: 'pending', 
            label: 'NECESIDADES',
            color: '#f59e0b', // Amarillo para en progreso
            truncateLabel: false,
            toState: frontendURL(
              `accounts/${this.accountId}/kanban/status/pending`
            ),
          },
          {
            id: 'resolved',
            label: 'CIERRE', 
            color: '#10b981', // Verde para completado
            truncateLabel: false,
            toState: frontendURL(
              `accounts/${this.accountId}/kanban/status/resolved`
            ),
          },
          {
            id: 'helpme',
            label: 'POSTVENTA',
            color: '#8b5cf6', // Púrpura para postventa
            truncateLabel: false,
            toState: frontendURL(
              `accounts/${this.accountId}/kanban/status/snoozed`
            ),
          },
        ],
      };
    }, 
    //KANBAN0725 -FIN para los estados 

    // Nueva sección para tipos de proceso kanban
    kanbanTypesSection() {
      return {
        icon: 'clipboard-list', // Icono para tipos de proceso
        label: 'TIPO_DE_PROCESO',
        hasSubMenu: true,
        key: 'kanban_types',
        newLink: this.showNewLink(FEATURE_FLAGS.TEAM_MANAGEMENT),
        newLinkTag: 'NEW_KANBAN_TYPE',
        // toState: frontendURL(`accounts/${this.accountId}/settings/kanban`),
        toState: frontendURL(`accounts/${this.accountId}/settings/kanban`),
        toStateName: 'kanban_types_list',
        showModalForNewItem: true,
        modalName: 'AddKanbanType',
        dataTestid: 'sidebar-kanban-new-type-button',
        children: this.kanbanTypes.map(kanbanType => ({
          id: kanbanType.id,
          label: kanbanType.name,
          color: kanbanType.color || '#3b82f6',
          truncateLabel: true,
          toState: frontendURL(
            `accounts/${this.accountId}/kanban/type/${kanbanType.id}`
          ),
        })),
      };
    },

    teamSection() {
      return {
        icon: 'people-team',
        label: 'TEAMS',
        hasSubMenu: true,
        newLink: this.showNewLink(FEATURE_FLAGS.TEAM_MANAGEMENT),
        newLinkTag: 'NEW_TEAM',
        key: 'team',
        toState: frontendURL(`accounts/${this.accountId}/settings/teams/new`),
        toStateName: 'settings_teams_new',
        newLinkRouteName: 'settings_teams_new',
        children: this.teams.map(team => ({
          id: team.id,
          label: team.name,
          truncateLabel: true,
          toState: frontendURL(`accounts/${this.accountId}/team/${team.id}`),
        })),
      };
    },

    foldersSection() {
      return {
        icon: 'folder',
        label: 'CUSTOM_VIEWS_FOLDER',
        hasSubMenu: true,
        key: 'custom_view',
        children: this.customViews
          .filter(view => view.filter_type === 'conversation')
          .map(view => ({
            id: view.id,
            label: view.name,
            truncateLabel: true,
            toState: frontendURL(
              `accounts/${this.accountId}/custom_view/${view.id}`
            ),
          })),
      };
    },

    contactSegmentsSection() {
      return {
        icon: 'folder',
        label: 'CUSTOM_VIEWS_SEGMENTS',
        hasSubMenu: true,
        key: 'custom_view',
        children: this.customViews
          .filter(view => view.filter_type === 'contact')
          .map(view => ({
            id: view.id,
            label: view.name,
            truncateLabel: true,
            toState: frontendURL(
              `accounts/${this.accountId}/contacts/custom_view/${view.id}`
            ),
          })),
      };
    },

    additionalSecondaryMenuItems() {
      let conversationMenuItems = [this.inboxSection, this.labelSection];
      let contactMenuItems = [this.contactLabelSection];
      
      //KANBAN0725 - INI - Agregando tipos de proceso a kanban
      let kanbanMenuItems = [
       // this.kanbanStatesSection, 
        this.kanbanTypesSection, // Nueva sección para tipos de proceso
        //this.kanbanLabelSection
      ];
      //KANBAN0725 - FIN 
      
      if (this.teams.length) {
        conversationMenuItems = [this.teamSection, ...conversationMenuItems];
      }
      if (this.customViews.length) {
        conversationMenuItems = [this.foldersSection, ...conversationMenuItems];
      }
      if (this.contactCustomViews.length) {
        contactMenuItems = [this.contactSegmentsSection, ...contactMenuItems];
      }
      
      return {
        conversations: conversationMenuItems,
        contacts: contactMenuItems,
        kanban: kanbanMenuItems,
      };
    },
  },
  methods: {
    onToggleGroup(groupId) {
      this.openGroup = groupId;
    },
    showAddLabelPopup() {
      this.$emit('addLabel');
    },
    // Nuevo método para tipos de proceso kanban
    showAddKanbanTypePopup() {
      console.log('🔄 Secondary: showAddKanbanTypePopup llamado');
      console.log('🔄 Secondary: Emitiendo evento addKanbanType');
      this.$emit('addKanbanType');
    },

    toggleAccountModal() {
      this.$emit('toggleAccounts');
    },
    showNewLink(featureFlag) {
      return this.isFeatureEnabledonAccount(this.accountId, featureFlag);
    },
  },
};
</script>

<template>
  <div
    v-if="hasSecondaryMenu"
    class="flex flex-col h-full px-2 pb-8 overflow-auto text-sm bg-white border-r w-48 dark:bg-slate-900 dark:border-slate-800/50 rtl:border-r-0 rtl:border-l border-slate-50"
  >
    <div class="flex items-center justify-between pt-2 mb-2">
      <AccountContext @toggleAccounts="toggleAccountModal" />
    </div>

    <!-- Menú items -->
    <transition-group name="menu-list" tag="ul" class="mb-0 ml-0 list-none">
      <SecondaryNavItem
        v-for="menuItem in accessibleMenuItems"
        :key="menuItem.toState"
        :menu-item="menuItem"
        :open-group="openGroup"
        @toggleGroup="onToggleGroup"
      />
      <SecondaryNavItem
        v-for="menuItem in additionalSecondaryMenuItems[menuConfig.parentNav]"
        :key="menuItem.key"
        :menu-item="menuItem"
        :open-group="openGroup"
        @toggleGroup="onToggleGroup"
        @addLabel="showAddLabelPopup"
        @addKanbanType="showAddKanbanTypePopup"
      />
    </transition-group>
  </div>
</template>