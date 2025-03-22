<script setup>
import SinonimosIndex from './sinonimos/SinonimosIndex.vue'
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';

const getters = useStoreGetters();
const currentUser = computed(() => getters.getCurrentUser.value);

const store = useStore();
const { t } = useI18n();

const dataEmbedding = ref({});
const metaEmbedding = ref({});

const currentPage = ref(1);
const searchQuery = ref('');

const fetchDataTable = async () => {
  const { access_token, account_id } = currentUser.value;

  const current_page = currentPage.value;
  const search_query = searchQuery.value;

  const urlBaseApi = process.env.WINTOOK_OPENAI;
  const urlApi = `${urlBaseApi}/v1/responses/getEmbedding`;
  const options = {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'access-token': access_token
    },
    body: JSON.stringify(
      {
        account_id, 
        current_page, 
        searchQuery: search_query, 
        searchTrained: 0, 
        perPages: 10, 
        trainedFilter: 0, 
        origenFilter: 0
      })
  };

  try {
    const response = await fetch(urlApi, options);
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    dataEmbedding.value
    const data = await response.json();
    dataEmbedding.value = data.data;
    metaEmbedding.value = data.meta;
    console.log(dataEmbedding.value)
  } catch (error) {
    console.error('Error occurred:', error.message || error);
    throw error;
  }
};

onMounted(() => {
  fetchDataTable();
});

</script>

<template>
  <div class="mt-6 flex-1">
    <div class="grid grid-cols-1">
      <div class="w-full">
        <SinonimosIndex />
      </div>
    </div>
  </div>
</template>
