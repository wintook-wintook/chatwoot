<script>
// Motor 2.0 — la ficha de un agente 2.0 (plan §11.9): menú de secciones · la sección · el
// probador siempre a la vista. Comparte lista y tablas con Agentes a medida; la ficha 1.0 no
// se toca. Arriba, «¿Listo para atender?» (el del 1.0) con su botón para activarlo.
import { useAlert } from 'dashboard/composables';
import Motor2AgentsAPI from 'dashboard/api/motor2Agents';
import { emptyForm, fromAgent, toPayload, missingFields } from './agentForm';
import SectionAgent from './SectionAgent.vue';
import SectionKnows from './SectionKnows.vue';
import SectionSkills from './SectionSkills.vue';
import SectionRules from './SectionRules.vue';
import SectionVersions from './SectionVersions.vue';
import SectionTests from './SectionTests.vue';
import Trainer from './Trainer.vue';

const SECTIONS = [
  { id: 'agent', icon: 'person' },
  { id: 'knows', icon: 'library' },
  { id: 'skills', icon: 'flash-on' },
  { id: 'rules', icon: 'list' },
  { id: 'instructions', icon: 'chat-multiple' },
  { id: 'tests', icon: 'checkmark-circle' },
  { id: 'versions', icon: 'history' },
];

export default {
  components: {
    SectionAgent,
    SectionKnows,
    SectionSkills,
    SectionRules,
    SectionVersions,
    SectionTests,
    Trainer,
  },
  data() {
    return {
      form: emptyForm(),
      saved: JSON.stringify(emptyForm()),
      agent: null,
      options: {},
      readiness: [],
      section: this.$route.query.seccion || 'agent',
      sections: SECTIONS,
      loading: true,
      saving: false,
      activating: false,
      mobileTab: 'form',
      stamp: 0,
    };
  },
  computed: {
    templateId() {
      return this.agent ? this.agent.id : null;
    },
    dirty() {
      return JSON.stringify(this.form) !== this.saved;
    },
    missing() {
      return missingFields(this.form);
    },
    warnings() {
      return this.readiness.filter(item => item.status !== 'ok');
    },
    canActivate() {
      return (
        this.templateId &&
        this.form.channel.inboxId &&
        this.readiness.some(i => i.key === 'assignment' && i.status !== 'ok')
      );
    },
  },
  watch: {
    'form.channel.inboxId': function inboxChanged(id, before) {
      if (id !== before) this.loadOptions(id);
    },
  },
  async mounted() {
    const id = this.$route.params.templateId;
    try {
      if (id && id !== 'new') await this.load(Number(id));
      await this.loadOptions(this.form.channel.inboxId);
    } catch (e) {
      useAlert(e.response?.data?.error || this.t('LOAD_ERROR'));
    } finally {
      this.loading = false;
    }
  },
  methods: {
    t(key, args) {
      return this.$t(`MOTOR2.${key}`, args);
    },
    async load(id) {
      const { data } = await Motor2AgentsAPI.show(id);
      this.apply(data);
      this.loadReadiness();
    },
    apply(agent) {
      this.agent = agent;
      this.form = fromAgent(agent);
      this.saved = JSON.stringify(this.form);
      this.stamp += 1;
    },
    async loadOptions(inboxId) {
      const { data } = await Motor2AgentsAPI.options(inboxId);
      this.options = data;
    },
    async loadReadiness() {
      if (!this.templateId) return;
      const { data } = await Motor2AgentsAPI.readiness(this.templateId);
      this.readiness = data.items || [];
    },
    payload() {
      return toPayload(this.form);
    },
    async save() {
      if (this.missing.length) {
        useAlert(this.t(`MISSING.${this.missing[0]}`));
        this.section = 'agent';
        return;
      }
      this.saving = true;
      try {
        const { data } = this.templateId
          ? await Motor2AgentsAPI.update(this.templateId, {
              agent: this.payload(),
            })
          : await Motor2AgentsAPI.create({ agent: this.payload() });
        const isNew = !this.templateId;
        this.apply(data);
        this.loadReadiness();
        useAlert(this.t('SAVED'));
        if (isNew)
          this.$router.replace({
            name: 'motor2_agent',
            params: { templateId: String(data.id) },
          });
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('SAVE_ERROR'));
      } finally {
        this.saving = false;
      }
    },
    async activate() {
      this.activating = true;
      try {
        const { data } = await Motor2AgentsAPI.activate(this.templateId);
        this.readiness = data.items || [];
        useAlert(this.t('ACTIVATED'));
      } catch (e) {
        useAlert(e.response?.data?.error || this.t('SAVE_ERROR'));
      } finally {
        this.activating = false;
      }
    },
    // El entrenador cambió la ficha (ya guardada): se recarga sin perder el chat.
    applyFromTrainer(agent) {
      this.apply(agent);
      this.loadReadiness();
    },
    async reloadAttachments() {
      await this.load(this.templateId);
    },
    backToList() {
      this.$router.push({ name: 'contact_trackings_agents' });
    },
  },
};
</script>

