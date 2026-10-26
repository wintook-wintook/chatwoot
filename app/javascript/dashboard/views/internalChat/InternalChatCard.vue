<script>
// feat/chat_interno — UNA SALA EN LA LISTA, con el mismo marcado que ConversationCard
// (components/widgets/conversation/ConversationCard.vue): foto de 40px, nombre, último
// mensaje, hace cuánto y el globo de no leídos.
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import TimeAgo from 'dashboard/components/ui/TimeAgo.vue';
import { memberName, otherMember, roomTitle } from './roomHelpers';

export default {
  components: { Thumbnail, TimeAgo },
  props: {
    room: { type: Object, required: true },
    currentUserId: { type: Number, required: true },
    isActive: { type: Boolean, default: false },
  },
  emits: ['select'],
  computed: {
    title() {
      return roomTitle(
        this.room,
        this.currentUserId,
        this.$t('INTERNAL_CHAT.GENERAL')
      );
    },
    other() {
      return this.room.kind === 'direct'
        ? otherMember(this.room, this.currentUserId) || {}
        : {};
    },
    avatarName() {
      return this.room.kind === 'direct' ? this.title : this.room.name || '#';
    },
    lastMessage() {
      return this.room.last_message;
    },
    preview() {
      const message = this.lastMessage;
      if (!message) return '';
      const mine = message.sender && message.sender.id === this.currentUserId;
      const who = mine
        ? this.$t('INTERNAL_CHAT.YOU')
        : memberName(message.sender);
      const text = message.deleted
        ? this.$t('INTERNAL_CHAT.DELETED')
        : message.content;
      return this.room.kind === 'direct' && !mine ? text : `${who}: ${text}`;
    },
    unreadCount() {
      return this.room.unread_count || 0;
    },
    timestamp() {
      return this.room.last_message_at || 0;
    },
  },
};
</script>

<template>
  <div
    class="relative flex items-start flex-grow-0 flex-shrink-0 w-auto max-w-full px-4 py-0 border-t-0 border-b-0 border-l-2 border-r-0 border-transparent border-solid cursor-pointer conversation hover:bg-slate-25 dark:hover:bg-slate-800 group"
    :class="{
      'active animate-card-select bg-slate-25 dark:bg-slate-800 border-woot-500':
        isActive,
    }"
    @click="$emit('select', room)"
  >
    <Thumbnail
      :src="other.avatar_url"
      :username="avatarName"
      :status="other.availability_status"
      class="mt-3"
      size="40px"
    />
    <div
      class="px-0 py-3 border-b group-hover:border-transparent flex-1 border-slate-50 dark:border-slate-800/75 w-[calc(100%-40px)]"
    >
      <h4
        class="text-sm my-0 mx-2 pt-0.5 text-ellipsis overflow-hidden whitespace-nowrap w-[calc(100%-70px)] text-slate-900 dark:text-slate-100"
        :class="unreadCount ? 'font-semibold' : 'font-medium'"
      >
        {{ title }}
      </h4>
      <p
        class="text-slate-700 dark:text-slate-200 text-sm my-0 mx-2 leading-6 h-6 max-w-[96%] w-[16.875rem] overflow-hidden text-ellipsis whitespace-nowrap"
      >
        <template v-if="lastMessage">{{ preview }}</template>
        <template v-else>
          <fluent-icon
            size="16"
            class="-mt-0.5 align-middle inline-block text-slate-600 dark:text-slate-300"
            icon="info"
          />
          {{ $t('CHAT_LIST.NO_MESSAGES') }}
        </template>
      </p>
      <div class="absolute flex flex-col right-4 top-4">
        <span
          v-if="timestamp"
          class="ml-auto font-normal leading-4 text-black-600 text-xxs"
        >
          <TimeAgo
            :last-activity-timestamp="timestamp"
            :created-at-timestamp="timestamp"
          />
        </span>
        <span
          v-if="unreadCount"
          class="shadow-lg rounded-full text-xxs font-semibold h-4 leading-4 ml-auto mt-1 min-w-[1rem] px-1 py-0 text-center text-white bg-green-400"
        >
          {{ unreadCount > 9 ? '9+' : unreadCount }}
        </span>
      </div>
    </div>
  </div>
</template>
