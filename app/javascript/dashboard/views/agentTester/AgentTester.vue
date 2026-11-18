<script>
// Probador de agentes (Agentes IA › Probador). Fuera del diseño de los agentes: aquí cualquiera
// que pueda cambiar agentes los prueba como cliente, con el motor real (1.0 o 2.0) en el canal de
// pruebas, y el entrenador le dice si el error es del prompt, del contenido, del modelo o del
// motor. Lotes de pruebas y bitácora. Plan-Motor-Agentes.md §11.13.
//
// Quien prueba solo dice qué debió responder (👎) o que estuvo bien (👍); el diagnóstico lo ve
// quien entrena en «Revisión», plática por plática y mensaje por mensaje.
import AgentTesterAPI from 'dashboard/api/agentTester';
import AgentTestBatchesApi from 'dashboard/api/agentTestBatches';
import TesterChat from './TesterChat.vue';
import TesterBatches from './TesterBatches.vue';
import TesterLog from './TesterLog.vue';
import TesterReview from './TesterReview.vue';

export default {
  components: { TesterChat, TesterBatches, TesterLog, TesterReview },
  data() {
    return {
      tab: 'chat',
      agents: [],
      batches: [],
      canEdit: false,
      resume: null,
      // 👎 por revisar (el contador de la pestaña).
      openReviews: 0,
    };
  },
  computed: {
    // Lotes: para quien puede cambiar agentes. La Bitácora la ven todos (cada quien sus 👎).
    tabs() {
      return this.canEdit
        ? ['chat', 'review', 'batches', 'log']
        : ['chat', 'log'];
    },
  },
  mounted() {
    this.loadAgents();
  },
  methods: {
    t(key, args) {
      return this.$t(`AGENT_TESTER.${key}`, args);
    },
    async loadAgents() {
      const { data } = await AgentTesterAPI.agents();
      this.agents = data.agents;
      this.canEdit = data.can_edit;
      if (this.canEdit) {
        this.loadBatches();
        this.loadReviewCount();
      }
    },
    async loadReviewCount() {
      try {
        const { data } = await AgentTesterAPI.review({ status: 'open' });
        this.openReviews = (data.agents || []).reduce((n, a) => n + a.open, 0);
      } catch (e) {
        this.openReviews = 0;
      }
    },
    onSaved() {
      this.loadBatches();
      if (this.canEdit) this.loadReviewCount();
    },
    tabLabel(key) {
      const label = this.t(`TABS.${key}`);
      return key === 'review' && this.openReviews
        ? `${label} (${this.openReviews})`
        : label;
    },
    async loadBatches() {
      const { data } = await AgentTestBatchesApi.get();
      this.batches = data;
    },
    // «Seguir la plática» desde la bitácora.
    resumeChat(conversationId) {
      this.resume = conversationId;
      this.tab = 'chat';
    },
  },
};
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 p-4 overflow-y-auto md:p-6">
    <header class="mb-4">
      <h1 class="m-0 text-xl font-semibold text-slate-900 dark:text-slate-25">
        {{ t('TITLE') }}
      </h1>
      <p class="m-0 mt-1 text-sm text-slate-500">{{ t('SUBTITLE') }}</p>
    </header>
    <nav
      class="flex gap-1 mb-4 border-b border-slate-100 dark:border-slate-700"
    >
      <button
        v-for="key in tabs"
        :key="key"
        type="button"
        class="px-3 py-2 -mb-px text-sm bg-transparent rounded-none !border-x-0 !border-t-0 border-b-2"
        :class="
          tab === key
            ? 'border-woot-500 text-woot-600 font-medium'
            : 'border-transparent text-slate-500'
        "
        @click="tab = key"
      >
        {{ tabLabel(key) }}
      </button>
    </nav>
    <TesterChat
      v-if="tab === 'chat'"
      :agents="agents"
      :can-edit="canEdit"
      :resume="resume"
      @saved="onSaved"
      @resumed="resume = null"
    />
    <TesterReview
      v-else-if="tab === 'review'"
      :agents="agents"
      @changed="loadReviewCount"
    />
    <TesterBatches
      v-else-if="tab === 'batches'"
      :agents="agents"
      :batches="batches"
      @changed="loadBatches"
    />
    <TesterLog v-else :can-edit="canEdit" @resume="resumeChat" />
  </div>
</template>
