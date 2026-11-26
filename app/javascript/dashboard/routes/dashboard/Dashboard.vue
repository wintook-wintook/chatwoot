<script>
import Sidebar from '../../components/layout/Sidebar.vue';
import AssistantPanel from 'dashboard/components/assistant/AssistantPanel.vue'; // Asistente (Dali)
import AssistantTopBar from 'dashboard/components/assistant/AssistantTopBar.vue'; // barra «Pregúntale a Dali…»
import DaliReturnButton from 'dashboard/components/assistant/DaliReturnButton.vue'; // portal de Dali → «Volver a Dali»
import CaseConflictModal from 'dashboard/components/caseConflict/CaseConflictModal.vue'; // K1 — dos personas en el mismo caso
import { BUS_EVENTS } from 'shared/constants/busEvents';
import WootKeyShortcutModal from 'dashboard/components/widgets/modal/WootKeyShortcutModal.vue';
import AddAccountModal from 'dashboard/components/layout/sidebarComponents/AddAccountModal.vue';
import AccountSelector from 'dashboard/components/layout/sidebarComponents/AccountSelector.vue';
import AddLabelModal from 'dashboard/routes/dashboard/settings/labels/AddLabel.vue';
import NotificationPanel from 'dashboard/routes/dashboard/notifications/components/NotificationPanel.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import wootConstants from 'dashboard/constants/globals';
const CommandBar = () => import('./commands/commandbar.vue');

export default {
  components: {
    AssistantPanel,
    AssistantTopBar,
    DaliReturnButton,
    CaseConflictModal,
    Sidebar,
    CommandBar,
    WootKeyShortcutModal,
    AddAccountModal,
    AccountSelector,
    AddLabelModal,
    NotificationPanel,
  },
  setup() {
    const { uiSettings, updateUISettings } = useUISettings();

    return {
      uiSettings,
      updateUISettings,
    };
  },
  data() {
    return {
      showAccountModal: false,
      showCreateAccountModal: false,
      showAddLabelModal: false,
      showShortcutModal: false,
      isNotificationPanel: false,
      displayLayoutType: '',
    };
  },
  computed: {
    currentRoute() {
      return ' ';
    },
    layoutTypes() {
      return wootConstants.LAYOUT_TYPES;
    },
    isSidebarOpen() {
      const { show_secondary_sidebar: showSecondarySidebar } = this.uiSettings;
      return showSecondarySidebar;
    },
    previouslyUsedDisplayType() {
      const {
        previously_used_conversation_display_type: conversationDisplayType,
      } = this.uiSettings;
      return conversationDisplayType;
    },
    previouslyUsedSidebarView() {
      const { previously_used_sidebar_view: showSecondarySidebar } =
        this.uiSettings;
      return showSecondarySidebar;
    },
  },
  watch: {
    displayLayoutType() {
      const { LAYOUT_TYPES } = wootConstants;
      this.updateUISettings({
        conversation_display_type:
          this.displayLayoutType === LAYOUT_TYPES.EXPANDED
            ? LAYOUT_TYPES.EXPANDED
            : this.previouslyUsedDisplayType,
        show_secondary_sidebar:
          this.displayLayoutType === LAYOUT_TYPES.EXPANDED
            ? false
            : this.previouslyUsedSidebarView,
      });
    },
  },
  mounted() {
    this.handleResize();
    window.addEventListener('resize', this.handleResize);
    this.$emitter.on(BUS_EVENTS.TOGGLE_SIDEMENU, this.toggleSidebar);
    this.$emitter.on(BUS_EVENTS.OPEN_SIDEMENU, this.openSidebar);
  },
  beforeDestroy() {
    window.removeEventListener('resize', this.handleResize);
    this.$emitter.off(BUS_EVENTS.TOGGLE_SIDEMENU, this.toggleSidebar);
    this.$emitter.off(BUS_EVENTS.OPEN_SIDEMENU, this.openSidebar);
  },

  methods: {
    handleResize() {
      const { SMALL_SCREEN_BREAKPOINT, LAYOUT_TYPES } = wootConstants;
      let throttled = false;
      const delay = 150;

      if (throttled) {
        return;
      }
      throttled = true;

      setTimeout(() => {
        throttled = false;
        if (window.innerWidth <= SMALL_SCREEN_BREAKPOINT) {
          this.displayLayoutType = LAYOUT_TYPES.EXPANDED;
        } else {
          this.displayLayoutType = LAYOUT_TYPES.CONDENSED;
        }
      }, delay);
    },
    toggleSidebar() {
      this.updateUISettings({
        show_secondary_sidebar: !this.isSidebarOpen,
        previously_used_sidebar_view: !this.isSidebarOpen,
      });
    },
    // En pantalla chica el menú se oculta solo: ahí no se fuerza.
    openSidebar() {
      if (this.isSidebarOpen) return;
      if (this.displayLayoutType === wootConstants.LAYOUT_TYPES.EXPANDED)
        return;
      this.toggleSidebar();
    },
    openCreateAccountModal() {
      this.showAccountModal = false;
      this.showCreateAccountModal = true;
    },
    closeCreateAccountModal() {
      this.showCreateAccountModal = false;
    },
    toggleAccountModal() {
      this.showAccountModal = !this.showAccountModal;
    },
    toggleKeyShortcutModal() {
      this.showShortcutModal = true;
    },
    closeKeyShortcutModal() {
      this.showShortcutModal = false;
    },
    showAddLabelPopup() {
      this.showAddLabelModal = true;
    },
    hideAddLabelPopup() {
      this.showAddLabelModal = false;
    },
    openNotificationPanel() {
      this.isNotificationPanel = true;
    },
    closeNotificationPanel() {
      this.isNotificationPanel = false;
    },
  },
};
</script>

