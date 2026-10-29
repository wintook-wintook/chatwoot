<!--
  Página del contacto › Resumen: cuatro cifras (conversaciones y casos abiertos,
  oportunidades en curso, próxima tarea) y la actividad reciente mezclada.
  Los datos vienen de Contacts::SummariesController, ya acotados por el rol.
-->
<script>
import ContactSummaryAPI from 'dashboard/api/contactSummary';
import Spinner from 'shared/components/Spinner.vue';
import { formatMoney } from 'dashboard/helper/caseCommercial';

const ICONS = {
  conversation: 'chat',
  case: 'clipboard',
  note: 'document',
  ai: 'bot',
};

export default {
  name: 'ContactSummaryTab',
  components: { Spinner },
  props: {
    contactId: { type: Number, required: true },
  },
  emits: ['openTab'],
  data() {
    return { stats: null, activity: [], loading: true };
  },
  computed: {
    opportunitiesValue() {
      const { opportunities_amounts: amounts, opportunities_count: count } =
        this.stats;
      if (!amounts || !amounts.length) return String(count);
      return amounts.map(a => formatMoney(a.amount, a.currency)).join(' · ');
    },
    nextTaskValue() {
      const task = this.stats.next_task;
      if (!task) return this.$t('CONTACT_PAGE.SUMMARY.NONE');
      return task.title;
    },
    cards() {
      return [
        {
          key: 'OPEN_CONVERSATIONS',
          value: this.stats.open_conversations,
          tab: 'conversations',
        },
        { key: 'OPEN_CASES', value: this.stats.open_cases, tab: 'cases' },
        {
          key: 'OPPORTUNITIES',
          value: this.opportunitiesValue,
          tab: 'cases',
        },
        {
          key: 'NEXT_TASK',
          value: this.nextTaskValue,
          sub: this.stats.next_task
            ? this.formatWhen(this.stats.next_task.at)
            : '',
          tab: 'tasks',
        },
      ];
    },
  },
  watch: {
    contactId: 'fetch',
  },
  mounted() {
    this.fetch();
  },
  methods: {
    async fetch() {
      this.loading = true;
      try {
        const { data } = await ContactSummaryAPI.show(this.contactId);
        this.stats = data.stats;
        this.activity = data.activity || [];
      } catch {
        this.stats = null;
      } finally {
        this.loading = false;
      }
    },
    formatWhen(at) {
      return new Date(at).toLocaleString(undefined, {
        day: '2-digit',
        month: 'short',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    icon(item) {
      return ICONS[item.kind] || 'info';
    },
    text(item) {
      if (item.kind === 'conversation') {
        return this.$t('CONTACT_PAGE.SUMMARY.CONVERSATION', {
          id: item.id,
          inbox: item.inbox || '—',
        });
      }
      if (item.kind === 'case') {
        const key = `CASE_TICKETS.EVENT_TYPES.${item.event}`;
        const event = this.$te(key) ? this.$t(key) : item.event;
        return `${item.folio} · ${item.title} — ${event}`;
      }
      if (item.kind === 'note') {
        return `${this.$t('CONTACT_PAGE.SUMMARY.NOTE')}: «${item.text}»`;
      }
      const statusKey = `CONTACT_PAGE.SUMMARY.AI_STATUS.${item.status}`;
      return this.$t('CONTACT_PAGE.SUMMARY.AI', {
        name: item.name || '—',
        status: this.$te(statusKey) ? this.$t(statusKey) : item.status,
      });
    },
    open(item) {
      const { accountId } = this.$route.params;
      if (item.kind === 'conversation') {
        this.$router.push({
          name: 'inbox_conversation',
          params: { accountId, conversation_id: item.id },
        });
      } else if (item.kind === 'case') {
        this.$router.push({
          name: 'gestorTickets_detail',
          params: { accountId, id: item.ticket_id },
        });
      } else if (item.kind === 'note') {
        this.$emit('openTab', 'notes');
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-6">
    <Spinner v-if="loading" />
    <template v-else-if="stats">
      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <button
          v-for="card in cards"
          :key="card.key"
          type="button"
          class="flex flex-col items-start min-w-0 gap-1 p-4 overflow-hidden text-left bg-white border rounded-lg dark:bg-slate-900 border-slate-75 dark:border-slate-700 hover:border-woot-500"
          @click="$emit('openTab', card.tab)"
        >
          <span class="text-xs text-slate-500 dark:text-slate-400">
            {{ $t(`CONTACT_PAGE.SUMMARY.${card.key}`) }}
          </span>
          <span
            class="block w-full text-lg font-semibold truncate text-slate-800 dark:text-slate-100"
            :title="String(card.value)"
          >
            {{ card.value }}
          </span>
          <span
            v-if="card.sub"
            class="text-xs text-slate-500 dark:text-slate-400"
          >
            {{ card.sub }}
          </span>
        </button>
      </div>

      <section>
        <h3
          class="mb-2 text-xs font-semibold tracking-wide uppercase text-slate-500 dark:text-slate-400"
        >
          {{ $t('CONTACT_PAGE.SUMMARY.ACTIVITY') }}
        </h3>
        <p
          v-if="!activity.length"
          class="text-sm text-slate-500 dark:text-slate-400"
        >
          {{ $t('CONTACT_PAGE.SUMMARY.NO_ACTIVITY') }}
        </p>
        <ul
          v-else
          class="p-0 m-0 list-none bg-white border divide-y rounded-lg dark:bg-slate-900 border-slate-75 dark:border-slate-700 divide-slate-50 dark:divide-slate-800"
        >
          <li
            v-for="(item, index) in activity"
            :key="`${item.kind}-${index}`"
            class="flex items-start gap-3 px-3 py-2"
            :class="{
              'cursor-pointer hover:bg-slate-25 dark:hover:bg-slate-800':
                item.kind !== 'ai',
            }"
            @click="open(item)"
          >
            <fluent-icon
              :icon="icon(item)"
              size="16"
              class="mt-0.5 flex-shrink-0 text-slate-500 dark:text-slate-400"
            />
            <div class="flex flex-col flex-1 min-w-0">
              <span
                class="text-sm break-words text-slate-800 dark:text-slate-100"
              >
                {{ text(item) }}
              </span>
              <span
                v-if="item.user"
                class="text-xs text-slate-500 dark:text-slate-400"
              >
                {{ $t('CONTACT_PAGE.SUMMARY.BY', { name: item.user }) }}
              </span>
            </div>
            <span
              class="text-xs whitespace-nowrap text-slate-500 dark:text-slate-400"
            >
              {{ formatWhen(item.at) }}
            </span>
          </li>
        </ul>
      </section>
    </template>
  </div>
</template>
