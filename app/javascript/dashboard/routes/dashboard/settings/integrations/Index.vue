<script setup>
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { computed, onMounted } from 'vue';
import IntegrationItem from './IntegrationItem.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

const store = useStore();
const getters = useStoreGetters();

const uiFlags = getters['integrations/getUIFlags'];

// proyecto@commands_agents: Bot Comando no se muestra en la lista de integraciones.
const HIDDEN_INTEGRATIONS = ['command_bot'];

// Orden fijo de las integraciones en la lista. Las que no estén aquí se
// muestran al final, conservando el orden que devuelve el backend.
const INTEGRATION_ORDER = [
  'bots_inboxes',
  'tracking_bot',
  'daiko',
  'crmzeus',
  'discourse',
  'webhook',
  'openai',
  'dashboard_apps',
  'dialogflow',
  'google_translate',
];

const orderIndex = id => {
  const index = INTEGRATION_ORDER.indexOf(id);
  return index === -1 ? INTEGRATION_ORDER.length : index;
};

const integrationList = computed(() =>
  getters['integrations/getAppIntegrations'].value
    .filter(item => !HIDDEN_INTEGRATIONS.includes(item.id))
    .slice()
    .sort((a, b) => orderIndex(a.id) - orderIndex(b.id))
);

onMounted(() => {
  store.dispatch('integrations/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('INTEGRATION_SETTINGS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('INTEGRATION_SETTINGS.HEADER')"
        :description="$t('INTEGRATION_SETTINGS.DESCRIPTION')"
        :link-text="$t('INTEGRATION_SETTINGS.LEARN_MORE')"
        feature-name="integrations"
      />
    </template>
    <template #body>
      <div class="flex-grow flex-shrink overflow-auto">
        <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          <IntegrationItem
            v-for="item in integrationList"
            :id="item.id"
            :key="item.id"
            :logo="item.logo"
            :name="item.name"
            :description="item.description"
            :enabled="item.enabled"
          />
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
