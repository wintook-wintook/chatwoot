<script>
import { mapGetters } from 'vuex';
import GoogleCalendarAPI from '../../api/googleCalendar';
import Thumbnail from '../widgets/Thumbnail.vue';
import WootSubmitButton from '../buttons/FormSubmitButton.vue';

// fix/calendario_google F3c — «Compartir mi calendario». Cada cambio va directo a las reglas
// de acceso de MI Google Calendar (con mi conexión); Google lo aplica igual que en su web.
// Pestañas: compañeros de la cuenta · otras personas (cualquier correo).
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
const ERROR_KEYS = {
  invalid_email: 'INVALID_EMAIL',
  own_email: 'OWN_EMAIL',
  owner_rule: 'OWNER_RULE',
  not_connected: 'NOT_CONNECTED',
  same_google: 'SAME_GOOGLE',
  reconnect: 'RECONNECT',
};
const GENERAL_KEYS = { default: 'PUBLIC', domain: 'DOMAIN', group: 'GROUP' };

export default {
  name: 'ShareCalendarModal',
  components: { Thumbnail, WootSubmitButton },
  props: {
    show: { type: Boolean, default: false },
  },
  emits: ['close'],
  data() {
    return {
      tab: 0,
      rules: [],
      others: [],
      generalRules: [],
      loading: false,
      loadError: '',
      // Por fila (agente o correo): 'saving' | 'saved' | mensaje de error.
      rowState: {},
      newEmail: '',
      newLevel: 'details',
      adding: false,
      addError: '',
    };
  },
  computed: {
    ...mapGetters({ agents: 'agents/getAgents' }),
    levelOptions() {
      return LEVELS.map(level => ({
        value: level,
        label: this.levelLabel(level),
      }));
    },
    // Para agregar a alguien no tiene sentido «Nada».
    addLevelOptions() {
      return this.levelOptions.filter(o => o.value !== 'none');
    },
    tabs() {
      return [
        {
          key: 'coworkers',
          label: this.t('TABS.COWORKERS'),
          count: this.sharedCoworkers,
        },
        {
          key: 'others',
          label: this.t('TABS.OTHERS'),
          count: this.others.length,
        },
      ];
    },
    sharedCoworkers() {
      return this.rules.filter(r => r.level !== 'none').length;
    },
    coworkerRows() {
      const agentsById = Object.fromEntries(this.agents.map(a => [a.id, a]));
      return this.rules
        .filter(r => agentsById[r.agent_id])
        .map(r => {
          const agent = agentsById[r.agent_id];
          const key = `agent:${r.agent_id}`;
          return {
            key,
            agentId: r.agent_id,
            name: agent.available_name || agent.name,
            thumbnail: agent.thumbnail || '',
            level: r.level,
            editable: r.status === 'editable',
            statusLabel: STATUS_KEYS[r.status]
              ? this.t(`STATUS.${STATUS_KEYS[r.status]}`)
              : '',
            ...this.rowFeedback(key),
          };
        });
    },
    otherRows() {
      return this.others.map(o => {
        const key = `email:${o.email}`;
        return {
          key,
          email: o.email,
          level: o.level,
          editable: o.status === 'editable',
          statusLabel:
            o.status === 'owner_rule' ? this.t('STATUS.OWNER_RULE') : '',
          ...this.rowFeedback(key),
        };
      });
    },
    generalNotes() {
      return this.generalRules
        .filter(g => GENERAL_KEYS[g.type])
        .map(g =>
          this.t(`GENERAL.${GENERAL_KEYS[g.type]}`, {
            level: this.levelLabel(g.level),
            value: g.value || '',
          })
        );
    },
    levelHelp() {
      return ['free_busy', 'details', 'schedule'].map(level => ({
        level,
        label: this.levelLabel(level),
        help: this.t(`LEVEL_HELP.${LEVEL_KEYS[level]}`),
      }));
    },
    canAdd() {
      return !!this.newEmail.trim() && !this.adding;
    },
  },
  watch: {
    show(value) {
      if (value) this.load();
    },
  },
  methods: {
    t(key, params) {
      return this.$t(`GOOGLE_CALENDAR.SHARE_CALENDAR.${key}`, params);
    },
    levelLabel(level) {
      return this.t(`LEVELS.${LEVEL_KEYS[level] || 'NONE'}`);
    },
    errorText(reason) {
      if (ERROR_KEYS[reason]) return this.t(`ERRORS.${ERROR_KEYS[reason]}`);
      return reason || this.t('LOAD_ERROR');
    },
    rowFeedback(key) {
      const state = this.rowState[key] || '';
      return {
        saving: state === 'saving',
        saved: state === 'saved',
        error: state && !['saving', 'saved'].includes(state) ? state : '',
      };
    },
    setRowState(key, state) {
      this.rowState = { ...this.rowState, [key]: state };
    },
    async load() {
      this.loading = true;
      this.loadError = '';
      this.rowState = {};
      this.addError = '';
      this.newEmail = '';
      try {
        const { data } = await GoogleCalendarAPI.getSharingRules();
        this.rules = data.sharing_rules || [];
        this.others = data.others || [];
        this.generalRules = data.general_rules || [];
      } catch (error) {
        const reason = error?.response?.data?.error;
        this.rules = [];
        this.others = [];
        this.loadError =
          reason === 'reconnect' ? this.t('RECONNECT') : this.t('LOAD_ERROR');
      } finally {
        this.loading = false;
      }
    },
    async changeCoworker(agentId, level) {
      const key = `agent:${agentId}`;
      const previous = this.rules.find(r => r.agent_id === agentId);
      this.setRowState(key, 'saving');
      try {
        const { data } = await GoogleCalendarAPI.updateSharingRule(
          agentId,
          level
        );
        this.rules = this.rules.map(r => (r.agent_id === agentId ? data : r));
        this.setRowState(key, 'saved');
      } catch (error) {
        // Se queda como estaba y se muestra el motivo (p. ej. Workspace no deja compartir).
        this.rules = this.rules.map(r =>
          r.agent_id === agentId ? { ...previous } : r
        );
        this.setRowState(key, this.errorText(error?.response?.data?.error));
      }
    },
    async changeOther(email, level) {
      const key = `email:${email}`;
      const previous = this.others.find(o => o.email === email);
      this.setRowState(key, 'saving');
      try {
        const { data } = await GoogleCalendarAPI.shareCalendarWithEmail(
          email,
          level
        );
        this.others =
          level === 'none'
            ? this.others.filter(o => o.email !== email)
            : this.others.map(o => (o.email === email ? data : o));
        this.setRowState(key, 'saved');
      } catch (error) {
        this.others = this.others.map(o =>
          o.email === email ? { ...previous } : o
        );
        this.setRowState(key, this.errorText(error?.response?.data?.error));
      }
    },
    async addEmail() {
      const email = this.newEmail.trim().toLowerCase();
      if (!email) return;
      this.adding = true;
      this.addError = '';
      try {
        const { data } = await GoogleCalendarAPI.shareCalendarWithEmail(
          email,
          this.newLevel
        );
        this.others = [
          ...this.others.filter(o => o.email !== data.email),
          data,
        ].sort((a, b) => a.email.localeCompare(b.email));
        this.setRowState(`email:${data.email}`, 'saved');
        this.newEmail = '';
      } catch (error) {
        this.addError = this.errorText(error?.response?.data?.error);
      } finally {
        this.adding = false;
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
    <div class="flex flex-col h-auto">
      <woot-modal-header
        :header-title="t('TITLE')"
        :header-content="t('DESCRIPTION')"
      />
      <form
        class="flex flex-col items-start w-full gap-3"
        @submit.prevent="addEmail"
      >
        <p v-if="loading" class="text-sm text-slate-500 dark:text-slate-400">
          {{ t('LOADING') }}
        </p>
        <p
          v-else-if="loadError"
          class="text-sm text-ruby-600 dark:text-ruby-400"
        >
          {{ loadError }}
        </p>
        <template v-else>
          <woot-tabs
            class="w-full"
            :index="tab"
            :border="false"
            @change="i => (tab = i)"
          >
            <woot-tabs-item
              v-for="(item, i) in tabs"
              :key="item.key"
              :index="i"
              :name="item.label"
              :count="item.count"
              show-badge
            />
          </woot-tabs>

          <!-- Compañeros de la cuenta -->
          <div
            v-show="tab === 0"
            class="w-full max-h-72 overflow-y-auto divide-y divide-slate-100 dark:divide-slate-700"
          >
            <p
              v-if="!coworkerRows.length"
              class="py-3 text-sm text-slate-500 dark:text-slate-400"
            >
              {{ t('EMPTY') }}
            </p>
            <div
              v-for="row in coworkerRows"
              :key="row.key"
              class="flex items-center gap-3 py-2"
            >
              <Thumbnail
                :src="row.thumbnail"
                :username="row.name"
                size="28px"
              />
              <div class="flex-1 min-w-0">
                <p
                  class="m-0 text-sm text-slate-800 dark:text-slate-100 truncate"
                >
                  {{ row.name }}
                </p>
                <p
                  v-if="row.error"
                  class="m-0 text-xs text-ruby-600 dark:text-ruby-400"
                >
                  {{ row.error }}
                </p>
              </div>
              <span v-if="row.saving" class="text-xs text-slate-400">{{
                t('SAVING')
              }}</span>
              <fluent-icon
                v-else-if="row.saved"
                icon="checkmark"
                size="14"
                class="text-green-500 flex-shrink-0"
              />
              <select
                v-if="row.editable"
                :value="row.level"
                :disabled="row.saving"
                class="!w-60 !mb-0 flex-shrink-0"
                @change="changeCoworker(row.agentId, $event.target.value)"
              >
                <option
                  v-for="option in levelOptions"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
              <span
                v-else
                class="w-60 text-xs text-right text-slate-400 dark:text-slate-500 flex-shrink-0"
              >
                {{ row.statusLabel }}
              </span>
            </div>
          </div>

          <!-- Otras personas (no son agentes de la cuenta) -->
          <div v-show="tab === 1" class="w-full space-y-3">
            <div class="flex items-end w-full gap-2">
              <label class="flex-1 min-w-0 !mb-0" :class="{ error: addError }">
                {{ t('ADD.LABEL') }}
                <input
                  v-model="newEmail"
                  type="email"
                  class="!mb-0"
                  :placeholder="t('ADD.PLACEHOLDER')"
                  @input="addError = ''"
                />
              </label>
              <select v-model="newLevel" class="!w-52 !mb-0 flex-shrink-0">
                <option
                  v-for="option in addLevelOptions"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
              <WootSubmitButton
                :disabled="!canAdd"
                :loading="adding"
                :button-text="t('ADD.BUTTON')"
              />
            </div>
            <p
              v-if="addError"
              class="m-0 text-xs text-ruby-600 dark:text-ruby-400"
            >
              {{ addError }}
            </p>
            <p v-else class="m-0 text-xs text-slate-500 dark:text-slate-400">
              {{ t('ADD.HINT') }}
            </p>

            <div
              class="max-h-56 overflow-y-auto divide-y divide-slate-100 dark:divide-slate-700"
            >
              <p
                v-if="!otherRows.length"
                class="py-3 text-sm text-slate-500 dark:text-slate-400"
              >
                {{ t('OTHERS_EMPTY') }}
              </p>
              <div
                v-for="row in otherRows"
                :key="row.key"
                class="flex items-center gap-3 py-2"
              >
                <Thumbnail :username="row.email" size="28px" />
                <div class="flex-1 min-w-0">
                  <p
                    class="m-0 text-sm text-slate-800 dark:text-slate-100 truncate"
                  >
                    {{ row.email }}
                  </p>
                  <p
                    v-if="row.error"
                    class="m-0 text-xs text-ruby-600 dark:text-ruby-400"
                  >
                    {{ row.error }}
                  </p>
                </div>
                <span v-if="row.saving" class="text-xs text-slate-400">{{
                  t('SAVING')
                }}</span>
                <fluent-icon
                  v-else-if="row.saved"
                  icon="checkmark"
                  size="14"
                  class="text-green-500 flex-shrink-0"
                />
                <template v-if="row.editable">
                  <select
                    :value="row.level"
                    :disabled="row.saving"
                    class="!w-52 !mb-0 flex-shrink-0"
                    @change="changeOther(row.email, $event.target.value)"
                  >
                    <option
                      v-for="option in addLevelOptions"
                      :key="option.value"
                      :value="option.value"
                    >
                      {{ option.label }}
                    </option>
                  </select>
                  <woot-button
                    v-tooltip="t('REMOVE')"
                    type="button"
                    variant="clear"
                    color-scheme="secondary"
                    size="small"
                    icon="dismiss"
                    :disabled="row.saving"
                    @click="changeOther(row.email, 'none')"
                  />
                </template>
                <span
                  v-else
                  class="text-xs text-slate-400 dark:text-slate-500 flex-shrink-0"
                >
                  {{ row.statusLabel }}
                </span>
              </div>
            </div>
          </div>

          <!-- Qué significa cada nivel + reglas generales que vienen de Google -->
          <div
            class="w-full p-3 space-y-1 rounded-md bg-slate-50 dark:bg-slate-800"
          >
            <p
              v-for="item in levelHelp"
              :key="item.level"
              class="m-0 text-xs text-slate-600 dark:text-slate-300"
            >
              <strong>{{ item.label }}:</strong> {{ item.help }}
            </p>
            <p
              v-for="note in generalNotes"
              :key="note"
              class="m-0 pt-1 text-xs text-amber-700 dark:text-amber-300"
            >
              {{ note }}
            </p>
          </div>
        </template>

        <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
          <button type="button" class="button clear" @click="onClose">
            {{ t('CLOSE') }}
          </button>
        </div>
      </form>
    </div>
  </woot-modal>
</template>
