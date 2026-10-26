<script>
// feat/chat_interno — LA LISTA DE SALAS, con el mismo marco que la lista de conversaciones
// (components/ChatList.vue + ChatListHeader.vue + ChatTypeTabs.vue):
//   Mías   tus directos
//   Todas  # general, # tus equipos y tus directos
// «No asignadas» no aplica al chat interno.
import { mapGetters } from 'vuex';
import ChatTypeTabs from 'dashboard/components/widgets/ChatTypeTabs.vue';
import InternalChatCard from './InternalChatCard.vue';

const TABS = { MINE: 'me', ALL: 'all' };

export default {
  components: { ChatTypeTabs, InternalChatCard },
  props: {
    activeRoomId: { type: Number, default: null },
  },
  emits: ['select', 'new'],
  data() {
    return { activeTab: TABS.ALL };
  },
  computed: {
    ...mapGetters({
      rooms: 'internalChat/rooms',
      directRooms: 'internalChat/directRooms',
      currentUserId: 'getCurrentUserID',
      uiFlags: 'internalChat/uiFlags',
    }),
    tabs() {
      return [
        {
          key: TABS.MINE,
          name: this.$t('CHAT_LIST.ASSIGNEE_TYPE_TABS.me'),
          count: this.directRooms.length,
        },
        {
          key: TABS.ALL,
          name: this.$t('CHAT_LIST.ASSIGNEE_TYPE_TABS.all'),
          count: this.rooms.length,
        },
      ];
    },
    visibleRooms() {
      return this.activeTab === TABS.MINE ? this.directRooms : this.rooms;
    },
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-shrink-0 overflow-hidden border-r conversations-list-wrap rtl:border-r-0 rtl:border-l border-slate-50 dark:border-slate-800/50 flex-basis-clamp"
  >
    <div class="flex items-center justify-between px-4 py-0">
      <div class="flex max-w-[85%] justify-center items-center">
        <h1
          class="text-xl font-medium break-words truncate text-black-900 dark:text-slate-100"
        >
          {{ $t('INTERNAL_CHAT.TITLE') }}
        </h1>
      </div>
      <woot-button
        v-tooltip.right="$t('SIDEBAR.INTERNAL_CHAT_NEW')"
        variant="smooth"
        color-scheme="secondary"
        icon="add"
        size="tiny"
        @click="$emit('new')"
      />
    </div>

    <ChatTypeTabs
      :items="tabs"
      :active-tab="activeTab"
      @chatTabChange="activeTab = $event"
    />

    <p
      v-if="!uiFlags.loadingRooms && !visibleRooms.length"
      class="flex items-center justify-center p-4 overflow-auto"
    >
      {{ $t('INTERNAL_CHAT.EMPTY_LIST') }}
    </p>
    <div class="flex-1 overflow-auto conversations-list">
      <InternalChatCard
        v-for="room in visibleRooms"
        :key="room.id"
        :room="room"
        :current-user-id="currentUserId"
        :is-active="room.id === activeRoomId"
        @select="$emit('select', $event)"
      />
    </div>
  </div>
</template>
