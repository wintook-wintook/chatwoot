<!--
  feat/chat_interno_pulido — PANEL DERECHO DE UNA SALA DE «CHAT INTERNO»
  En lugar del contacto (que en «Interno» es uno oculto): quién está en la sala,
  con su foto y si está en línea; los conectados primero.
-->
<script>
import { mapGetters } from 'vuex';
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';

const STATUS_ORDER = { online: 0, busy: 1, offline: 2 };
const rank = status => (status in STATUS_ORDER ? STATUS_ORDER[status] : 2);

export default {
  name: 'InternalMembersPanel',
  components: { Thumbnail },
  props: {
    conversationId: { type: [Number, String], required: true },
    onToggle: { type: Function, default: () => {} },
  },
  computed: {
    ...mapGetters({
      currentUserId: 'getCurrentUserID',
      agents: 'agents/getAgents',
    }),
    watchers() {
      return (
        this.$store.getters['conversationWatchers/getByConversationId'](
          this.conversationId
        ) || []
      );
    },
    members() {
      return this.watchers
        .map(watcher => {
          const agent = this.agents.find(item => item.id === watcher.id) || {};
          return {
            id: watcher.id,
            name: agent.available_name || agent.name || watcher.name,
            thumbnail: agent.thumbnail || watcher.thumbnail || '',
            status: agent.availability_status || 'offline',
            me: watcher.id === this.currentUserId,
          };
        })
        .sort(
          (a, b) =>
            rank(a.status) - rank(b.status) || a.name.localeCompare(b.name)
        );
    },
  },
  watch: {
    conversationId: {
      immediate: true,
      handler(id) {
        if (id)
          this.$store.dispatch('conversationWatchers/show', {
            conversationId: id,
          });
      },
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-full bg-white dark:bg-slate-900">
    <div
      class="flex items-center justify-between px-4 py-3 border-b border-slate-50 dark:border-slate-800"
    >
      <h3 class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100">
        {{ $t('INTERNAL_CHAT.MEMBERS.TITLE', { count: members.length }) }}
      </h3>
      <woot-button
        variant="clear"
        size="small"
        color-scheme="secondary"
        icon="dismiss"
        :title="$t('INTERNAL_CHAT.MEMBERS.CLOSE')"
        @click="onToggle"
      />
    </div>
    <ul class="flex-1 p-0 m-0 overflow-y-auto list-none">
      <li
        v-for="member in members"
        :key="member.id"
        class="flex items-center gap-3 px-4 py-2"
      >
        <Thumbnail
          :src="member.thumbnail"
          :username="member.name"
          :status="member.status"
          size="32px"
        />
        <span class="flex flex-col min-w-0">
          <span
            class="text-sm font-medium truncate text-slate-800 dark:text-slate-100"
          >
            {{ member.name }}
            <span v-if="member.me" class="font-normal text-slate-500">
              {{ $t('INTERNAL_CHAT.MEMBERS.YOU') }}
            </span>
          </span>
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ $t(`INTERNAL_CHAT.STATUS.${member.status}`) }}
          </span>
        </span>
      </li>
    </ul>
  </div>
</template>