<template>
  <div
    class="flex flex-wrap flex-grow-0 w-full h-full max-w-full min-h-0 ml-auto mr-auto app-wrapper dark:text-slate-300"
  >
    <Sidebar
      :route="currentRoute"
      :show-secondary-sidebar="isSidebarOpen"
      @openNotificationPanel="openNotificationPanel"
      @toggleAccountModal="toggleAccountModal"
      @openKeyShortcutModal="toggleKeyShortcutModal"
      @closeKeyShortcutModal="closeKeyShortcutModal"
      @showAddLabelPopup="showAddLabelPopup"
    />
    <section
      class="relative flex flex-col flex-1 h-full min-w-0 min-h-0 px-0 overflow-hidden"
    >
      <!-- Un solo botón para ocultar y volver a mostrar el menú, en todas las pantallas (antes cada una ponía su ☰
           y en muchas faltaba: ocultabas el menú y ya no había cómo regresarlo). -->
      <button
        v-if="displayLayoutType !== layoutTypes.EXPANDED"
        v-tooltip.right="
          isSidebarOpen ? $t('SIDEBAR.HIDE_MENU') : $t('SIDEBAR.SHOW_MENU')
        "
        type="button"
        class="absolute left-0 z-20 flex items-center justify-center w-5 h-12 !p-0 -translate-y-1/2 bg-white border border-l-0 rounded-r-lg shadow top-1/2 border-slate-200 text-slate-600 hover:text-woot-600 hover:bg-woot-25 dark:bg-slate-800 dark:border-slate-700 dark:text-slate-300"
        :aria-label="
          isSidebarOpen ? $t('SIDEBAR.HIDE_MENU') : $t('SIDEBAR.SHOW_MENU')
        "
        @click="toggleSidebar"
      >
        <fluent-icon
          :icon="isSidebarOpen ? 'chevron-left' : 'chevron-right'"
          size="16"
          class="shrink-0"
        />
      </button>
      <!-- Dali siempre a la vista; la pantalla toma el alto que queda. -->
      <AssistantTopBar />
      <div class="flex flex-1 w-full min-h-0 overflow-hidden">
        <router-view />
      </div>
      <CommandBar />
      <AssistantPanel />
      <DaliReturnButton />
      <CaseConflictModal />
      <AccountSelector
        :show-account-modal="showAccountModal"
        @closeAccountModal="toggleAccountModal"
        @showCreateAccountModal="openCreateAccountModal"
      />
      <AddAccountModal
        :show="showCreateAccountModal"
        @closeAccountCreateModal="closeCreateAccountModal"
      />
      <WootKeyShortcutModal
        :show.sync="showShortcutModal"
        @close="closeKeyShortcutModal"
        @clickaway="closeKeyShortcutModal"
      />
      <NotificationPanel
        v-if="isNotificationPanel"
        @close="closeNotificationPanel"
      />
      <woot-modal :show.sync="showAddLabelModal" :on-close="hideAddLabelPopup">
        <AddLabelModal @close="hideAddLabelPopup" />
      </woot-modal>
    </section>
  </div>
</template>
