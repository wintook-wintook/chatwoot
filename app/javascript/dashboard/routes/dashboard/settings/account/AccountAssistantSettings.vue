<!--
  Asistente (Dali) — Ajustes de la cuenta: el nombre del asistente. Cada cliente
  le pone el suyo; vacío = «Dali». Solo un administrador lo cambia.
-->
<script>
import { useAlert } from 'dashboard/composables';
import AssistantAPI from 'dashboard/api/platformAssistant';
import {
  assistantState,
  DEFAULT_ASSISTANT_NAME,
} from 'dashboard/helper/assistantState';

export default {
  name: 'AccountAssistantSettings',
  data() {
    return {
      name: '',
      saving: false,
      defaultName: DEFAULT_ASSISTANT_NAME,
      // D5a — modelos de OpenAI (solo llegan al administrador).
      models: null,
      model: '',
      analysisModel: '',
    };
  },
  async mounted() {
    try {
      const { data } = await AssistantAPI.show();
      this.name = data.name === DEFAULT_ASSISTANT_NAME ? '' : data.name;
      this.setModels(data.models);
    } catch (_e) {
      this.name = '';
    }
  },
  methods: {
    setModels(models) {
      this.models = models || null;
      this.model = (models && models.model) || '';
      this.analysisModel = (models && models.analysis_model) || '';
    },
    async save() {
      this.saving = true;
      try {
        const { data } = this.models
          ? await AssistantAPI.saveSettings({
              name: this.name,
              model: this.model,
              analysisModel: this.analysisModel,
            })
          : await AssistantAPI.rename(this.name);
        if (data.models) this.setModels(data.models);
        assistantState.name = data.name;
        this.name = data.name === DEFAULT_ASSISTANT_NAME ? '' : data.name;
        useAlert(this.$t('ASSISTANT.SETTINGS.SAVED'));
      } catch (e) {
        useAlert(e.response?.data?.error || this.$t('ASSISTANT.ERROR'));
      } finally {
        this.saving = false;
      }
    },
  },
};
</script>

<template>
  <div class="flex flex-row p-4 border-b border-slate-25 dark:border-slate-800">
    <div class="flex-grow-0 flex-shrink-0 flex-[25%] min-w-0 py-4 pr-6 pl-0">
      <h4 class="text-lg font-medium text-black-900 dark:text-slate-200">
        {{ $t('ASSISTANT.SETTINGS.TITLE') }}
      </h4>
      <p>{{ $t('ASSISTANT.SETTINGS.HINT') }}</p>
    </div>
    <form
      class="p-4 flex-grow-0 flex-shrink-0 flex-[50%] flex flex-col gap-2"
      @submit.prevent="save"
    >
      <label class="text-sm font-medium text-slate-800 dark:text-slate-100">
        {{ $t('ASSISTANT.SETTINGS.LABEL') }}
        <input
          v-model="name"
          type="text"
          maxlength="30"
          :placeholder="defaultName"
        />
      </label>
      <template v-if="models">
        <label class="text-sm font-medium text-slate-800 dark:text-slate-100">
          {{ $t('ASSISTANT.SETTINGS.MODEL') }}
          <select v-model="model">
            <option value="">
              {{
                $t('ASSISTANT.SETTINGS.MODEL_DEFAULT', {
                  model: models.default,
                })
              }}
            </option>
            <option v-for="m in models.available" :key="m" :value="m">
              {{ m }}
            </option>
          </select>
        </label>
        <label class="text-sm font-medium text-slate-800 dark:text-slate-100">
          {{ $t('ASSISTANT.SETTINGS.ANALYSIS_MODEL') }}
          <select v-model="analysisModel">
            <option value="">
              {{ $t('ASSISTANT.SETTINGS.ANALYSIS_MODEL_DEFAULT') }}
            </option>
            <option v-for="m in models.available" :key="m" :value="m">
              {{ m }}
            </option>
          </select>
        </label>
        <p class="m-0 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('ASSISTANT.SETTINGS.MODEL_HINT') }}
        </p>
      </template>
      <woot-button class="self-start" size="small" :is-loading="saving">
        {{ $t('ASSISTANT.SETTINGS.SAVE') }}
      </woot-button>
    </form>
  </div>
</template>
