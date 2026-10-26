<script>
// feat/chat_interno (F3) — CHAT INTERNO, DENTRO DE CONVERSACIONES
// ============================================================================
// Las salas se eligen en el menú de Conversaciones (grupo «Interno»: # general, # cada
// equipo y los directos). Aquí solo se ve la sala abierta. Sin sala en la dirección se
// abre la general; con ?new=1 se abre «Nuevo chat».
// Lo que llega en tiempo real lo mete el store (internalChat/messageCreated…).
// Plan: docs/chat_interno_plan.md §3
// ============================================================================
import { mapGetters } from 'vuex';
import RoomView from './RoomView.vue';
import NewRoomModal from './NewRoomModal.vue';

export default {
  components: { RoomView, NewRoomModal },
  data() {
    return { loadError: false };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      getAccount: 'accounts/getAccount',
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
    showNewRoom() {
      return this.$route.query.new === '1';
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
    goToRoom(room, query = {}) {
      this.$router.push({
        name: 'internal_chat',
        params: { accountId: this.accountId, roomId: room.id },
        query,
      });
    },
    // Sin sala elegida: la general (conservando ?new=1 si se pidió «Nuevo chat»).
    openDefaultRoom() {
      const general = this.rooms.find(room => room.kind === 'general');
      if (general) this.goToRoom(general, this.showNewRoom ? { new: '1' } : {});
    },
    closeNewRoom() {
      this.$router.replace({ query: {} });
    },
    onCreated(room) {
      this.goToRoom(room);
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
    <p
      v-else-if="loadError"
      class="m-auto text-sm text-red-600 dark:text-red-400"
    >
      {{ $t('INTERNAL_CHAT.LOAD_ERROR') }}
    </p>
    <template v-else>
      <RoomView v-if="activeRoom" :key="activeRoom.id" :room="activeRoom" />
      <p
        v-else-if="!uiFlags.loadingRooms"
        class="m-auto text-sm text-slate-500 dark:text-slate-400"
      >
        {{ $t('INTERNAL_CHAT.PICK_ROOM') }}
      </p>
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
  </div>
</template>
