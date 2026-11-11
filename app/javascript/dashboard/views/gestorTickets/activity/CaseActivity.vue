<!--
  Plan Actividad del caso — pestaña principal del caso.
  Arriba la tarjeta «¿cómo va?»: qué sigue, el último contacto con el cliente y
  lo atrasado. Abajo TODO lo que pasó en una sola lista, de lo más nuevo a lo más
  viejo: la bitácora (cambios, notas, tareas, tareas agendadas, cotizaciones) y
  los mensajes de todas las conversaciones del caso, resumidos por día.
  Los datos salen de GET …/case_tickets/:id/activity (Cases::ActivityFeed).
  Registrar (Nota, Tarea, Agendar, Mensaje) y las conversaciones del caso viven
  en la barra de pestañas del detalle (CaseConversationsMenu), no aquí: así la
  historia tiene más espacio.
-->
<script>
import CaseTicketsAPI from 'dashboard/api/caseTickets';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import caseEventText from '../caseEventText';
import { assistantState as assistant } from 'dashboard/helper/assistantState';

const T = 'CASE_TICKETS.ACTIVITY';
const PAGE = 40;

// Qué filtro le toca a cada evento (los grupos de mensajes van a «client»).
const CLIENT_EVENTS = [
  'conversation_link',
  'conversation_unlinked',
  'message_received',
  'message_sent',
  'ai_followup',
];
const FILTERS = ['all', 'client', 'notes', 'tasks', 'changes'];

