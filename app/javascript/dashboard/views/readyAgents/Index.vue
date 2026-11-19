<!--
  Agentes listos: el catálogo de funciones (Atención a prospectos, Atención a clientes…). Cada
  función trae su asistente: la empresa contesta sus preguntas, le pone nombre, elige sus bandejas
  y lo prueba; desde ese momento atiende solo en esas bandejas (sin automatizaciones). Se pueden
  tener varios del mismo tipo. Todos usan el motor 2.0 y quedan en la lista de agentes
  (Plan-Motor-Agentes §11.14). Los que todavía no están salen como «Próximamente».
  ?edit=<id> abre ese agente (la lista de agentes lo manda aquí).
-->
<script>
import { useAlert } from 'dashboard/composables';
import ReadyAgentsAPI from 'dashboard/api/readyAgents';
import ReadyAgentModal from './ReadyAgentModal.vue';
import CustomersAgentModal from './CustomersAgentModal.vue';
import CampaignSellerModal from './CampaignSellerModal.vue';

const T = 'READY_AGENTS';
// Una bandeja puede tener un agente de cada uno de estos dos (TrackingTemplate::ATTENDING_PAIR).
const PAIR = ['prospects', 'customers'];

export default {
  name: 'ReadyAgentsIndex',
  components: { ReadyAgentModal, CustomersAgentModal, CampaignSellerModal },
  data() {
    return {
      catalog: [],
      agents: [],
      inboxes: [],
      calendarUsers: [],
      sources: [], // las fuentes de la cuenta y qué hay en cada una (paso «Qué sabe»)
      caseTypes: [], // «Atención a clientes»: los tipos de caso que puede levantar
      events: [], // «Vendedor de campaña» › Invitar: los eventos próximos
      loading: true,
      modal: null,
      queryHandled: false,
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
        this.sources = data.sources || [];
        this.caseTypes = data.case_types || [];
        this.events = data.events || [];
        this.openFromQuery();
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('LOAD_ERROR'));
      } finally {
        this.loading = false;
      }
    },
    agentsOf(kind) {
      return this.agents.filter(a => a.kind === kind);
    },
    // El Vendedor de campaña está «prendido» si alguna campaña lo usa (no atiende bandejas).
    isOn(agent) {
      return agent.kind === 'campaign_seller'
        ? agent.campaigns > 0
        : agent.enabled;
    },
    // El Vendedor de campaña no atiende bandejas: se dice en cuántas campañas está.
    whereLine(agent) {
      if (agent.kind === 'campaign_seller')
        return agent.campaigns
          ? this.t('CAMPAIGN.IN_CAMPAIGNS', { n: agent.campaigns })
          : this.t('CAMPAIGN.NO_CAMPAIGNS');
      return this.inboxNames(agent) || this.t('NO_INBOXES');
    },
    inboxNames(agent) {
      return this.inboxes
        .filter(i => agent.inbox_ids.includes(i.id))
        .map(i => i.name)
        .join(', ');
    },
    // Las bandejas que ya atiende otro agente; con el par (prospectos + clientes) se comparten.
    takenFor(agent, kind) {
      const partner = PAIR.includes(kind) ? PAIR.find(k => k !== kind) : null;
      return this.agents
        .filter(a => a.enabled && (!agent || a.id !== agent.id))
        .filter(a => !partner || a.kind !== partner)
        .flatMap(a => a.inbox_ids);
    },
    // Solo la primera vez: después de guardar se recarga y no se vuelve a abrir.
    openFromQuery() {
      if (this.queryHandled) return;
      this.queryHandled = true;
      const id = Number(this.$route.query.edit);
      const agent = id && this.agents.find(a => a.id === id);
      const entry = agent && this.catalog.find(e => e.kind === agent.kind);
      if (entry) this.open(entry, agent);
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
              :class="isOn(agent) ? 'bg-green-500' : 'bg-slate-300'"
              :title="isOn(agent) ? t('ON') : t('OFF')"
            />
            <div class="flex-1 min-w-0">
              <p
                class="m-0 text-sm font-medium truncate text-slate-800 dark:text-slate-100"
              >
                {{ agent.name }}
              </p>
              <p class="m-0 text-xs truncate text-slate-500">
                {{ whereLine(agent) }}
                <template v-if="agent.live_sessions">
                  · {{ t('LIVE', { n: agent.live_sessions }) }}
                </template>
                <template v-if="finishedLine(agent)">
                  · {{ finishedLine(agent) }}
                </template>
              </p>
            </div>
            <woot-button
              v-if="agent.kind !== 'campaign_seller'"
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
    <CampaignSellerModal
      v-if="modal && modal.entry.kind === 'campaign_seller'"
      show
      :title="modal.entry.title"
      :agent="modal.agent"
      :calendar-users="calendarUsers"
      :sources="sources"
      :events="events"
      @close="modal = null"
      @saved="onSaved"
    />
    <CustomersAgentModal
      v-else-if="modal && modal.entry.kind === 'customers'"
      show
      :title="modal.entry.title"
      :agent="modal.agent"
      :inboxes="inboxes"
      :taken-inbox-ids="takenFor(modal.agent, 'customers')"
      :calendar-users="calendarUsers"
      :sources="sources"
      :case-types="caseTypes"
      @close="modal = null"
      @saved="onSaved"
    />
    <ReadyAgentModal
      v-else-if="modal"
      show
      :kind="modal.entry.kind"
      :title="modal.entry.title"
      :agent="modal.agent"
      :inboxes="inboxes"
      :taken-inbox-ids="takenFor(modal.agent, modal.entry.kind)"
      :calendar-users="calendarUsers"
      :sources="sources"
      @close="modal = null"
      @saved="onSaved"
    />
  </div>
</template>
