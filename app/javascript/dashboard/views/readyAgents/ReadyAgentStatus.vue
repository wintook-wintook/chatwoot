<!--
  Agente listo en la conversación: «Atendida por Sofi» (o cómo terminó: calificado, descartado,
  pasado a una persona, era cliente) con Pausar / Reanudar. Lo que contestó el prospecto sale al
  pasar el mouse.
-->
<script>
import { useAlert } from 'dashboard/composables';
import ReadyAgentSessionsAPI from 'dashboard/api/readyAgentSessions';

const T = 'READY_AGENTS.SESSION';

export default {
  name: 'ReadyAgentStatus',
  props: {
    conversationId: { type: [Number, String], default: null },
  },
  data() {
    return { session: null, busy: false };
  },
  computed: {
    tooltip() {
      const s = this.session;
      if (!s) return '';
      const answers = Object.entries(s.answers || {}).map(
        ([q, a]) => `${q}: ${a}`
      );
      return [s.outcome, ...answers].filter(Boolean).join('\n');
    },
  },
  watch: {
    conversationId: { immediate: true, handler: 'load' },
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    async load() {
      this.session = null;
      if (!this.conversationId) return;
      try {
        const { data } = await ReadyAgentSessionsAPI.forConversation(
          this.conversationId
        );
        this.session = data.session;
      } catch (_e) {
        this.session = null;
      }
    },
    async change(action) {
      this.busy = true;
      try {
        const { data } = await ReadyAgentSessionsAPI[action](this.session.id);
        this.session = data.session;
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('FAILED'));
      } finally {
        this.busy = false;
      }
    },
  },
};
</script>

<template>
  <div
    v-if="session"
    v-tooltip.top="tooltip"
    class="flex items-center w-full min-w-0 gap-1.5 px-2 py-1 text-xs rounded-md bg-slate-50 dark:bg-slate-800"
  >
    <fluent-icon icon="bot" size="14" class="flex-shrink-0 text-woot-600" />
    <span class="min-w-0 truncate text-slate-600 dark:text-slate-300">
      <span class="font-medium text-slate-700 dark:text-slate-200">
        {{ session.agent.name }}
      </span>
      · {{ t(`STATUS.${session.status}`) }}
    </span>
    <div
      v-if="['active', 'paused'].includes(session.status)"
      class="flex flex-shrink-0 gap-2 ltr:ml-auto rtl:mr-auto"
    >
      <button
        v-if="session.status === 'active'"
        type="button"
        class="text-slate-600 hover:underline dark:text-slate-300"
        :disabled="busy"
        @click="change('pause')"
      >
        {{ t('PAUSE') }}
      </button>
      <button
        v-else
        type="button"
        class="text-woot-600 hover:underline"
        :disabled="busy"
        @click="change('resume')"
      >
        {{ t('RESUME') }}
      </button>
    </div>
  </div>
</template>
