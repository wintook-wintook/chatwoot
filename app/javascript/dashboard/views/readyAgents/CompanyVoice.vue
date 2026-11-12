<!--
  «Cómo habla tu empresa»: lo general que toman el Seguimiento IA y todos los Agentes listos
  (no los Agentes a medida, que son otro motor). Lo particular de cada agente o seguimiento
  manda sobre esto. «Probar» arma un mensaje de ejemplo con lo del formulario, sin guardar.
  Pestaña «Plantillas de seguimiento» (?tab=plantillas): el catálogo del Seguimiento IA.
-->
<script>
import { useAlert } from 'dashboard/composables';
import AiVoiceAPI from 'dashboard/api/aiVoice';
import FollowUpPresets from './FollowUpPresets.vue';

const T = 'AI_VOICE';
export const VOICE_FIELDS = [
  'who',
  'tone',
  'signature',
  'roles',
  'after_hours',
  'never',
  'words',
];
const LONG = ['roles', 'never', 'words'];

export default {
  name: 'CompanyVoice',
  components: { FollowUpPresets },
  data() {
    return {
      tab: this.$route?.query?.tab === 'plantillas' ? 'presets' : 'voice',
      voice: Object.fromEntries(VOICE_FIELDS.map(k => [k, ''])),
      loading: true,
      saving: false,
      testing: false,
      kind: 'follow_up',
      sample: '',
      sampleError: '',
    };
  },
  computed: {
    tabs() {
      return [
        { key: 'voice', label: this.t('TABS.VOICE') },
        { key: 'presets', label: this.t('TABS.PRESETS') },
      ];
    },
    fields() {
      return VOICE_FIELDS.map(key => ({ key, long: LONG.includes(key) }));
    },
  },
  mounted() {
    this.load();
  },
  methods: {
    t(key, params) {
      return this.$t(`${T}.${key}`, params);
    },
    setTab(tab) {
      this.tab = tab;
      const query = tab === 'presets' ? { tab: 'plantillas' } : {};
      this.$router.replace({ query }).catch(() => {});
    },
    async load() {
      try {
        const { data } = await AiVoiceAPI.get();
        this.voice = { ...this.voice, ...data.voice };
      } catch (e) {
        useAlert(this.t('LOAD_ERROR'));
      } finally {
        this.loading = false;
      }
    },
    async save() {
      this.saving = true;
      try {
        const { data } = await AiVoiceAPI.update(this.voice);
        this.voice = { ...this.voice, ...data.voice };
        useAlert(this.t('SAVED'));
      } catch (e) {
        useAlert(this.t('SAVE_ERROR'));
      } finally {
        this.saving = false;
      }
    },
    async test() {
      this.testing = true;
      this.sample = '';
      this.sampleError = '';
      try {
        const { data } = await AiVoiceAPI.preview(this.voice, this.kind);
        this.sample = data.message;
      } catch (e) {
        this.sampleError = e?.response?.data?.error || this.t('TEST_ERROR');
      } finally {
        this.testing = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-col w-full h-full p-6 overflow-y-auto">
    <header class="mb-5 max-w-3xl">
      <h1 class="m-0 text-xl font-semibold text-slate-900 dark:text-slate-25">
        {{ t('TITLE') }}
      </h1>
      <p class="m-0 mt-1 text-sm text-slate-500 dark:text-slate-400">
        {{ t('SUBTITLE') }}
      </p>
    </header>
    <nav
      class="flex gap-1 mb-5 border-b border-slate-100 dark:border-slate-700 max-w-5xl"
    >
      <button
        v-for="item in tabs"
        :key="item.key"
        type="button"
        class="px-3 py-2 -mb-px text-sm bg-transparent rounded-none !border-x-0 !border-t-0 border-b-2"
        :class="
          tab === item.key
            ? 'border-woot-500 text-woot-600 font-medium'
            : 'border-transparent text-slate-500 hover:text-slate-700 dark:hover:text-slate-200'
        "
        :data-test="`voice-tab-${item.key}`"
        @click="setTab(item.key)"
      >
        {{ item.label }}
      </button>
    </nav>
    <FollowUpPresets v-if="tab === 'presets'" />
    <p v-else-if="loading" class="text-sm text-slate-500">
      {{ t('LOADING') }}
    </p>
    <div v-else class="grid gap-6 lg:grid-cols-[3fr_2fr] max-w-5xl">
      <form class="flex flex-col gap-4" @submit.prevent="save">
        <label v-for="f in fields" :key="f.key" class="flex flex-col gap-1">
          <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
            {{ t(`FIELDS.${f.key.toUpperCase()}.LABEL`) }}
          </span>
          <textarea
            v-if="f.long"
            v-model="voice[f.key]"
            rows="3"
            maxlength="600"
            class="!mb-0 text-sm"
            :data-test="`voice-${f.key}`"
            :placeholder="t(`FIELDS.${f.key.toUpperCase()}.PLACEHOLDER`)"
          />
          <input
            v-else
            v-model="voice[f.key]"
            type="text"
            maxlength="600"
            class="!mb-0 text-sm"
            :data-test="`voice-${f.key}`"
            :placeholder="t(`FIELDS.${f.key.toUpperCase()}.PLACEHOLDER`)"
          />
        </label>
        <div>
          <woot-button
            type="submit"
            :is-loading="saving"
            data-test="voice-save"
          >
            {{ t('SAVE') }}
          </woot-button>
        </div>
      </form>

      <aside
        class="flex flex-col gap-3 p-4 border rounded-xl h-fit border-slate-100 dark:border-slate-700 bg-slate-25 dark:bg-slate-800/50"
      >
        <h2
          class="m-0 text-base font-semibold text-slate-800 dark:text-slate-100"
        >
          {{ t('TEST.TITLE') }}
        </h2>
        <p class="m-0 text-sm text-slate-500 dark:text-slate-400">
          {{ t('TEST.HINT') }}
        </p>
        <select v-model="kind" class="!mb-0 text-sm" data-test="voice-kind">
          <option value="follow_up">{{ t('TEST.FOLLOW_UP') }}</option>
          <option value="prospects">{{ t('TEST.PROSPECTS') }}</option>
        </select>
        <div>
          <woot-button
            variant="smooth"
            icon="play-circle"
            :is-loading="testing"
            data-test="voice-test"
            @click="test"
          >
            {{ t('TEST.BUTTON') }}
          </woot-button>
        </div>
        <p
          v-if="sample"
          class="m-0 p-3 text-sm whitespace-pre-line bg-white rounded-lg text-slate-800 dark:bg-slate-900 dark:text-slate-100"
          data-test="voice-sample"
        >
          {{ sample }}
        </p>
        <p v-if="sampleError" class="m-0 text-sm text-red-600">
          {{ sampleError }}
        </p>
        <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
          {{ t('USED_BY') }}
        </p>
      </aside>
    </div>
  </div>
</template>
