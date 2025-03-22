<script setup>
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import { computed, onMounted, ref } from 'vue';
import { useStoreGetters } from 'dashboard/composables/store';

import DataResourceForm from './DataResourceForm.vue';
import EmbeddingIndex from './EmbeddingIndex.vue';
const getters = useStoreGetters();
const currentUser = computed(() => getters.getCurrentUser.value);
const showDataResource = ref(false);
const dataResource = ref({});
const forumsType = ref({})
const hideDataResource = () => {
  showDataResource.value = false;
};

const fetchDataResource = async () => {
  const { access_token } = currentUser.value;
  const urlBaseApi = process.env.WINTOOK_OPENAI;
  const urlApi = `${urlBaseApi}/v1/responses/getForumsType`;
  try {
    const response = await fetch( urlApi , {
        method: 'GET',
        headers: {
          'access-token': access_token,
        },
      }
    );

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    forumsType.value = await response.json();
  } catch (error) {
    console.error('Error fetching forums type:', error.message);
  }
};

onMounted(() => {
  fetchDataResource();
});

const addDataResource = () => {
  const { account_id } = currentUser.value;
  dataResource.value = {
    id: 0,
    account_id: account_id,
    forum_type_id: 0,
    forum_account: '',
    forum_url: '',
  };
  showDataResource.value = true;
};
</script>

<template>
  <div class="flex-1 overflow-auto">
    <BaseSettingsHeader
      title="Entrenamiento ChatGPT"
      feature-name="canned_responses"
    >
      <template #actions>
        <woot-button
          class="button nice rounded-md"
          icon="add-circle"
          @click="addDataResource"
        >
          {{ 'Configurar Entrenamiento (Foros)' }}
        </woot-button>
      </template>
    </BaseSettingsHeader>
    <EmbeddingIndex />
    <woot-modal :show.sync="showDataResource" :on-close="hideDataResource">
      <DataResourceForm
        :on-close="hideDataResource"
        :data-resource="dataResource"
        :forums-type="forumsType"
      />
    </woot-modal>
  </div>
</template>
