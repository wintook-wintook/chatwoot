<!--
  Tareas con el cliente — «Esperando al cliente» en Mi día (ClientTasks::Watch): las tareas que le tocan al cliente
  en los casos donde eres responsable (no llevan responsable interno, así que no salen en tus tareas). Vencidas, por
  vencer, en espera y las que el cliente acaba de terminar (para revisarlas o regresarlas). «Recordarle» le escribe
  por su conversación con el enlace de su portal; «Abrir» va al caso. Si no hay nada, no se ve.
    userId   viendo el día de otra persona: las suyas (solo ver: sin «Recordarle»)
-->
<script>
import { useAlert } from 'dashboard/composables';
import CaseTasksAPI from 'dashboard/api/caseTasks';

const GROUPS = ['overdue', 'soon', 'done', 'waiting'];

export default {
  name: 'MyDayClientTasks',
  props: {
    userId: { type: [Number, String], default: null },
    readonly: { type: Boolean, default: false },
  },
  data() {
    return {
      data: null,
      open: true,
      group: 'overdue',
      remindingId: null,
      reminded: [],
    };
  },
  computed: {
    counts() {
      return this.data?.counts || {};
    },
    total() {
      return GROUPS.reduce((sum, g) => sum + (this.counts[g] || 0), 0);
    },
    groups() {
      return GROUPS.filter(g => this.counts[g]);
    },
    rows() {
      return this.data?.[this.group] || [];
    },
  },
  watch: {
    userId() {
      this.load();
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    t(key, params) {
      return this.$t(`CASE_TICKETS.TASKS.MY_DAY.CLIENT.${key}`, params);
    },
    async load() {
      try {
        const { data } = await CaseTasksAPI.clientWatch(this.userId);
        this.data = data;
        if (!this.counts[this.group]) [this.group] = this.groups;
      } catch (e) {
        this.data = null;
      }
    },
    day(value) {
      return value
        ? new Date(value).toLocaleDateString('es-MX', {
            day: 'numeric',
            month: 'short',
          })
        : '';
    },
    when(row) {
      if (row.status === 'done')
        return this.t('DONE_BY', {
          who: row.completed_by || this.t('THE_CLIENT'),
          date: this.day(row.completed_at),
        });
      if (row.days_overdue !== null && row.days_overdue !== undefined)
        return this.t('OVERDUE_DAYS', { n: row.days_overdue });
      return row.due_at ? this.t('DUE', { date: this.day(row.due_at) }) : '';
    },
    async remind(row) {
      this.remindingId = row.id;
      try {
        const { data } = await CaseTasksAPI.remindClient(row.id);
        if (data.sent) {
          this.reminded = [...this.reminded, row.id];
          useAlert(this.t('REMINDED'));
        } else {
          useAlert(this.t(`NOT_SENT.${data.reason}`));
        }
      } catch (e) {
        useAlert(this.t('NOT_SENT.error'));
      } finally {
        this.remindingId = null;
      }
    },
    openCase(row) {
      this.$router.push({
        name: 'gestorTickets_detail',
        params: { id: row.case_ticket.id },
      });
    },
  },
};
</script>

<template>
  <div>
    <section
      v-if="total"
      class="flex flex-col gap-2 p-3 bg-white border rounded-lg border-slate-100 dark:bg-slate-900 dark:border-slate-700"
      data-test="my-day-client-tasks"
    >
      <button
        type="button"
        class="flex items-center justify-between gap-2 text-left"
        @click="open = !open"
      >
        <span class="flex items-center gap-2 text-sm font-semibold">
          <fluent-icon icon="people" size="16" class="text-woot-600" />
          {{ t('TITLE', { n: total }) }}
          <span
            v-if="counts.overdue"
            class="px-1.5 py-0.5 text-[11px] font-medium rounded-full bg-red-50 text-red-700 dark:bg-red-900/30 dark:text-red-300"
          >
            {{ t('OVERDUE_BADGE', { n: counts.overdue }) }}
          </span>
          <span
            v-if="counts.done"
            class="px-1.5 py-0.5 text-[11px] font-medium rounded-full bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-300"
          >
            {{ t('DONE_BADGE', { n: counts.done }) }}
          </span>
        </span>
        <fluent-icon :icon="open ? 'chevron-up' : 'chevron-down'" size="14" />
      </button>

      <template v-if="open">
        <p class="m-0 text-xs text-slate-500">{{ t('HINT') }}</p>
        <div class="flex flex-wrap gap-1">
          <button
            v-for="g in groups"
            :key="g"
            type="button"
            class="px-2.5 py-1 text-xs border rounded-full"
            :class="
              group === g
                ? 'border-woot-500 text-woot-700 dark:text-woot-300 font-medium'
                : 'border-slate-200 dark:border-slate-600 text-slate-600 dark:text-slate-300'
            "
            @click="group = g"
          >
            {{ t(`GROUPS.${g}`, { n: counts[g] }) }}
          </button>
        </div>
        <ul class="flex flex-col m-0 list-none">
          <li
            v-for="row in rows"
            :key="row.id"
            class="flex flex-wrap items-center gap-x-3 gap-y-1 py-1.5 border-t border-slate-50 dark:border-slate-800"
          >
            <span class="flex-1 min-w-[12rem]">
              <span class="block text-sm text-slate-800 dark:text-slate-100">
                {{ row.title }}
              </span>
              <span class="block text-xs text-slate-500">
                {{ row.client }} · {{ row.case_ticket.folio }}
                <template v-if="row.client_status === 'in_progress'">
                  · {{ t('IN_PROGRESS') }}
                </template>
              </span>
            </span>
            <span
              class="text-xs"
              :class="
                group === 'overdue'
                  ? 'text-red-600'
                  : group === 'done'
                  ? 'text-green-700 dark:text-green-400'
                  : 'text-slate-500'
              "
            >
              {{ when(row) }}
            </span>
            <span class="flex gap-1">
              <woot-button
                v-if="!readonly && row.status !== 'done'"
                size="tiny"
                variant="smooth"
                :is-loading="remindingId === row.id"
                :disabled="reminded.includes(row.id)"
                @click="remind(row)"
              >
                {{
                  reminded.includes(row.id) ? t('REMINDED_SHORT') : t('REMIND')
                }}
              </woot-button>
              <woot-button
                size="tiny"
                variant="smooth"
                color-scheme="secondary"
                @click="openCase(row)"
              >
                {{ row.status === 'done' ? t('REVIEW') : t('OPEN') }}
              </woot-button>
            </span>
          </li>
        </ul>
        <p
          v-if="counts[group] > rows.length"
          class="m-0 text-[11px] text-slate-500"
        >
          {{ t('MORE', { n: counts[group] - rows.length }) }}
        </p>
      </template>
    </section>
  </div>
</template>
