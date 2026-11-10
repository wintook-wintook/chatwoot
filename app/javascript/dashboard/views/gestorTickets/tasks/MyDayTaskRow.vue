<!--
  @tickets_cases — Plan-Bandeja-Prioridad F2: una tarea de «Mi día».
  `highlight` = la SIGUIENTE (tarjeta grande con acciones a la vista); si no,
  fila compacta. `draggable` muestra el asa para arrastrar. Las acciones salen
  por eventos y las resuelve la bandeja.
-->
<script>
import {
  REASON_TONE,
  formatMinutes,
  reasonTone,
  visibleReasons,
} from 'dashboard/helper/caseTaskPriority';
import { formatDay } from 'dashboard/helper/caseCommercial';

export default {
  name: 'MyDayTaskRow',
  props: {
    row: { type: Object, required: true },
    rank: { type: Number, default: 0 },
    planned: { type: Boolean, default: false },
    highlight: { type: Boolean, default: false },
    draggable: { type: Boolean, default: false },
    completingId: { type: [Number, String], default: null },
  },
  emits: ['openTask', 'openTicket', 'complete', 'pin', 'unpin', 'postpone'],
  computed: {
    reasons() {
      return visibleReasons(this.row.reasons);
    },
    waiting() {
      return (this.row.reasons || []).some(r => r.key === 'waiting');
    },
    frozen() {
      const st = this.row.case_ticket && this.row.case_ticket.status;
      return st === 'closed' || st === 'cancelled';
    },
    taskFolio() {
      const seq = this.row.sequence;
      return seq ? `T${String(seq).padStart(3, '0')}` : '';
    },
    dueLabel() {
      if (!this.row.due_at) return '';
      return new Date(this.row.due_at).toLocaleString(undefined, {
        day: '2-digit',
        month: 'short',
        hour: '2-digit',
        minute: '2-digit',
      });
    },
    estimate() {
      return formatMinutes(this.row.estimated_minutes);
    },
  },
  methods: {
    reasonClass(key) {
      return REASON_TONE[reasonTone(key)];
    },
    reasonLabel(reason) {
      const base = 'CASE_TICKETS.TASKS.MY_DAY.REASONS';
      if (reason.key === 'overdue' && !reason.days) {
        return this.$t(`${base}.overdue_today`);
      }
      return this.$t(`${base}.${reason.key}`, {
        days: reason.days,
        date: reason.date ? formatDay(reason.date) : '',
      });
    },
  },
};
</script>

