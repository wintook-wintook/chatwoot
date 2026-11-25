<script>
import { mapGetters } from 'vuex';
import GoogleCalendarAPI from '../../api/googleCalendar';

// fix/calendario_google F3c — «Compartir mi calendario». Cada cambio va directo a las reglas
// de acceso de MI Google Calendar (con mi conexión); Google lo aplica igual que en su web.
const LEVELS = ['none', 'free_busy', 'details', 'schedule'];
const LEVEL_KEYS = {
  none: 'NONE',
  free_busy: 'FREE_BUSY',
  details: 'DETAILS',
  schedule: 'SCHEDULE',
};
const STATUS_KEYS = {
  not_connected: 'NOT_CONNECTED',
  same_google: 'SAME_GOOGLE',
  owner_rule: 'OWNER_RULE',
};

export default {
  name: 'ShareCalendarModal',
  props: {
    show: { type: Boolean, default: false },
  },
  emits: ['close'],
  data() {
    return {
      rules: [],
      loading: false,
      loadError: '',
      // Por agente: 'saving' | 'saved' | mensaje de error de Google.
      rowState: {},
    };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
    levelOptions() {
      return LEVELS.map(level => ({
        value: level,
        label: this.$t(
          `GOOGLE_CALENDAR.SHARE_CALENDAR.LEVELS.${LEVEL_KEYS[level]}`
        ),
      }));
    },
    rows() {
      const agentsById = Object.fromEntries(this.agents.map(a => [a.id, a]));
      return this.rules
        .filter(r => agentsById[r.agent_id])
        .map(r => {
          const agent = agentsById[r.agent_id];
          const state = this.rowState[r.agent_id] || '';
          return {
            agentId: r.agent_id,
            name: agent.available_name || agent.name,
            thumbnail: agent.thumbnail,
            level: r.level,
            editable: r.status === 'editable',
            statusLabel: STATUS_KEYS[r.status]
              ? this.$t(
                  `GOOGLE_CALENDAR.SHARE_CALENDAR.STATUS.${
                    STATUS_KEYS[r.status]
                  }`
                )
              : '',
            saving: state === 'saving',
            note: this.noteFor(state),
            isError: !!state && !['saving', 'saved'].includes(state),
          };
        });
    },
  },
  watch: {
    show(value) {
      if (value) this.load();
    },
  },
  methods: {
    noteFor(state) {
      if (state === 'saving')
        return this.$t('GOOGLE_CALENDAR.SHARE_CALENDAR.SAVING');
      if (state === 'saved')
        return this.$t('GOOGLE_CALENDAR.SHARE_CALENDAR.SAVED');
      return state;
    },
    async load() {
      this.loading = true;
      this.loadError = '';
      this.rowState = {};
      try {
        const { data } = await GoogleCalendarAPI.getSharingRules();
        this.rules = data.sharing_rules || [];
      } catch (error) {
        const reason = error?.response?.data?.error;
        this.rules = [];
        this.loadError =
          reason === 'reconnect'
            ? this.$t('GOOGLE_CALENDAR.SHARE_CALENDAR.RECONNECT')
            : this.$t('GOOGLE_CALENDAR.SHARE_CALENDAR.LOAD_ERROR');
      } finally {
        this.loading = false;
      }
    },
    setRowState(agentId, state) {
      this.rowState = { ...this.rowState, [agentId]: state };
    },
    async changeLevel(agentId, level) {
      const previous = this.rules.find(r => r.agent_id === agentId);
      this.setRowState(agentId, 'saving');
      try {
        const { data } = await GoogleCalendarAPI.updateSharingRule(
          agentId,
          level
        );
        this.rules = this.rules.map(r => (r.agent_id === agentId ? data : r));
        this.setRowState(agentId, 'saved');
      } catch (error) {
        // Se queda como estaba y se muestra el motivo (p. ej. Workspace no deja compartir).
        this.rules = this.rules.map(r =>
          r.agent_id === agentId ? { ...previous } : r
        );
        this.setRowState(
          agentId,
          error?.response?.data?.error ||
            this.$t('GOOGLE_CALENDAR.SHARE_CALENDAR.LOAD_ERROR')
        );
      }
    },
    onClose() {
      this.$emit('close');
    },
  },
};
</script>

<template>
  <woot-modal :show="show" :on-close="onClose" size="medium">
    <woot-modal-header
      :header-title="$t('GOOGLE_CALENDAR.SHARE_CALENDAR.TITLE')"
      :header-content="$t('GOOGLE_CALENDAR.SHARE_CALENDAR.DESCRIPTION')"
    />
    <div class="px-8 pb-8 pt-2 space-y-3">
      <p v-if="loading" class="text-sm text-slate-500 dark:text-slate-400">
        {{ $t('GOOGLE_CALENDAR.SHARE_CALENDAR.LOADING') }}
      </p>
      <p v-else-if="loadError" class="text-sm text-ruby-600 dark:text-ruby-400">
        {{ loadError }}
      </p>
      <p
        v-else-if="!rows.length"
        class="text-sm text-slate-500 dark:text-slate-400"
      >
        {{ $t('GOOGLE_CALENDAR.SHARE_CALENDAR.EMPTY') }}
      </p>
      <template v-else>
        <div
          v-for="row in rows"
          :key="row.agentId"
          class="flex items-center gap-3"
        >
          <img
            v-if="row.thumbnail"
            :src="row.thumbnail"
            class="w-6 h-6 rounded-full flex-shrink-0 object-cover"
            :alt="row.name"
          />
          <div class="flex-1 min-w-0">
            <p class="text-sm text-slate-700 dark:text-slate-200 truncate">
              {{ row.name }}
            </p>
            <p
              v-if="row.note"
              class="text-xs"
              :class="
                row.isError
                  ? 'text-ruby-600 dark:text-ruby-400'
                  : 'text-slate-400 dark:text-slate-500'
              "
            >
              {{ row.note }}
            </p>
          </div>
          <select
            v-if="row.editable"
            :value="row.level"
            :disabled="row.saving"
            class="w-56 px-3 py-2 text-sm border rounded-md border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 disabled:opacity-60 disabled:cursor-not-allowed"
            @change="changeLevel(row.agentId, $event.target.value)"
          >
            <option
              v-for="option in levelOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
          <span v-else class="text-xs text-slate-400 dark:text-slate-500">
            {{ row.statusLabel }}
          </span>
        </div>
      </template>
      <div class="flex justify-end pt-2">
        <woot-button variant="clear" @click="onClose">
          {{ $t('GOOGLE_CALENDAR.SHARE_CALENDAR.CLOSE') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
