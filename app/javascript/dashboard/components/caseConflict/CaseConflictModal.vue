<!--
  K1 — conflicto al guardar un caso: otra persona ya había cambiado ese mismo dato.
  Muestra qué cambió y quién; «Usar el mío» reintenta a la fuerza y «Dejar el de X»
  recarga lo que hay. En los dos casos avisa (`caseConflictResolved`) para que la
  pantalla abierta (detalle, lista o tablero) se recargue.
-->
<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { CONFLICT_EVENT } from 'dashboard/helper/caseConflict';

export default {
  name: 'CaseConflictModal',
  data() {
    return { conflict: null, saving: false };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents', teams: 'teams/getTeams' }),
    who() {
      return (this.conflict.last_change && this.conflict.last_change.by) || '';
    },
    ticketId() {
      return this.conflict.case_ticket && this.conflict.case_ticket.id;
    },
  },
  mounted() {
    this.$emitter.on(CONFLICT_EVENT, this.open);
  },
  beforeDestroy() {
    this.$emitter.off(CONFLICT_EVENT, this.open);
  },
  methods: {
    t(key, params) {
      return this.$t(`CASE_TICKETS.CONFLICT.${key}`, params);
    },
    open(conflict) {
      this.conflict = conflict;
    },
    close() {
      this.conflict = null;
    },
    label(field) {
      const key = `CASE_TICKETS.CONFLICT.FIELDS.${field.toUpperCase()}`;
      const text = this.$t(key);
      return text === key ? field.replace('custom_attributes.', '') : text;
    },
    // El valor que hay ahora, legible: nombres en vez de ids y etiquetas de estado.
    value(row) {
      const v = row.current;
      if (v === null || v === undefined || v === '') return '—';
      if (row.field === 'status') return this.$t(`CASE_TICKETS.STATUSES.${v}`);
      if (row.field === 'priority')
        return this.$t(`CASE_TICKETS.PRIORITIES.${v}`);
      if (row.field === 'assignee_id') {
        const agent = this.agents.find(a => a.id === Number(v));
        return agent ? agent.name : v;
      }
      if (row.field === 'team_id') {
        const team = (this.teams || []).find(x => x.id === Number(v));
        return team ? team.name : v;
      }
      if (row.field === 'case_type_column_id') return this.t('STAGE_CHANGED');
      return typeof v === 'object' ? JSON.stringify(v) : String(v);
    },
    when(at) {
      return at
        ? new Date(at).toLocaleTimeString([], { timeStyle: 'short' })
        : '';
    },
    resolved() {
      this.$emitter.emit('caseConflictResolved', this.ticketId);
      if (this.ticketId) {
        this.$store.dispatch('caseTickets/fetchTicket', this.ticketId);
      }
      this.close();
    },
    async useMine() {
      this.saving = true;
      try {
        await this.conflict.retry();
        useAlert(this.t('SAVED_MINE'));
        this.resolved();
      } catch (e) {
        useAlert(
          (e.response && e.response.data && e.response.data.error) ||
            this.t('ERROR')
        );
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <woot-modal :show="!!conflict" :on-close="close">
    <woot-modal-header :header-title="t('TITLE')" />
    <div v-if="conflict" class="px-6 pb-6 space-y-3">
      <p class="m-0 text-sm text-slate-700 dark:text-slate-200">
        {{ conflict.error }}
        <span
          v-if="conflict.last_change && conflict.last_change.at"
          class="text-slate-500"
        >
          ({{ when(conflict.last_change.at) }})
        </span>
      </p>
      <ul
        class="p-0 m-0 list-none border rounded-lg border-slate-100 dark:border-slate-700"
      >
        <li
          v-for="row in conflict.fields"
          :key="row.field"
          class="flex items-center justify-between gap-3 px-3 py-2 text-sm border-b last:border-b-0 border-slate-50 dark:border-slate-700/60"
        >
          <span class="text-slate-600 dark:text-slate-300">
            {{ label(row.field) }}
          </span>
          <span class="font-medium text-slate-800 dark:text-slate-100">
            {{ t('NOW', { value: value(row) }) }}
          </span>
        </li>
      </ul>
      <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
        {{ t('HINT') }}
      </p>
      <div class="flex justify-end gap-2 pt-1">
        <woot-button variant="clear" color-scheme="secondary" @click="resolved">
          {{ who ? t('KEEP_THEIRS', { name: who }) : t('KEEP_CURRENT') }}
        </woot-button>
        <woot-button :is-loading="saving" @click="useMine">
          {{ t('USE_MINE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