<template>
  <div
    class="flex items-start gap-3 bg-white dark:bg-slate-800"
    :class="
      highlight
        ? 'p-4 border-2 rounded-xl border-woot-500 dark:border-woot-400'
        : 'px-3 py-2.5 border rounded-lg border-slate-100 dark:border-slate-700'
    "
  >
    <span
      v-if="draggable"
      class="my-day-handle pt-0.5 cursor-grab text-slate-300 hover:text-slate-500 dark:text-slate-600 dark:hover:text-slate-400"
      :title="$t('CASE_TICKETS.TASKS.MY_DAY.DRAG')"
    >
      <fluent-icon icon="drag" size="16" />
    </span>
    <span
      v-if="rank"
      class="w-6 pt-0.5 font-mono text-sm font-semibold text-right tabular-nums text-slate-400 dark:text-slate-500"
    >
      {{ rank }}
    </span>

    <div class="flex-1 min-w-0">
      <span
        v-if="highlight"
        class="inline-block mb-2 px-2 py-0.5 text-[11px] font-bold uppercase tracking-wide rounded-full bg-woot-500 text-white"
      >
        {{ $t('CASE_TICKETS.TASKS.MY_DAY.NEXT') }}
      </span>
      <button
        type="button"
        class="block w-full m-0 font-medium text-left truncate text-slate-800 dark:text-slate-100 hover:underline"
        :class="highlight ? 'text-lg font-semibold' : 'text-sm'"
        :title="row.title"
        @click="$emit('openTask', row)"
      >
        {{ row.title }}
      </button>
      <div class="flex flex-wrap items-center gap-1.5 mt-1">
        <span class="font-mono text-xs text-slate-400">{{ taskFolio }}</span>
        <button
          v-if="row.case_ticket"
          type="button"
          class="flex items-center min-w-0 gap-1 text-xs hover:underline text-slate-500 dark:text-slate-400"
          :title="$t('CASE_TICKETS.TASKS.INBOX.OPEN_TICKET')"
          @click="$emit('openTicket', row)"
        >
          <span
            v-if="row.case_ticket.case_type"
            class="inline-block w-2 h-2 rounded-sm flex-shrink-0"
            :style="{ backgroundColor: row.case_ticket.case_type.color }"
          />
          <span class="font-mono font-semibold">
            {{ row.case_ticket.folio }}
          </span>
          <span v-if="highlight" class="truncate">
            {{ row.case_ticket.title }}
          </span>
        </button>
        <button
          v-else-if="row.contact"
          type="button"
          class="text-xs truncate hover:underline text-slate-500 dark:text-slate-400"
          @click="$emit('openTicket', row)"
        >
          {{ row.contact.name }}
        </button>
        <span
          v-else-if="row.organization"
          class="text-xs truncate text-slate-500 dark:text-slate-400"
        >
          {{ row.organization.name }}
        </span>
        <span
          v-for="r in reasons"
          :key="r.key"
          class="px-1.5 py-0.5 text-[11px] font-medium rounded-full"
          :class="reasonClass(r.key)"
        >
          {{ reasonLabel(r) }}
        </span>
        <span
          v-if="waiting"
          class="px-1.5 py-0.5 text-[11px] font-medium rounded-full"
          :class="reasonClass('waiting')"
        >
          {{ reasonLabel({ key: 'waiting' }) }}
        </span>
      </div>

      <div v-if="highlight" class="flex flex-wrap items-center gap-2 mt-4">
        <woot-button
          v-if="!frozen"
          size="small"
          color-scheme="primary"
          icon="checkmark"
          :is-loading="completingId === row.id"
          :disabled="!!completingId"
          @click="$emit('complete', row)"
        >
          {{ $t('CASE_TICKETS.TASKS.COMPLETE') }}
        </woot-button>
        <woot-button
          v-if="row.case_ticket"
          size="small"
          variant="smooth"
          color-scheme="secondary"
          @click="$emit('openTicket', row)"
        >
          {{ $t('CASE_TICKETS.TASKS.INBOX.OPEN_TICKET') }}
        </woot-button>
        <woot-button
          v-if="!frozen"
          size="small"
          variant="smooth"
          color-scheme="secondary"
          icon="snooze"
          @click="$emit('postpone', row)"
        >
          {{ $t('CASE_TICKETS.TASKS.MY_DAY.POSTPONE') }}
        </woot-button>
        <span class="text-xs text-slate-500 dark:text-slate-400">
          <template v-if="dueLabel">
            {{ $t('CASE_TICKETS.TASKS.MY_DAY.DUE', { date: dueLabel }) }}
          </template>
          <template v-if="estimate">· {{ estimate }}</template>
        </span>
      </div>
    </div>

    <div class="flex flex-col items-end flex-shrink-0 gap-1">
      <span
        class="font-mono font-semibold tabular-nums"
        :class="
          highlight
            ? 'text-sm font-bold text-woot-600 dark:text-woot-300'
            : 'text-sm text-slate-600 dark:text-slate-300'
        "
        :title="$t('CASE_TICKETS.TASKS.MY_DAY.SCORE_TITLE')"
      >
        {{ row.score }}
      </span>
      <span
        v-if="estimate && !highlight"
        class="text-[11px] text-slate-400 dark:text-slate-500"
      >
        {{ estimate }}
      </span>
    </div>

    <div class="flex items-center flex-shrink-0 gap-1">
      <woot-button
        v-if="planned"
        size="tiny"
        variant="clear"
        color-scheme="secondary"
        icon="dismiss"
        :title="$t('CASE_TICKETS.TASKS.MY_DAY.UNPIN')"
        @click="$emit('unpin', row)"
      />
      <woot-button
        v-else
        size="tiny"
        variant="smooth"
        color-scheme="primary"
        icon="arrow-up"
        :title="$t('CASE_TICKETS.TASKS.MY_DAY.PIN')"
        @click="$emit('pin', row)"
      />
      <template v-if="!highlight && !frozen">
        <woot-button
          size="tiny"
          variant="clear"
          color-scheme="secondary"
          icon="snooze"
          :title="$t('CASE_TICKETS.TASKS.MY_DAY.POSTPONE')"
          @click="$emit('postpone', row)"
        />
        <woot-button
          size="tiny"
          variant="smooth"
          color-scheme="secondary"
          icon="checkmark"
          :title="$t('CASE_TICKETS.TASKS.COMPLETE_TITLE')"
          :is-loading="completingId === row.id"
          :disabled="!!completingId"
          @click="$emit('complete', row)"
        />
      </template>
    </div>
  </div>
</template>