<template>
  <div class="flex flex-col w-full h-full min-h-0 bg-white dark:bg-slate-900">
    <header
      class="flex flex-wrap items-center gap-3 px-4 py-3 border-b md:px-6 border-slate-100 dark:border-slate-800"
    >
      <woot-button
        variant="clear"
        size="small"
        icon="chevron-left"
        @click="backToList"
      />
      <h2 class="flex items-center min-w-0 gap-2 m-0 text-lg font-medium">
        <span class="truncate">{{ form.name || t('NEW_TITLE') }}</span>
        <span
          class="px-2 py-0.5 text-xs rounded-full bg-woot-50 text-woot-700 dark:bg-woot-800 dark:text-woot-50"
        >
          {{ t('BADGE') }}
        </span>
      </h2>
      <span class="flex-1" />
      <span v-if="dirty" class="text-xs text-amber-600">{{
        t('UNSAVED')
      }}</span>
      <woot-button
        size="small"
        :is-loading="saving"
        :disabled="!dirty && !!templateId"
        @click="save"
      >
        {{ templateId ? t('SAVE') : t('CREATE') }}
      </woot-button>
    </header>

    <div
      v-if="warnings.length"
      class="flex flex-wrap items-center gap-x-4 gap-y-1 px-4 py-2 text-xs md:px-6 bg-amber-50 text-amber-800 dark:bg-amber-900/30 dark:text-amber-100"
    >
      <span class="font-medium">{{ t('READINESS') }}</span>
      <span v-for="item in warnings" :key="item.key">{{
        t('WARN', { text: item.label })
      }}</span>
      <woot-button
        v-if="canActivate"
        size="tiny"
        :is-loading="activating"
        @click="activate"
      >
        {{ t('ACTIVATE') }}
      </woot-button>
    </div>

    <div class="flex gap-2 px-4 pt-2 md:hidden">
      <woot-button
        size="small"
        :variant="mobileTab === 'form' ? 'smooth' : 'clear'"
        @click="mobileTab = 'form'"
      >
        {{ t('TAB_FORM') }}
      </woot-button>
      <woot-button
        size="small"
        :variant="mobileTab === 'test' ? 'smooth' : 'clear'"
        @click="mobileTab = 'test'"
      >
        {{ t('TAB_TEST') }}
      </woot-button>
    </div>

    <p v-if="loading" class="p-6 text-sm text-slate-500">{{ t('LOADING') }}</p>
    <div
      v-else
      class="grid flex-1 min-h-0 grid-cols-1 gap-4 p-4 md:p-6 md:grid-cols-[190px_minmax(0,1fr)_minmax(320px,400px)]"
    >
      <nav
        class="flex flex-row gap-1 overflow-x-auto md:flex-col md:overflow-visible"
        :class="{ 'hidden md:flex': mobileTab === 'test' }"
      >
        <button
          v-for="s in sections"
          :key="s.id"
          type="button"
          class="flex items-center gap-2 px-3 py-2 text-sm text-left rounded-lg shrink-0"
          :class="
            section === s.id
              ? 'bg-woot-50 text-woot-700 font-medium dark:bg-woot-800 dark:text-woot-50'
              : 'text-slate-600 hover:bg-slate-50 dark:text-slate-300 dark:hover:bg-slate-800'
          "
          :data-section="s.id"
          @click="section = s.id"
        >
          <fluent-icon :icon="s.icon" size="16" class="shrink-0" />
          <span class="truncate">{{ t(`NAV.${s.id}`) }}</span>
        </button>
      </nav>

      <section
        class="min-h-0 overflow-y-auto motor2-form"
        :class="{ 'hidden md:block': mobileTab === 'test' }"
      >
        <SectionAgent
          v-if="section === 'agent'"
          v-model="form"
          :options="options"
        />
        <SectionKnows
          v-else-if="section === 'knows'"
          v-model="form"
          :options="options"
        />
        <SectionSkills
          v-else-if="section === 'skills'"
          v-model="form"
          :options="options"
          :template-id="templateId"
          :attachments="agent ? agent.attachments : []"
          @uploaded="reloadAttachments"
        />
        <SectionRules
          v-else-if="section === 'rules'"
          v-model="form"
          :options="options"
        />
        <div v-else-if="section === 'instructions'" class="space-y-2">
          <p class="m2-hint">{{ t('INSTRUCTIONS.HINT') }}</p>
          <textarea
            v-model="form.motor2.instructions"
            rows="16"
            :placeholder="t('INSTRUCTIONS.PLACEHOLDER')"
          />
          <p class="m2-hint">
            {{ t('INSTRUCTIONS.VOICE') }}
            <router-link :to="{ name: 'ai_voice' }" class="text-woot-600">
              {{ t('INSTRUCTIONS.VOICE_LINK') }}
            </router-link>
          </p>
        </div>
        <SectionTests
          v-else-if="section === 'tests'"
          :template-id="templateId"
          :payload="payload"
          :stamp="stamp"
        />
        <SectionVersions
          v-else
          :template-id="templateId"
          :stamp="stamp"
          @restored="applyFromTrainer"
        />
      </section>

      <div
        class="min-h-[480px] md:min-h-0"
        :class="{ 'hidden md:block': mobileTab === 'form' }"
      >
        <Trainer
          :template-id="templateId"
          :payload="payload"
          :dirty="dirty"
          @changed="applyFromTrainer"
          @go="section = $event"
        />
      </div>
    </div>
  </div>
</template>

<style lang="scss">
.motor2-form {
  .m2-label {
    @apply block mb-1 text-xs font-medium text-slate-600 dark:text-slate-300;
  }

  .m2-subtitle {
    @apply mb-1 text-sm font-medium text-slate-800 dark:text-slate-100;
  }

  .m2-hint {
    @apply mb-2 text-xs text-slate-500;
  }

  input[type='text'],
  input[type='number'] {
    @apply h-9 py-1 px-2 mb-0 text-sm;
  }

  select {
    @apply h-9 py-1 pl-2 pr-8 mb-0 text-sm;
  }

  textarea {
    @apply mb-0 text-sm;
  }
}
</style>
