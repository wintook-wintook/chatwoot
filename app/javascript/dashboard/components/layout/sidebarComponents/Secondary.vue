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
import { useUISettings } from 'dashboard/composables/useUISettings';
import {
  UI_SETTINGS_KEY,
  INBOX_GROUPS,
  groupInboxes,
  groupOrderFromUISettings,
  inboxGroupFor,
  resolveOpenGroup,
  toggleOpenGroup,
} from 'dashboard/helper/inboxGroups'; // feat/bandejas_por_tipo
import InboxGroupsOrderModal from './InboxGroupsOrderModal.vue';
import { roomTitle } from '../../../views/internalChat/roomHelpers'; // feat/chat_interno

export default {
  components: {
    AccountContext,
    SecondaryNavItem,
    InboxGroupsOrderModal,
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
  setup() {
    const { uiSettings, updateUISettings } = useUISettings();
    return { uiSettings, updateUISettings };
  },
  data() {
    // Acordeón del menú secundario: `toState` del único grupo colapsable
    // abierto (null = todos plegados).
    return {
      openGroup: null,
      caseSettingsRequested: false, // @tickets_cases
      showInboxOrderModal: false, // feat/bandejas_por_tipo
      // Grupo de bandejas abierto (acordeón): '' = aún no elige → el primero;
      // null = todos cerrados.
      openInboxGroup: '',
    };
  },
  // @tickets_cases — los ítems con `visibleGetter` dependen de la configuración
  // del módulo de casos: se pide una vez cuando el menú los trae.
  watch: {
    // feat/bandejas_por_tipo: al entrar a una bandeja se abre su grupo.
    // (también cuando las bandejas terminan de cargar después de la ruta).
    '$route.params.inbox_id': {
      immediate: true,
      handler: 'openGroupOfCurrentInbox',
    },
    inboxes: 'openGroupOfCurrentInbox',
    // Menú v2: al estar en una pantalla de un grupo plegable, el grupo se abre.
    '$route.name': {
      immediate: true,
      handler(name) {
        const items = (this.menuConfig && this.menuConfig.menuItems) || [];
        const group = items.find(
          item =>
            item.collapsible &&
            (item.children || []).some(child => child.toStateName === name)
        );
        if (group) this.openGroup = group.toState;
        this.openGroupOfCurrentInbox(); // feat/chat_interno: en una sala, abre «Interno»
      },
    },
    menuConfig: {
      immediate: true,
      handler(config) {
        const needsSettings = ((config && config.menuItems) || []).some(
          item => item.visibleGetter
        );
        if (needsSettings && !this.caseSettingsRequested) {
          this.caseSettingsRequested = true;
          this.$store.dispatch('caseTickets/fetchSettings').catch(() => {});
        }
      },
    },
  },
  computed: {
    ...mapGetters({
      isFeatureEnabledonAccount: 'accounts/isFeatureEnabledonAccount',
      currentRole: 'getCurrentRole',
      getAccount: 'accounts/getAccount', // feat/chat_interno
      currentUserId: 'getCurrentUserID',
      internalChatRooms: 'internalChat/rooms',
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
        // @tickets_cases — permiso que decide el backend (p. ej. «Resumen del negocio»).
        if (item.visibleGetter) {
          return this.$store.getters[item.visibleGetter];
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
    
    // feat/bandejas_por_tipo — en vez de una sola carpeta «Bandejas de entrada», un
    // grupo por tipo de canal en el orden que eligió el agente (helper/inboxGroups.js).
    inboxGroupOrder() {
      return groupOrderFromUISettings(this.uiSettings, this.accountId);
    },
    inboxGroups() {
      return groupInboxes(this.inboxes, this.inboxGroupOrder);
    },
    inboxGroupCounts() {
      return Object.fromEntries(
        this.menuGroups.map(group => [
          group.key,
          group.internal ? group.rooms.length : group.inboxes.length,
        ])
      );
    },
    effectiveOpenInboxGroup() {
      return resolveOpenGroup(this.openInboxGroup, this.menuGroups);
    },
    canSeeInboxes() {
      return !(
        this.hideAllInboxForAgents && this.currentRole !== 'administrator'
      );
    },
    // feat/chat_interno: las salas del chat interno, como un grupo más («Interno»).
    internalChatEnabled() {
      const account = this.getAccount(this.accountId);
      return Boolean(account && account.internal_chat_enabled);
    },
    // Grupos del menú en el orden del agente: los de bandejas y, si está encendido, Interno.
    menuGroups() {
      const byKey = Object.fromEntries(
        this.inboxGroups.map(group => [group.key, group])
      );
      return this.inboxGroupOrder
        .map(key => {
          if (key === INBOX_GROUPS.INTERNAL) {
            return this.internalChatEnabled
              ? { key, internal: true, rooms: this.internalChatRooms }
              : null;
          }
          return byKey[key] || null;
        })
        .filter(Boolean);
    },
    inboxSections() {
      if (!this.canSeeInboxes) return [];
      const base = {
        icon: 'folder',
        hasSubMenu: true,
        toState: frontendURL(`accounts/${this.accountId}/settings/inboxes/new`),
        toStateName: 'settings_inbox_new',
        newLinkTag: 'NEW_INBOX',
        newLinkRouteName: 'settings_inbox_new',
      };
      const fallback = {
        ...base,
        label: 'INBOXES',
        key: 'inbox',
        newLink: this.showNewLink(FEATURE_FLAGS.INBOX_MANAGEMENT),
        children: [],
      };
      // Sin bandejas queda la carpeta de siempre, para no perder «Nueva bandeja».
      if (!this.inboxGroups.length) {
        return [...this.menuGroups.map(this.internalSection), fallback];
      }
      const lastInboxKey = this.inboxGroups.length
        ? this.menuGroups.filter(group => !group.internal).slice(-1)[0].key
        : null;
      // Título «Bandejas de entrada» arriba de los grupos (solo texto, no se pliega).
      const heading = {
        icon: 'folder',
        label: 'INBOXES',
        key: 'inbox_heading',
        children: [],
      };
      const groups = this.menuGroups.map(group => {
        if (group.internal) return this.internalSection(group);
        return {
          ...base,
          nested: true,
          label: `INBOX_GROUPS.${group.key.toUpperCase()}`,
          key: `inbox_group_${group.key}`,
          foldKey: group.key,
          folded: group.key !== this.effectiveOpenInboxGroup,
          labelCount: group.inboxes.length,
          // «Nueva bandeja» una sola vez, al final del último grupo de bandejas.
          newLink:
            group.key === lastInboxKey &&
            this.showNewLink(FEATURE_FLAGS.INBOX_MANAGEMENT),
          children: group.inboxes.map(inbox => ({
            id: inbox.id,
            label: inbox.name,
            truncateLabel: true,
            toState: frontendURL(
              `accounts/${this.accountId}/inbox/${inbox.id}`
            ),
            type: inbox.channel_type,
            phoneNumber: inbox.phone_number,
            reauthorizationRequired: inbox.reauthorization_required,
          })),
        };
      });
      return [heading, ...groups];
    },
    // Justo debajo de «No Atendidas»: abre el modal para ordenar los grupos.
    sortInboxesItem() {
      return {
        key: 'sort_inboxes',
        label: 'SORT_INBOXES',
        icon: 'arrow-sort',
        action: 'sortInboxes',
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
        childLimit: 10, // «Mostrar más» después de las primeras 10
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
        childLimit: 10, // «Mostrar más» después de las primeras 10
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
      let conversationMenuItems = [...this.inboxSections, this.labelSection];
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
      
      // feat/bandejas_por_tipo: la opción va primero, pegada a «No Atendidas».
      if (this.canSeeInboxes) {
        conversationMenuItems = [
          this.sortInboxesItem,
          ...conversationMenuItems,
        ];
      }
      return {
        conversations: conversationMenuItems,
        contacts: contactMenuItems,
        kanban: kanbanMenuItems,
      };
    },
  },
  methods: {
    // Acordeón: abrir uno cierra los demás; volver a tocar el abierto lo cierra.
    onFoldInboxGroup(key) {
      this.openInboxGroup = toggleOpenGroup(this.effectiveOpenInboxGroup, key);
    },
    openGroupOfCurrentInbox() {
      if (this.$route.name === 'internal_chat') {
        this.openInboxGroup = INBOX_GROUPS.INTERNAL;
        return;
      }
      const inboxId = Number(this.$route.params.inbox_id);
      const inbox = inboxId && this.inboxes.find(item => item.id === inboxId);
      if (inbox) this.openInboxGroup = inboxGroupFor(inbox);
    },
    // feat/chat_interno — el grupo «Interno»: una sala por renglón con sus no leídos y
    // «Nuevo chat» al final (abre el modal en la pantalla del chat).
    internalSection(group) {
      const url = path => frontendURL(`accounts/${this.accountId}/${path}`);
      const rooms = group.rooms.map(room => ({
        id: `internal_chat_${room.id}`,
        label: roomTitle(room, this.currentUserId, 'general'),
        truncateLabel: true,
        icon: room.kind === 'direct' ? 'person' : 'number-symbol',
        toState: url(`internal-chat/${room.id}`),
        count: room.unread_count ? room.unread_count : undefined,
      }));
      return {
        icon: 'chat-multiple',
        hasSubMenu: true,
        nested: true,
        label: 'INBOX_GROUPS.INTERNAL',
        key: 'inbox_group_internal',
        foldKey: group.key,
        folded: group.key !== this.effectiveOpenInboxGroup,
        labelCount: group.rooms.length,
        children: [
          ...rooms,
          {
            id: 'internal_chat_new',
            label: 'INTERNAL_CHAT_NEW',
            translate: true,
            icon: 'add',
            toState: url('internal-chat?new=1'),
          },
        ],
      };
    },
    onMenuAction(action) {
      if (action === 'sortInboxes') this.showInboxOrderModal = true;
    },
    saveInboxGroupOrder(order) {
      const byAccount =
        (this.uiSettings && this.uiSettings[UI_SETTINGS_KEY]) || {};
      this.updateUISettings({
        [UI_SETTINGS_KEY]: { ...byAccount, [this.accountId]: order },
      });
      this.showInboxOrderModal = false;
    },
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
        v-for="menuItem in additionalSecondaryMenuItems[
          menuConfig.extraSections || menuConfig.parentNav
        ]"
        :key="menuItem.key"
        :menu-item="menuItem"
        :open-group="openGroup"
        @toggleGroup="onToggleGroup"
        @addLabel="showAddLabelPopup"
        @addKanbanType="showAddKanbanTypePopup"
        @action="onMenuAction"
        @fold="onFoldInboxGroup"
      />
    </transition-group>
    <InboxGroupsOrderModal
      v-if="showInboxOrderModal"
      :order="inboxGroupOrder"
      :counts="inboxGroupCounts"
      @close="showInboxOrderModal = false"
      @save="saveInboxGroupOrder"
    />
  </div>
</template>