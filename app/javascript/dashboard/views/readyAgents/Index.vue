<!--
  Agentes listos: los puestos que armamos nosotros (el cerebro es el del Seguimiento IA). La
  empresa activa uno, le pone nombre, elige sus bandejas, contesta sus preguntas y lo prueba;
  desde ese momento atiende solo en esas bandejas (sin automatizaciones). Los que todavía no
  están salen como «Próximamente». Los agentes a la medida siguen en «Agentes a medida».
-->
<script>
import { useAlert } from 'dashboard/composables';
import ReadyAgentsAPI from 'dashboard/api/readyAgents';
import ReadyAgentModal from './ReadyAgentModal.vue';

const T = 'READY_AGENTS';

export default {
  name: 'ReadyAgentsIndex',
  components: { ReadyAgentModal },
  data() {
    return {
      catalog: [],
      agents: [],
      inboxes: [],
      calendarUsers: [],
      loading: true,
      modal: null,
    };
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
        const { data } = await ReadyAgentsAPI.get();
        this.catalog = data.catalog;
        this.agents = data.agents;
        this.inboxes = data.inboxes;
        this.calendarUsers = data.calendar_users || [];
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('LOAD_ERROR'));
      } finally {
        this.loading = false;
      }
    },
    agentsOf(kind) {
      return this.agents.filter(a => a.kind === kind);
    },
    inboxNames(agent) {
      return this.inboxes
        .filter(i => agent.inbox_ids.includes(i.id))
        .map(i => i.name)
        .join(', ');
    },
    takenFor(agent) {
      return this.agents
        .filter(a => a.enabled && (!agent || a.id !== agent.id))
        .flatMap(a => a.inbox_ids);
    },
    open(entry, agent = null) {
      this.modal = { entry, agent };
    },
    onSaved() {
      this.modal = null;
      useAlert(this.t('SAVED'));
      this.load();
    },
    async toggle(agent) {
      try {
        await ReadyAgentsAPI.update(agent.id, {
          ready_agent: { enabled: !agent.enabled },
        });
        this.load();
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('SAVE_ERROR'));
      }
    },
    async remove(agent) {
      // eslint-disable-next-line no-alert
      if (!window.confirm(this.t('DELETE_CONFIRM', { name: agent.name })))
        return;
      await ReadyAgentsAPI.delete(agent.id);
      this.load();
    },
    finishedLine(agent) {
      const f = agent.finished || {};
      return Object.keys(f)
        .map(k => `${this.t(`SESSION.STATUS.${k}`)} ${f[k]}`)
        .join(' · ');
    },
  },
};
</script>

<template>
  <div class="flex flex-col w-full h-full p-6 overflow-y-auto">
    <header class="mb-5">
      <h1 class="m-0 text-xl font-semibold text-slate-900 dark:text-slate-25">
        {{ t('TITLE') }}
      </h1>
      <p class="m-0 mt-1 text-sm text-slate-500 dark:text-slate-400">
        {{ t('SUBTITLE') }}
      </p>
    </header>
    <p v-if="loading" class="text-sm text-slate-500">{{ t('LOADING') }}</p>
    <div v-else class="grid gap-4 md:grid-cols-2">
      <section
        v-for="entry in catalog"
        :key="entry.kind"
        class="flex flex-col gap-3 p-4 border rounded-xl border-slate-100 dark:border-slate-700"
        :class="
          entry.available
            ? 'bg-white dark:bg-slate-900'
            : 'bg-slate-25 dark:bg-slate-800/50 opacity-70'
        "
      >
        <div class="flex items-start justify-between gap-3">
          <div>
            <h2
              class="m-0 text-base font-semibold text-slate-800 dark:text-slate-100"
            >
              {{ entry.title }}
            </h2>
            <p class="m-0 mt-1 text-sm text-slate-600 dark:text-slate-300">
              {{ entry.summary }}
            </p>
          </div>
          <span
            v-if="!entry.available"
            class="flex-shrink-0 px-2 py-0.5 text-xs rounded-full bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
          >
            {{ t('SOON') }}
          </span>
        </div>
        <template v-if="entry.available">
          <div
            v-for="agent in agentsOf(entry.kind)"
            :key="agent.id"
            class="flex items-center gap-3 px-3 py-2 rounded-lg bg-slate-50 dark:bg-slate-800"
          >
            <span
              class="w-2 h-2 rounded-full flex-shrink-0"
              :class="agent.enabled ? 'bg-green-500' : 'bg-slate-300'"
              :title="agent.enabled ? t('ON') : t('OFF')"
            />
            <div class="flex-1 min-w-0">
              <p
                class="m-0 text-sm font-medium truncate text-slate-800 dark:text-slate-100"
              >
                {{ agent.name }}
              </p>
              <p class="m-0 text-xs truncate text-slate-500">
                {{ inboxNames(agent) || t('NO_INBOXES') }}
                <template v-if="agent.live_sessions">
                  · {{ t('LIVE', { n: agent.live_sessions }) }}
                </template>
                <template v-if="finishedLine(agent)">
                  · {{ finishedLine(agent) }}
                </template>
              </p>
            </div>
            <woot-button
              size="tiny"
              variant="clear"
              color-scheme="secondary"
              @click="toggle(agent)"
            >
              {{ agent.enabled ? t('TURN_OFF') : t('TURN_ON') }}
            </woot-button>
            <woot-button
              size="tiny"
              variant="smooth"
              color-scheme="secondary"
              icon="edit"
              @click="open(entry, agent)"
            />
            <woot-button
              size="tiny"
              variant="clear"
              color-scheme="alert"
              icon="delete"
              @click="remove(agent)"
            />
          </div>
          <div>
            <woot-button size="small" icon="add" @click="open(entry)">
              {{ t('ACTIVATE') }}
            </woot-button>
          </div>
        </template>
      </section>
    </div>
    <ReadyAgentModal
      v-if="modal"
      show
      :kind="modal.entry.kind"
      :title="modal.entry.title"
      :agent="modal.agent"
      :inboxes="inboxes"
      :taken-inbox-ids="takenFor(modal.agent)"
      :calendar-users="calendarUsers"
      @close="modal = null"
      @saved="onSaved"
    />
  </div>
</template>
