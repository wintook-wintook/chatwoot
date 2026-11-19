<!--
  Asistente (Dali) — Ajustes de la cuenta: el nombre del asistente. Cada cliente
  le pone el suyo; vacío = «Dali». Solo un administrador lo cambia.
  Abajo, solo para informar, qué modelo de OpenAI usa cada grupo de la plataforma (AiModels): los
  define el código para todas las cuentas y se cambian con una actualización, ya no aquí.
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
      // Qué modelo usa cada grupo (solo llega al administrador; solo informativo).
      groups: [],
    };
  },
  async mounted() {
    try {
      const { data } = await AssistantAPI.show();
      this.name = data.name === DEFAULT_ASSISTANT_NAME ? '' : data.name;
      this.groups = (data.models && data.models.groups) || [];
    } catch (_e) {
      this.name = '';
    }
  },
  methods: {
    async save() {
      this.saving = true;
      try {
        const { data } = await AssistantAPI.rename(this.name);
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
      <woot-button class="self-start" size="small" :is-loading="saving">
        {{ $t('ASSISTANT.SETTINGS.SAVE') }}
      </woot-button>
      <!-- Solo informativo: los modelos los define el código para todas las cuentas. -->
      <div v-if="groups.length" class="mt-4">
        <h5 class="m-0 text-sm font-medium text-slate-800 dark:text-slate-100">
          {{ $t('ASSISTANT.SETTINGS.MODELS.TITLE') }}
        </h5>
        <p class="m-0 mb-2 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('ASSISTANT.SETTINGS.MODELS.HINT') }}
        </p>
        <table class="w-full text-sm">
          <thead>
            <tr class="text-xs text-left text-slate-500">
              <th class="py-1 pr-3 font-medium">
                {{ $t('ASSISTANT.SETTINGS.MODELS.GROUP') }}
              </th>
              <th class="py-1 pr-3 font-medium">
                {{ $t('ASSISTANT.SETTINGS.MODELS.USED_FOR') }}
              </th>
              <th class="py-1 font-medium">
                {{ $t('ASSISTANT.SETTINGS.MODELS.MODEL') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="g in groups"
              :key="g.key"
              class="border-t border-slate-100 dark:border-slate-700"
            >
              <td
                class="py-1.5 pr-3 font-medium text-slate-800 dark:text-slate-100"
              >
                {{ $t(`ASSISTANT.SETTINGS.MODELS.GROUPS.${g.key}.NAME`) }}
              </td>
              <td
                class="py-1.5 pr-3 text-xs text-slate-600 dark:text-slate-300"
              >
                {{ $t(`ASSISTANT.SETTINGS.MODELS.GROUPS.${g.key}.USE`) }}
              </td>
              <td class="py-1.5 font-mono text-xs whitespace-nowrap">
                {{ g.model || $t('ASSISTANT.SETTINGS.MODELS.PER_INBOX') }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </form>
  </div>
</template>
