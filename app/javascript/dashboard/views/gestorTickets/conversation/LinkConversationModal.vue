<!--
  @tickets_cases — ligar la conversación de un caso que no tiene.
  Dos caminos: una conversación que ya existe del contacto, o una bandeja (usa la
  abierta del contacto ahí o crea una nueva). El caso no cambia de conversación:
  esto solo se ofrece cuando no tiene.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import ContactAPI from 'dashboard/api/contacts';
import CaseTicketsAPI from 'dashboard/api/caseTickets';

const T = 'CASE_TICKETS.CONVERSATION_ACTIONS.LINK_MODAL';

export default {
  name: 'LinkConversationModal',
  props: {
    show: { type: Boolean, default: false },
    ticket: { type: Object, required: true },
  },
  emits: ['close', 'linked'],
  data() {
    return {
      conversations: [],
      isLoading: false,
      inboxId: '',
      savingKey: null, // display_id de la que se liga, o 'inbox'
    };
  },
  computed: {
    ...mapGetters({ inboxes: 'inboxes/getInboxes' }),
    contactId() {
      return this.ticket.contact_id;
    },
  },
  watch: {
    show: {
      immediate: true,
      handler(open) {
        if (open) this.load();
      },
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    async load() {
      this.inboxId = '';
      if (!this.inboxes.length) this.$store.dispatch('inboxes/get');
      if (!this.contactId) return;
      this.isLoading = true;
      try {
        const { data } = await ContactAPI.getConversations(this.contactId);
        this.conversations = data.payload || [];
      } catch (_e) {
        this.conversations = [];
      } finally {
        this.isLoading = false;
      }
    },
    inboxName(id) {
      const inbox = this.inboxes.find(i => i.id === id);
      return inbox ? inbox.name : `#${id}`;
    },
    statusLabel(status) {
      return this.$te(`${T}.STATUS.${status}`)
        ? this.t(`STATUS.${status}`)
        : status;
    },
    lastMessage(c) {
      const msgs = c.messages || [];
      const last = msgs[msgs.length - 1];
      return (last && last.content) || '';
    },
    lastDate(c) {
      const ts = c.last_activity_at || c.timestamp;
      return ts ? new Date(ts * 1000).toLocaleDateString() : '';
    },
    async link(params, key) {
      this.savingKey = key;
      try {
        const { data } = await CaseTicketsAPI.linkConversation(
          this.ticket.id,
          params
        );
        useAlert(
          data.created
            ? this.t('CREATED', { id: data.conversation_display_id })
            : this.t('LINKED', { id: data.conversation_display_id })
        );
        this.$emit('linked', data);
      } catch (e) {
        useAlert(
          (e.response && e.response.data && e.response.data.error) ||
            this.t('ERROR')
        );
      } finally {
        this.savingKey = null;
      }
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="() => $emit('close')" size="medium">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="t('TITLE', { folio: ticket.folio })"
        :header-content="t('SUBTITLE')"
      />
      <div class="flex flex-col gap-6 px-8 pb-8">
        <!-- 1. Una conversación que ya existe del contacto -->
        <section class="flex flex-col gap-2">
          <h3
            class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ t('EXISTING') }}
          </h3>
          <p v-if="isLoading" class="m-0 text-sm text-slate-500">
            {{ t('LOADING') }}
          </p>
          <p
            v-else-if="!conversations.length"
            class="m-0 text-sm text-slate-500 dark:text-slate-400"
          >
            {{ t('EMPTY') }}
          </p>
          <ul v-else class="flex flex-col gap-2 p-0 m-0 list-none">
            <li
              v-for="c in conversations"
              :key="c.id"
              class="flex items-center gap-3 p-3 border rounded-lg border-slate-200 dark:border-slate-700"
            >
              <div class="flex flex-col flex-1 min-w-0 gap-0.5">
                <span
                  class="text-sm font-medium text-slate-800 dark:text-slate-100"
                >
                  {{
                    t('ROW', {
                      id: c.id,
                      inbox: inboxName(c.inbox_id),
                      status: statusLabel(c.status),
                      date: lastDate(c),
                    })
                  }}
                </span>
                <span
                  v-if="lastMessage(c)"
                  class="text-xs truncate text-slate-500 dark:text-slate-400"
                >
                  {{ lastMessage(c) }}
                </span>
              </div>
              <woot-button
                size="small"
                :is-loading="savingKey === c.id"
                :disabled="!!savingKey"
                @click="link({ conversation_id: c.id }, c.id)"
              >
                {{ t('LINK_BUTTON') }}
              </woot-button>
            </li>
          </ul>
        </section>

        <!-- 2. Una bandeja: la abierta del contacto ahí, o una nueva -->
        <section
          class="flex flex-col gap-2 pt-4 border-t border-slate-100 dark:border-slate-800"
        >
          <h3
            class="m-0 text-sm font-semibold text-slate-800 dark:text-slate-100"
          >
            {{ t('CREATE_TITLE') }}
          </h3>
          <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
            {{ t('CREATE_HINT') }}
          </p>
          <div class="flex items-center gap-2">
            <select v-model="inboxId" class="flex-1 !mb-0">
              <option value="">{{ t('INBOX_PLACEHOLDER') }}</option>
              <option v-for="i in inboxes" :key="i.id" :value="i.id">
                {{ i.name }}
              </option>
            </select>
            <woot-button
              :is-loading="savingKey === 'inbox'"
              :disabled="!inboxId || !!savingKey"
              @click="link({ inbox_id: inboxId }, 'inbox')"
            >
              {{ t('CREATE') }}
            </woot-button>
          </div>
        </section>

        <div class="flex justify-end">
          <woot-button
            variant="clear"
            color-scheme="secondary"
            @click="$emit('close')"
          >
            {{ t('CANCEL') }}
          </woot-button>
        </div>
      </div>
    </div>
  </woot-modal>
</template>
