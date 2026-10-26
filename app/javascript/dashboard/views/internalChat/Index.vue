<script>
// feat/chat_interno (F3) — CHAT INTERNO, DENTRO DE CONVERSACIONES
// ============================================================================
// Mismo esquema que la pantalla de conversaciones: la lista de salas en medio (pestañas
// Mías / Todas) y la sala abierta a la derecha. También se eligen desde el menú de
// Conversaciones (grupo «Interno»). Sin sala en la dirección se abre la general; con
// ?new=1 se abre «Nuevo chat».
// Lo que llega en tiempo real lo mete el store (internalChat/messageCreated…).
// Plan: docs/chat_interno_plan.md §3
// ============================================================================
import { mapGetters } from 'vuex';
import PopOverSearch from 'dashboard/routes/dashboard/conversation/search/PopOverSearch.vue';
import EmptyStateMessage from 'dashboard/components/widgets/conversation/EmptyState/EmptyStateMessage.vue';
import RoomView from './RoomView.vue';
import NewRoomModal from './NewRoomModal.vue';
import InternalChatList from './InternalChatList.vue';

export default {
  components: {
    PopOverSearch,
    EmptyStateMessage,
    RoomView,
    NewRoomModal,
    InternalChatList,
  },
  data() {
    return { loadError: false, isOnExpandedLayout: false };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      getAccount: 'accounts/getAccount',
      roomById: 'internalChat/roomById',
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
    showNewRoom() {
      return this.$route.query.new === '1';
    },
  },
  watch: {
    // Como una bandeja: sin sala elegida se ve el estado vacío («No Chat»).
    roomId: {
      immediate: true,
      handler(id) {
        this.$store.dispatch('internalChat/openRoom', id || null);
      },
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
    goToRoom(room, query = {}) {
      this.$router.push({
        name: 'internal_chat',
        params: { accountId: this.accountId, roomId: room.id },
        query,
      });
    },
    closeNewRoom() {
      this.$router.replace({ query: {} });
    },
    openNewRoom() {
      this.$router.replace({ query: { new: '1' } });
    },
    onSelect(room) {
      this.isOnExpandedLayout = false;
      if (room.id !== this.roomId) this.goToRoom(room);
    },
    onCreated(room) {
      this.goToRoom(room);
    },
  },
};
</script>

<template>
  <section class="bg-white conversation-page dark:bg-slate-900">
    <p
      v-if="!enabled"
      class="m-auto text-sm text-slate-500 dark:text-slate-400"
    >
      {{ $t('INTERNAL_CHAT.DISABLED') }}
    </p>
    <p
      v-else-if="loadError"
      class="m-auto text-sm text-red-600 dark:text-red-400"
    >
      {{ $t('INTERNAL_CHAT.LOAD_ERROR') }}
    </p>
    <template v-else>
      <InternalChatList
        :active-room-id="roomId"
        :is-on-expanded-layout="isOnExpandedLayout"
        @select="onSelect"
        @new="openNewRoom"
      >
        <PopOverSearch
          :is-on-expanded-layout="isOnExpandedLayout"
          @toggleConversationLayout="isOnExpandedLayout = !isOnExpandedLayout"
        />
      </InternalChatList>
      <template v-if="!isOnExpandedLayout">
        <RoomView v-if="activeRoom" :key="activeRoom.id" :room="activeRoom" />
        <div
          v-else
          class="flex flex-col items-center justify-center flex-1 h-full min-w-0 px-0"
        >
          <EmptyStateMessage :message="$t('INTERNAL_CHAT.PICK_ROOM')" />
        </div>
      </template>
      <!-- Sin scroll en el modal: la lista del selector flota por encima (size = clase del contenedor) -->
      <woot-modal
        :show="showNewRoom"
        :on-close="closeNewRoom"
        size="!overflow-visible"
      >
        <NewRoomModal
          v-if="showNewRoom"
          @close="closeNewRoom"
          @created="onCreated"
        />
      </woot-modal>
    </template>
  </section>
</template>
