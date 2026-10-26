<script>
// feat/chat_interno (F3) — CHAT INTERNO ENTRE AGENTES
// ============================================================================
// Izquierda: las salas del agente (Grupos con la general primero; Directos) con sus no
// leídos. Derecha: la sala abierta. Sin sala en la dirección se abre la general.
// Lo que llega en tiempo real lo mete el store (internalChat/messageCreated…).
// Plan: docs/chat_interno_plan.md §3
// ============================================================================
import { mapGetters } from 'vuex';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import RoomView from './RoomView.vue';
import NewRoomModal from './NewRoomModal.vue';
import { otherMember, roomTitle } from './roomHelpers';

export default {
  components: { Thumbnail, RoomView, NewRoomModal },
  data() {
    return { showNewRoom: false, loadError: false };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      currentUserId: 'getCurrentUserID',
      getAccount: 'accounts/getAccount',
      groupRooms: 'internalChat/groupRooms',
      directRooms: 'internalChat/directRooms',
      rooms: 'internalChat/rooms',
      roomById: 'internalChat/roomById',
      uiFlags: 'internalChat/uiFlags',
    }),
    enabled() {
      const account = this.getAccount(this.accountId);
      return Boolean(account && account.internal_chat_enabled);
    },
    roomId() {
      return Number(this.$route.params.roomId) || null;
    },
    activeRoom() {
      return this.roomId ? this.roomById(this.roomId) : null;
    },
  },
  watch: {
    roomId: {
      immediate: true,
      handler(id) {
        if (id) this.$store.dispatch('internalChat/openRoom', id);
        else this.openDefaultRoom();
      },
    },
    rooms() {
      if (!this.roomId) this.openDefaultRoom();
    },
  },
  mounted() {
    this.$store.dispatch('agents/get').catch(() => {});
    this.$store.dispatch('internalChat/fetchRooms').catch(() => {
      this.loadError = true;
    });
  },
  beforeDestroy() {
    this.$store.commit('internalChat/SET_ACTIVE_ROOM', null);
  },
  methods: {
    title(room) {
      return roomTitle(
        room,
        this.currentUserId,
        this.$t('INTERNAL_CHAT.GENERAL')
      );
    },
    other(room) {
      return otherMember(room, this.currentUserId) || {};
    },
    openRoom(room) {
      if (room.id === this.roomId) return;
      this.$router.push({
        name: 'internal_chat',
        params: { accountId: this.accountId, roomId: room.id },
      });
    },
    openDefaultRoom() {
      const general = this.rooms.find(room => room.kind === 'general');
      if (general) this.openRoom(general);
    },
    onCreated(room) {
      this.showNewRoom = false;
      this.openRoom(room);
    },
    isActive(room) {
      return room.id === this.roomId;
    },
  },
};
</script>

<template>
  <div class="flex w-full h-full min-h-0 bg-white dark:bg-slate-900">
    <p
      v-if="!enabled"
      class="m-auto text-sm text-slate-500 dark:text-slate-400"
    >
      {{ $t('INTERNAL_CHAT.DISABLED') }}
    </p>
    <template v-else>
      <aside
        class="flex flex-col h-full min-h-0 border-r w-72 shrink-0 border-slate-50 dark:border-slate-800/50"
      >
        <div class="flex items-center justify-between h-14 px-4 shrink-0">
          <h2
            class="m-0 text-base font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ $t('INTERNAL_CHAT.TITLE') }}
          </h2>
          <woot-button
            size="small"
            variant="smooth"
            color-scheme="primary"
            icon="add"
            @click="showNewRoom = true"
          >
            {{ $t('INTERNAL_CHAT.NEW') }}
          </woot-button>
        </div>
        <p v-if="loadError" class="px-4 text-sm text-red-600 dark:text-red-400">
          {{ $t('INTERNAL_CHAT.LOAD_ERROR') }}
        </p>
        <div class="flex-1 min-h-0 px-2 pb-4 overflow-auto">
          <h3
            class="px-2 mt-2 mb-1 text-xs font-semibold uppercase text-slate-500 dark:text-slate-400"
          >
            {{ $t('INTERNAL_CHAT.GROUPS') }}
          </h3>
          <button
            v-for="room in groupRooms"
            :key="room.id"
            type="button"
            class="flex items-center w-full gap-2 px-2 py-1.5 text-sm text-left border-0 rounded-lg cursor-pointer"
            :class="
              isActive(room)
                ? 'bg-woot-25 dark:bg-slate-800 text-woot-600 dark:text-woot-400'
                : 'bg-transparent text-slate-700 dark:text-slate-200 hover:bg-slate-25 dark:hover:bg-slate-800'
            "
            @click="openRoom(room)"
          >
            <span
              class="flex-1 truncate"
              :class="{ 'font-semibold': room.unread_count }"
            >
              {{ title(room) }}
            </span>
            <span
              v-if="room.unread_count"
              class="px-1.5 text-xxs font-semibold text-white rounded-full bg-woot-500"
            >
              {{ room.unread_count }}
            </span>
          </button>

          <h3
            class="px-2 mt-4 mb-1 text-xs font-semibold uppercase text-slate-500 dark:text-slate-400"
          >
            {{ $t('INTERNAL_CHAT.DIRECTS') }}
          </h3>
          <p
            v-if="!directRooms.length"
            class="px-2 text-xs text-slate-400 dark:text-slate-500"
          >
            {{ $t('INTERNAL_CHAT.EMPTY_DIRECTS') }}
          </p>
          <button
            v-for="room in directRooms"
            :key="room.id"
            type="button"
            class="flex items-center w-full gap-2 px-2 py-1.5 text-sm text-left border-0 rounded-lg cursor-pointer"
            :class="
              isActive(room)
                ? 'bg-woot-25 dark:bg-slate-800 text-woot-600 dark:text-woot-400'
                : 'bg-transparent text-slate-700 dark:text-slate-200 hover:bg-slate-25 dark:hover:bg-slate-800'
            "
            @click="openRoom(room)"
          >
            <Thumbnail
              :src="other(room).avatar_url"
              :username="title(room)"
              :status="other(room).availability_status"
              should-show-status-always
              size="24px"
            />
            <span
              class="flex-1 truncate"
              :class="{ 'font-semibold': room.unread_count }"
            >
              {{ title(room) }}
            </span>
            <span
              v-if="room.unread_count"
              class="px-1.5 text-xxs font-semibold text-white rounded-full bg-woot-500"
            >
              {{ room.unread_count }}
            </span>
          </button>
        </div>
      </aside>

      <RoomView v-if="activeRoom" :key="activeRoom.id" :room="activeRoom" />
      <p
        v-else-if="!uiFlags.loadingRooms"
        class="m-auto text-sm text-slate-500 dark:text-slate-400"
      >
        {{ $t('INTERNAL_CHAT.PICK_ROOM') }}
      </p>

      <NewRoomModal
        v-if="showNewRoom"
        @close="showNewRoom = false"
        @created="onCreated"
      />
    </template>
  </div>
</template>