export default {
  name: 'CaseActivity',
  mixins: [caseEventText],
  props: {
    ticket: { type: Object, required: true },
    // Cambia cuando el detalle recarga el caso o su bitácora: se vuelve a pedir.
    refreshKey: { type: String, default: '' },
  },
  emits: ['openTab'],
  data() {
    return {
      items: [],
      summary: null,
      linked: [],
      isLoading: false,
      loadError: false,
      filter: 'all',
      limit: PAGE,
      filters: FILTERS,
    };
  },
  computed: {
    filtered() {
      if (this.filter === 'all') return this.items;
      return this.items.filter(i => this.category(i) === this.filter);
    },
    visible() {
      return this.filtered.slice(0, this.limit);
    },
    // La lista partida por día, con su encabezado.
    days() {
      const days = [];
      this.visible.forEach(item => {
        const key = this.dayKey(item);
        let day = days[days.length - 1];
        if (!day || day.key !== key) {
          day = { key, label: this.dayLabel(key), items: [] };
          days.push(day);
        }
        day.items.push(item);
      });
      return days;
    },
    counts() {
      const counts = { all: this.items.length };
      this.items.forEach(i => {
        const c = this.category(i);
        counts[c] = (counts[c] || 0) + 1;
      });
      return counts;
    },
    nextTaskOverdue() {
      const due = this.summary?.next_task?.due_at;
      return !!due && new Date(due) < new Date();
    },
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
      this.isLoading = !this.items.length;
      this.loadError = false;
      try {
        const [activity, conversations] = await Promise.all([
          CaseTicketsAPI.getActivity(this.ticket.id),
          CaseTicketsAPI.getConversations(this.ticket.id),
        ]);
        this.items = activity.data.items;
        this.summary = activity.data.summary;
        this.linked = conversations.data.conversations;
      } catch (_e) {
        this.loadError = true;
      } finally {
        this.isLoading = false;
      }
    },
    setFilter(key) {
      this.filter = key;
      this.limit = PAGE;
    },
    category(item) {
      if (item.kind === 'messages') return 'client';
      const type = item.event_type;
      if (CLIENT_EVENTS.includes(type)) return 'client';
      if (type === 'internal_note') return 'notes';
      if (
        type.startsWith('task_') ||
        type.startsWith('meeting_') ||
        type === 'stage_tasks_added'
      ) {
        return 'tasks';
      }
      return 'changes';
    },
    icon(item) {
      if (item.kind === 'messages') {
        return this.isEmail(item.conversation) ? 'mail' : 'chat';
      }
      const type = item.event_type;
      if (type.startsWith('meeting_')) return 'calendar-clock';
      if (type.startsWith('quote_')) return 'document-text-link';
      return {
        client: 'link',
        notes: 'document',
        tasks: 'checkmark-circle',
        changes: 'arrow-swap',
      }[this.category(item)];
    },
    iconClass(item) {
      return {
        client: 'bg-sky-50 text-sky-600 dark:bg-sky-900/30 dark:text-sky-300',
        notes:
          'bg-amber-50 text-amber-600 dark:bg-amber-900/30 dark:text-amber-300',
        tasks:
          'bg-green-50 text-green-600 dark:bg-green-900/30 dark:text-green-300',
        changes:
          'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-300',
      }[this.category(item)];
    },
    isEmail(conversation) {
      return (conversation?.channel_type || '').includes('Email');
    },
    // --- textos -------------------------------------------------------------------
    title(item) {
      if (item.kind === 'messages') return this.messagesTitle(item);
      if (item.payload?.kind === 'task_report') return this.t('TASK_REPORT');
      if (item.payload?.kind === 'activity_report')
        return this.t('ACTIVITY_REPORT');
      return this.eventLabel({ event_type: item.event_type });
    },
    messagesTitle(item) {
      const parts = [];
      if (item.incoming) parts.push(this.t('RECEIVED', { n: item.incoming }));
      if (item.outgoing) parts.push(this.t('SENT', { n: item.outgoing }));
      return parts.join(' · ');
    },
    conversationName(conversation) {
      if (!conversation) return '';
      const name = `#${conversation.display_id} · ${
        conversation.inbox_name || '—'
      }`;
      return conversation.subject ? `${name} · ${conversation.subject}` : name;
    },
    detail(item) {
      if (item.kind === 'messages')
        return this.conversationName(item.conversation);
      // Notas: el texto completo (sin el título del reporte, que ya es el título).
      if (item.event_type === 'internal_note')
        return item.payload?.content || '';
      return this.payloadSummary({
        event_type: item.event_type,
        payload: item.payload || {},
      });
    },
    who(item) {
      if (item.kind === 'messages') return null;
      // Asistente (Dali) — lo que se hizo al confirmar una propuesta del asistente.
      if (item.payload?.via === 'assistant') {
        return `${this.actorName(item)} · ${this.$t('ASSISTANT.VIA', {
          name: assistant.name,
        })}`;
      }
      return this.actorName(item);
    },
    lastLine(item) {
      const last = item.last;
      if (!last || !last.content) return '';
      const who = last.incoming
        ? last.sender || this.t('CUSTOMER')
        : last.sender || this.t('WE');
      return `${who}: ${last.content}`;
    },
    time(item) {
      return new Date(item.at).toLocaleTimeString(this.$i18n.locale, {
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    // Día local del elemento (los mensajes ya vienen agrupados por día local).
    dayKey(item) {
      if (item.kind === 'messages') return item.day;
      const d = new Date(item.at);
      const pad = n => String(n).padStart(2, '0');
      return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
    },
    dayLabel(key) {
      const date = new Date(`${key}T12:00:00`);
      const today = new Date();
      const yesterday = new Date();
      yesterday.setDate(today.getDate() - 1);
      if (date.toDateString() === today.toDateString()) return this.t('TODAY');
      if (date.toDateString() === yesterday.toDateString()) {
        return this.t('YESTERDAY');
      }
      return date.toLocaleDateString(this.$i18n.locale, {
        weekday: 'long',
        day: 'numeric',
        month: 'long',
        year:
          date.getFullYear() === today.getFullYear() ? undefined : 'numeric',
      });
    },
    // «hace 2 días», «en 3 horas».
    // Vencimiento de una tarea: solo el día («hoy», «mañana», «en 3 días»), sin hora.
    dueDay(iso) {
      if (!iso) return '';
      const day = d => new Date(d.getFullYear(), d.getMonth(), d.getDate());
      const diff = Math.round(
        (day(new Date(iso)) - day(new Date())) / 86400000
      );
      const rtf = new Intl.RelativeTimeFormat(this.$i18n.locale, {
        numeric: 'auto',
      });
      return rtf.format(diff, 'day');
    },
    relative(iso) {
      if (!iso) return '';
      const diff = (new Date(iso) - new Date()) / 1000;
      const rtf = new Intl.RelativeTimeFormat(this.$i18n.locale, {
        numeric: 'auto',
      });
      const abs = Math.abs(diff);
      if (abs < 3600) return rtf.format(Math.round(diff / 60), 'minute');
      if (abs < 86400) return rtf.format(Math.round(diff / 3600), 'hour');
      return rtf.format(Math.round(diff / 86400), 'day');
    },
    taskFolio(task) {
      return `T${String(task.sequence).padStart(3, '0')}`;
    },
    // --- acciones -------------------------------------------------------------------
    openItem(item) {
      if (item.kind === 'messages') {
        this.openConversation(item.conversation);
        return;
      }
      const type = item.event_type;
      if (type.startsWith('meeting_')) this.$emit('openTab', 'meetings');
      else if (type.startsWith('task_') || type === 'stage_tasks_added') {
        this.$emit('openTab', 'tasks');
      } else if (type.startsWith('quote_')) this.$emit('openTab', 'quotes');
    },
    clickable(item) {
      if (item.kind === 'messages') return true;
      return /^(meeting_|task_|quote_)|^stage_tasks_added$/.test(
        item.event_type
      );
    },
    // La principal se ve dentro del caso; las adicionales, en Conversaciones.
    openConversation(conversation) {
      if (!conversation) return;
      if (conversation.primary) {
        this.$emit('openTab', 'detail');
        return;
      }
      const accountId = this.$route.params.accountId;
      this.$router.push(
        frontendURL(conversationUrl({ accountId, id: conversation.display_id }))
      );
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- ════ ¿Cómo va? ════ -->
    <div
      v-if="summary"
      class="grid gap-3 p-4 bg-white border rounded-lg md:grid-cols-2 border-slate-100 dark:bg-slate-900 dark:border-slate-800"
    >
      <!-- Qué sigue -->
      <div class="flex flex-col gap-1.5 min-w-0">
        <span class="text-xs font-medium uppercase text-slate-500">
          {{ t('NEXT') }}
          <span
            v-if="summary.overdue_tasks"
            class="ml-1 px-1.5 py-0.5 rounded-full normal-case bg-red-50 text-red-700 dark:bg-red-900/30 dark:text-red-300"
          >
            {{ t('OVERDUE', { n: summary.overdue_tasks }) }}
          </span>
        </span>
        <button
          v-if="summary.next_task"
          class="flex items-center gap-2 p-0 text-sm text-left bg-transparent border-0 cursor-pointer text-slate-800 dark:text-slate-100 hover:underline"
          @click="$emit('openTab', 'tasks')"
        >
          <fluent-icon icon="checkmark-circle" size="14" class="shrink-0" />
          <span class="truncate">
            <span class="font-mono text-xs text-slate-400">{{
              taskFolio(summary.next_task)
            }}</span>
            {{ summary.next_task.title }}
            <span
              v-if="summary.next_task.due_at"
              :class="
                nextTaskOverdue
                  ? 'text-red-600 dark:text-red-400'
                  : 'text-slate-500'
              "
            >
              · {{ t('DUE', { when: dueDay(summary.next_task.due_at) }) }}
            </span>
            <span v-if="summary.next_task.assignee" class="text-slate-500">
              · {{ summary.next_task.assignee.name }}
            </span>
          </span>
        </button>
        <button
          v-if="summary.next_meeting"
          class="flex items-center gap-2 p-0 text-sm text-left bg-transparent border-0 cursor-pointer text-slate-800 dark:text-slate-100 hover:underline"
          @click="$emit('openTab', 'meetings')"
        >
          <fluent-icon icon="calendar-clock" size="14" class="shrink-0" />
          <span class="truncate">
            {{ summary.next_meeting.title }}
            <span class="text-slate-500">
              · {{ formatDate(summary.next_meeting.starts_at) }}
            </span>
          </span>
        </button>
        <span
          v-if="!summary.next_task && !summary.next_meeting"
          class="text-sm text-slate-500"
        >
          {{ t('NOTHING_PENDING') }}
        </span>
      </div>

      <!-- Último contacto -->
      <div class="flex flex-col gap-1.5 min-w-0">
        <span class="text-xs font-medium uppercase text-slate-500">
          {{ t('LAST_CONTACT') }}
        </span>
        <span
          v-if="summary.last_incoming"
          class="text-sm truncate text-slate-800 dark:text-slate-100"
        >
          {{
            t('CUSTOMER_WROTE', {
              when: relative(summary.last_incoming.at),
              where: summary.last_incoming.conversation.inbox_name,
            })
          }}
        </span>
        <span
          v-if="summary.last_outgoing"
          class="text-sm truncate text-slate-800 dark:text-slate-100"
        >
          {{
            t('WE_WROTE', {
              when: relative(summary.last_outgoing.at),
              where: summary.last_outgoing.conversation.inbox_name,
            })
          }}
        </span>
        <span
          v-if="!summary.last_incoming && !summary.last_outgoing"
          class="text-sm text-slate-500"
        >
          {{ linked.length ? t('NO_MESSAGES') : t('NO_CONVERSATION') }}
        </span>
      </div>
    </div>

    <!-- ════ Filtros ════ -->
    <div class="flex flex-wrap gap-1.5">
      <button
        v-for="key in filters"
        :key="key"
        class="px-2.5 py-1 text-xs border rounded-full cursor-pointer"
        :class="
          filter === key
            ? 'bg-woot-50 border-woot-200 text-woot-700 dark:bg-woot-900/30 dark:border-woot-700 dark:text-woot-200'
            : 'bg-white border-slate-200 text-slate-600 dark:bg-slate-900 dark:border-slate-700 dark:text-slate-300'
        "
        @click="setFilter(key)"
      >
        {{ t(`FILTERS.${key}`) }}
        <span class="text-slate-400">{{ counts[key] || 0 }}</span>
      </button>
    </div>

    <!-- ════ Lista ════ -->
    <p v-if="isLoading" class="m-0 text-sm text-slate-500">
      {{ t('LOADING') }}
    </p>
    <p v-else-if="loadError" class="m-0 text-sm text-red-600">
      {{ t('ERROR') }}
    </p>
    <p v-else-if="!filtered.length" class="m-0 text-sm text-slate-500">
      {{ t('EMPTY') }}
    </p>
    <div v-else class="flex flex-col gap-4">
      <section v-for="day in days" :key="day.key" class="flex flex-col gap-1">
        <h4
          class="sticky top-0 z-10 py-1 m-0 text-xs font-semibold uppercase bg-slate-25 dark:bg-slate-900 text-slate-500"
        >
          {{ day.label }}
        </h4>
        <div
          v-for="item in day.items"
          :key="`${item.kind}-${item.id}`"
          class="flex gap-3 px-3 py-2 rounded-lg"
          :class="
            clickable(item)
              ? 'cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-800/60'
              : ''
          "
          @click="clickable(item) && openItem(item)"
        >
          <span
            class="flex items-center justify-center w-7 h-7 rounded-full shrink-0"
            :class="iconClass(item)"
          >
            <fluent-icon :icon="icon(item)" size="14" />
          </span>
          <div class="flex flex-col flex-1 min-w-0 gap-0.5">
            <div class="flex items-baseline gap-2">
              <span
                class="text-sm font-medium text-slate-800 dark:text-slate-100"
              >
                {{ title(item) }}
              </span>
              <span class="text-xs text-slate-400 shrink-0">
                {{ time(item) }}
                <template v-if="who(item)"> · {{ who(item) }}</template>
              </span>
            </div>
            <span
              v-if="detail(item)"
              class="text-sm whitespace-pre-line text-slate-600 dark:text-slate-300 line-clamp-4"
              >{{ detail(item) }}</span
            >
            <span
              v-if="item.kind === 'messages' && lastLine(item)"
              class="text-xs truncate text-slate-500"
            >
              {{ lastLine(item) }}
            </span>
          </div>
        </div>
      </section>
      <woot-button
        v-if="filtered.length > limit"
        size="small"
        variant="clear"
        @click="limit += 40"
      >
        {{ t('MORE', { n: filtered.length - limit }) }}
      </woot-button>
    </div>
  </div>
</template>
