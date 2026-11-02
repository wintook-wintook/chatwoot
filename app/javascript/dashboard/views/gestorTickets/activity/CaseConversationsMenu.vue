<!--
  Plan Actividad del caso — «💬 Conversaciones N ▾» en la barra de pestañas del
  caso. Lista las conversaciones ligadas (la principal marcada; las adicionales,
  p. ej. el correo, se pueden quitar), «Agregar conversación» y el aviso de las
  del contacto que no están ligadas (punto ámbar en el botón).
  Datos: GET/DELETE …/case_tickets/:id/conversations.
-->
<script>
import { useAlert } from 'dashboard/composables';
import CaseTicketsAPI from 'dashboard/api/caseTickets';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import LinkConversationModal from '../conversation/LinkConversationModal.vue';

const T = 'CASE_TICKETS.ACTIVITY';

export default {
  name: 'CaseConversationsMenu',
  components: { LinkConversationModal },
  props: {
    ticket: { type: Object, required: true },
    // Cambia cuando el detalle recarga el caso: se vuelve a pedir la lista.
    refreshKey: { type: String, default: '' },
  },
  emits: ['openTab', 'linked'],
  data() {
    return { linked: [], unlinked: [], open: false, showLink: false };
  },
  watch: {
    'ticket.id': 'load',
    refreshKey: 'load',
  },
  mounted() {
    this.load();
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    async load() {
      try {
        const { data } = await CaseTicketsAPI.getConversations(this.ticket.id);
        this.linked = data.conversations;
        this.unlinked = data.unlinked;
      } catch (_e) {
        this.linked = [];
        this.unlinked = [];
      }
    },
    isEmail(conversation) {
      return (conversation?.channel_type || '').includes('Email');
    },
    name(conversation) {
      const base = `#${conversation.display_id} · ${
        conversation.inbox_name || '—'
      }`;
      return conversation.subject ? `${base} · ${conversation.subject}` : base;
    },
    // La principal se ve dentro del caso; las adicionales, en Conversaciones.
    openConversation(conversation) {
      this.open = false;
      if (conversation.primary) {
        this.$emit('openTab', 'detail');
        return;
      }
      const accountId = this.$route.params.accountId;
      this.$router.push(
        frontendURL(conversationUrl({ accountId, id: conversation.display_id }))
      );
    },
    openLink() {
      this.open = false;
      this.showLink = true;
    },
    onLinked() {
      this.showLink = false;
      this.$emit('linked');
      this.load();
    },
    async unlink(conversation) {
      // eslint-disable-next-line no-alert
      if (
        !window.confirm(
          this.t('UNLINK_CONFIRM', { id: conversation.display_id })
        )
      ) {
        return;
      }
      try {
        await CaseTicketsAPI.unlinkConversation(
          this.ticket.id,
          conversation.display_id
        );
        this.$emit('linked');
        this.load();
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('ERROR'));
      }
    },
  },
};
</script>

<template>
  <div v-on-clickaway="() => (open = false)" class="relative">
    <woot-button
      size="small"
      variant="smooth"
      color-scheme="secondary"
      icon="chat"
      @click="open = !open"
    >
      {{ t('CONVERSATIONS') }}
      <span class="text-slate-400">{{ linked.length }}</span>
      <span
        v-if="unlinked.length"
        class="inline-block w-2 h-2 ml-1 rounded-full bg-amber-500"
      />
      <fluent-icon icon="chevron-down" size="12" class="ml-1" />
    </woot-button>
    <div
      v-if="open"
      class="absolute right-0 z-50 flex flex-col gap-1 p-2 mt-1 bg-white border rounded-md shadow-md top-full dark:bg-slate-800 border-slate-100 dark:border-slate-700 w-80"
    >
      <p v-if="!linked.length" class="px-2 py-1 m-0 text-sm text-slate-500">
        {{ t('NO_CONVERSATION') }}
      </p>
      <div
        v-for="c in linked"
        :key="c.display_id"
        class="flex items-center gap-2 px-2 py-1.5 text-sm rounded hover:bg-slate-50 dark:hover:bg-slate-700"
      >
        <fluent-icon
          :icon="isEmail(c) ? 'mail' : 'chat'"
          size="14"
          class="shrink-0 text-slate-400"
        />
        <button
          class="flex-1 min-w-0 p-0 text-left truncate bg-transparent border-0 cursor-pointer text-slate-700 dark:text-slate-200 hover:underline"
          @click="openConversation(c)"
        >
          {{ name(c) }}
        </button>
        <span v-if="c.primary" class="text-xs text-slate-400 shrink-0">
          {{ t('PRIMARY') }}
        </span>
        <button
          v-else
          v-tooltip="t('UNLINK')"
          class="p-0 bg-transparent border-0 cursor-pointer text-slate-400 hover:text-red-600 shrink-0"
          @click="unlink(c)"
        >
          <fluent-icon icon="dismiss" size="12" />
        </button>
      </div>
      <p
        v-if="unlinked.length"
        class="px-2 py-1 m-0 text-xs text-amber-700 dark:text-amber-300"
      >
        {{ t('UNLINKED', { n: unlinked.length }) }}
      </p>
      <woot-button
        size="small"
        variant="clear"
        icon="add"
        class="self-start"
        @click="openLink"
      >
        {{
          $t(
            `CASE_TICKETS.CONVERSATION_ACTIONS.${
              linked.length ? 'ADD' : 'LINK'
            }`
          )
        }}
      </woot-button>
    </div>

    <LinkConversationModal
      v-if="showLink"
      :show="showLink"
      :ticket="ticket"
      @close="showLink = false"
      @linked="onLinked"
    />
  </div>
</template>
