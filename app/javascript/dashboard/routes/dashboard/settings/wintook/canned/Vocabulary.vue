<script setup>
import VocabularioIndex from './vocabulario/VocabularioIndex.vue';
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'dashboard/composables/useI18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';

const getters = useStoreGetters();
const currentUser = computed(() => getters.getCurrentUser.value);

const store = useStore();
const { t } = useI18n();

const dataVocabulary = ref({});
const metaVocabulary = ref({});

const currentPage = ref(1);
const searchQuery = ref('');

const fetchDataTable = async () => {
  const { access_token, account_id } = currentUser.value;

  const current_page = currentPage.value;
  const search_query = searchQuery.value;

  const urlBaseApi = process.env.WINTOOK_API;
  const urlApi = `${urlBaseApi}/v1/vocabulary`;
  const dataOptions = {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'access-token': access_token
    },
    body: JSON.stringify({ current_page, search_query })
  };
console.log(urlApi, dataOptions)
  try {
    const response = await fetch(urlApi, dataOptions);
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    const data = await response.json();
    dataVocabulary.value = data.data.map(item => {
        return {
          ...item,
          excluir: item.excluir ? 'Excluida':'Incluida',
          activar_clave: item.activar_clave ? 'Si':'No',
          activar_respuesta: item.activar_respuesta ? 'Si':'No',
          palabraClaveId: item.palabra_clave_id,
          palabraClave: item.palabra_clave,
          excluirPalabra: item.excluir,
          activarClave: item.activar_clave,
          activarRespuesta: item.activar_respuesta,
          palabraRespuesta: item.respuesta,
          apagarBot: item.apagar_bot
        };
    });
    metaVocabulary.value = data.meta;
    console.log(dataVocabulary.value)
  } catch (error) {
    console.error('Error occurred:', error.message || error);
    throw error;
  }
};

onMounted(() => {
  // fetchDataTable();
});

</script>

<template>
  <div class="mt-6 flex-1">
    <div class="grid grid-cols-1">
      <div class="w-full">
        <VocabularioIndex />
      </div>
    </div>
  </div>
</template>
