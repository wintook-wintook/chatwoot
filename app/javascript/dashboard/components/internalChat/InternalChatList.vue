<!--
  feat/chat_interno_pulido — LA LISTA DE «CHAT INTERNO»
  En lugar de las tarjetas de clientes: dos secciones, Grupos (# general y los
  equipos) y Directos (el otro agente con su punto de en línea), cada una por su
  último mensaje. La sala con mensajes sin leer va en negritas con su contador y
  la vista previa dice quién escribió («Ana: …», «Tú: …»).
-->
<script>
import { mapGetters } from 'vuex';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import { getLastMessage } from 'dashboard/helper/conversationHelper';
import { internalDisplay, internalInfo } from 'dashboard/helper/internalChat';
import { dynamicTime, shortTimestamp } from 'shared/helpers/timeHelper';

const ACTIVITY = 2;

export default {
  name: 'InternalChatList',
  components: { Thumbnail },
  props: {
    chats: { type: Array, default: () => [] },
  },
  emits: ['open'],
  computed: {
    ...mapGetters({
      currentUserId: 'getCurrentUserID',
      agents: 'agents/getAgents',
      teams: 'teams/getTeams',
      selectedChat: 'getSelectedChat',
    }),
    rooms() {
      return this.chats
        .map(chat => this.toRoom(chat))
        .sort((a, b) => b.lastAt - a.lastAt);
    },
    groups() {
      return this.rooms.filter(room => room.kind !== 'direct');
    },
    directs() {
      return this.rooms.filter(room => room.kind === 'direct');
    },
    sections() {
      return [
        { key: 'GROUPS', rooms: this.groups },
        { key: 'DIRECTS', rooms: this.directs },
      ].filter(section => section.rooms.length);
    },
  },
  methods: {
    toRoom(chat) {
      const info = internalInfo(chat) || {};
      const display =
        internalDisplay(chat, {
          currentUserId: this.currentUserId,
          agents: this.agents,
          teams: this.teams,
          generalLabel: this.$t('INTERNAL_CHAT.GENERAL'),
        }) || {};
      const last = getLastMessage(chat);
      const hasText = last && last.message_type !== ACTIVITY;
      return {
        id: chat.id,
        chat,
        kind: info.kind,
        name: display.name || '',
        thumbnail: display.thumbnail || '',
        status: display.availability_status || '',
        unread: chat.unread_count || 0,
        lastAt: chat.timestamp || chat.last_activity_at || 0,
        preview: hasText ? this.preview(last) : '',
      };
    },
    preview(message) {
      // Las @menciones vienen como enlace markdown: en la vista previa solo «@Nombre».
      const content = (message.content || '').replace(
        /\[(@[^\]]+)\]\(mention:\/\/[^)]+\)/g,
        '$1'
      );
      const text =
        content ||
        (message.attachments && message.attachments.length
          ? this.$t('INTERNAL_CHAT.LIST.ATTACHMENT')
          : '');
      const sender = message.sender || {};
      const who =
        sender.id === this.currentUserId
          ? this.$t('INTERNAL_CHAT.LIST.YOU')
          : (sender.available_name || sender.name || '').split(' ')[0];
      return who ? `${who}: ${text}` : text;
    },
    time(room) {
      return room.lastAt ? shortTimestamp(dynamicTime(room.lastAt)) : '';
    },
    isActive(room) {
      return this.selectedChat && this.selectedChat.id === room.id;
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3 py-2">
    <section v-for="section in sections" :key="section.key">
      <h3
        class="px-4 mb-1 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
      >
        {{ $t(`INTERNAL_CHAT.LIST.${section.key}`) }}
      </h3>
      <ul class="p-0 m-0 list-none">
        <li v-for="room in section.rooms" :key="room.id">
          <button
            type="button"
            class="flex items-center w-full gap-3 px-4 py-2 text-left border-0 rounded-none hover:bg-slate-25 dark:hover:bg-slate-800"
            :class="isActive(room) ? 'bg-woot-25 dark:bg-slate-800' : ''"
            @click="$emit('open', room.chat, $event)"
          >
            <span
              v-if="room.kind !== 'direct'"
              class="flex items-center justify-center flex-shrink-0 w-9 h-9 text-base font-semibold rounded-full bg-woot-50 text-woot-600 dark:bg-woot-800 dark:text-woot-100"
            >
              #
            </span>
            <Thumbnail
              v-else
              :src="room.thumbnail"
              :username="room.name"
              :status="room.status"
              size="36px"
              class="flex-shrink-0"
            />
            <span class="flex flex-col flex-1 min-w-0">
              <span class="flex items-baseline justify-between gap-2">
                <span
                  class="text-sm truncate text-slate-800 dark:text-slate-100"
                  :class="room.unread ? 'font-semibold' : 'font-medium'"
                >
                  {{ room.name }}
                </span>
                <span
                  class="flex-shrink-0 text-xxs text-slate-400 dark:text-slate-500"
                >
                  {{ time(room) }}
                </span>
              </span>
              <span class="flex items-center justify-between gap-2">
                <span
                  class="text-xs truncate"
                  :class="
                    room.unread
                      ? 'text-slate-700 dark:text-slate-200'
                      : 'text-slate-500 dark:text-slate-400'
                  "
                >
                  {{ room.preview || $t('INTERNAL_CHAT.LIST.NO_MESSAGES') }}
                </span>
                <span
                  v-if="room.unread"
                  class="flex-shrink-0 min-w-[1.25rem] px-1.5 text-xxs font-semibold leading-5 text-center text-white rounded-full bg-woot-500"
                >
                  {{ room.unread > 99 ? '99+' : room.unread }}
                </span>
              </span>
            </span>
          </button>
        </li>
      </ul>
    </section>
  </div>
</template>
