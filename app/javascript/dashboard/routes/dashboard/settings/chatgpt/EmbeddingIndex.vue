<script>
import axios from 'axios';
import { mapGetters } from 'vuex';
import Integration from '../../../../routes/dashboard/settings/integrations/Integration.vue';
import EmbeddingTable from './EmbeddingTable';
import EmbeddingHeader from './EmbeddingHeader';
import TableFooter from 'dashboard/components/widgets/TableFooter.vue';
import Modal from '../../../../components/Modal.vue';
import WootSubmitButton from '../../../../components/buttons/FormSubmitButton.vue';
import { useAlert } from 'dashboard/composables';
const DEFAULT_PAGE = 1;

export default {
  components: {
    Integration,
    EmbeddingTable,
    EmbeddingHeader,
    TableFooter,
    Modal,
    WootSubmitButton,
  },
  data() {
    return {
      searchQueryEmbedding: '',
      searchTrainedEmbedding: 2,
      dataEmbedding: {},
      metaEmbedding: {},
      forumsAccounts: {},
      perPages: 10,
      trainedFilter: 2,
      origenFilter: 0,
      currentPage: 1,
      similarity: 0.85,
      showLoading: false,
      showPrompts: false,
      showOptions: false,
      dataSelectResponse: {},
      showLoadingForums: false,
    };
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
    }),
  },
  mounted() {
    this.getEmbedding(DEFAULT_PAGE);
    // this.getForumsAccounts();
  },
  methods: {
    setUpdate(data) {
      this.updateForumsAccounts(data);
      this.getEmbedding(DEFAULT_PAGE);
    },

    setDelete(forum_account_id) {
      this.deleteForumsAccounts(forum_account_id);
      this.getForumsAccounts();
      this.getEmbedding(DEFAULT_PAGE);
    },

    hidePrompts() {
      this.showPrompts = false;
    },
    hideOptions() {
      this.showOptions = false;
    },
    onSearchSubmitEmbedding() {
      if (this.searchQueryEmbedding) {
        this.getEmbedding(DEFAULT_PAGE);
      }
    },

    onInputSearchEmbedding(event) {
      const newQuery = event.target.value;
      const refetchAll = !!this.searchQueryEmbedding && newQuery === '';
      this.searchQueryEmbedding = newQuery;
      if (refetchAll) {
        this.getEmbedding(DEFAULT_PAGE);
      }
    },

    onPageChangeEmbedding(page) {
      console.log(page)
      this.getEmbedding(page);
    },

    onToggleUpdateEmbedding() {
      this.searchQueryEmbedding = '';
      this.getEmbedding(DEFAULT_PAGE);
    },

    async onToggleUpdateForo() {
      const { access_token, account_id } = this.currentUser;
      const data = {
        access_token,
        account_id,
      };
      const response = await axios
        .post(process.env.URL_WEBHOOK + '/api/updateForo', { data })
        .then(function (resp) {
          return resp.data;
        })
        .catch(function (error) {
          return error;
        });

      if (response.status === 200) {
        this.getEmbedding(DEFAULT_PAGE);
      }
      useAlert(response.message);
      return true;
    },

    async getForumsAccounts() {
      const { access_token, account_id } = this.currentUser;
      const { WINTOOK_OPENAI } = process.env;
      const data = {
        account_id,
      };
      this.showLoadingForums = true;
      try {
        const response = await fetch(`${WINTOOK_OPENAI}/v1/responses/getForumsAccounts`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'access-token': access_token,
          },
          body: JSON.stringify(data),
        });

        const responseData = await response.json();
        console.log(responseData)
        if (response.ok) {
          this.forumsAccounts = responseData;
        }
        return true;
      } catch (error) {
        console.error('Error en la solicitud:', error);
        useAlert('Ocurrió un error al actualizar el foro');
        return false;
      }
    },

    async updateForumsAccounts(data) {
      const { id: forum_account_id, forum_url } = data

      const { access_token, account_id } = this.currentUser;
      const { WINTOOK_OPENAI } = process.env;
      const dataBody = {
        account_id,
        forum_account_id,
        forum_url
      };
      console.log("dataBody", dataBody)
      try {
        const response = await fetch(`${WINTOOK_OPENAI}/v1/responses/updateForumsAccounts`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'access-token': access_token,
          },
          body: JSON.stringify(dataBody),
        });
        // const responseData = await response.json();
        // if (response.ok) {
        //   this.forumsAccounts = responseData;
        // }
        return true;
      } catch (error) {
        console.error('Error en la solicitud:', error);
        useAlert('Ocurrió un error al actualizar el foro');
        return false;
      }
    },

    async deleteForumsAccounts(forum_account_id) {
      const { access_token, account_id } = this.currentUser;
      const { WINTOOK_OPENAI } = process.env;
      const data = {
        account_id,
        forum_account_id
      };
      try {
        const response = await fetch(`${WINTOOK_OPENAI}/v1/responses/deleteForumsAccounts`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'access-token': access_token,
          },
          body: JSON.stringify(data),
        });
        if (response.ok) {
          useAlert('Se borro....');
        }
        return true;
      } catch (error) {
        console.error('Error en la solicitud:', error);
        useAlert('Ocurrió un error al actualizar el foro');
        return false;
      }
    },

    async setContentPrompts() {
      const { access_token } = this.currentUser;
      const data = this.dataSelectResponse;
      const urlBaseApi = process.env.WINTOOK_OPENAI;
      const urlApi = `${urlBaseApi}/v1/responses/setContentPrompts`;
      const response = await axios
        .post(
          urlApi,
          { data },
          {
            headers: {
              'Content-Type': 'application/json',
              'access-token': access_token,
            },
          }
        )
        .then(function (response) {
          return response;
        })
        .catch(function (error) {
          return error;
        });

      if (response.status === 200) {
        useAlert( response.data.message );
        this.getEmbedding(this.currentPage);
        this.showPrompts = false;
        return true;
      }
      const message = 'Ocurrió un error al actualizar <<ContentPrompts>>.';
      useAlert(message);
      this.showPrompts = false;
      return true;
    },

    async onToggleTrained(data) {
      const { access_token } = this.currentUser;
      const urlBaseApi = process.env.WINTOOK_OPENAI;
      const urlApi = `${urlBaseApi}/v1/responses/onToggleTrained`;
      const response = await axios
        .post(
          urlApi,
          { data },
          {
            headers: {
              'Content-Type': 'application/json',
              'access-token': access_token,
            },
          }
        )
        .then(function (response) {
          return response;
        })
        .catch(function (error) {
          return error;
        });

      if (response.status === 200) {
        useAlert(response.data.message);
        this.getEmbedding(this.currentPage);
        return true;
      }
      const message =
        'Este documento no es posible entrenar, tal vez contiene demasiadas imágenes.';
      useAlert(message);
      return true;
    },

    async onTogglePrompt(data) {
      this.showPrompts = true;
    },

    async onToggleUpdate(data) {
      const { access_token } = this.currentUser;
      const urlBaseApi = process.env.WINTOOK_OPENAI;
      const urlApi = `${urlBaseApi}/v1/responses/onToggleUpdate`;
      const response = await axios
        .post(
          urlApi,
          { data },
          {
            headers: {
              'Content-Type': 'application/json',
              'access-token': access_token,
            },
          }
        )
        .then(function (response) {
          return response;
        })
        .catch(function (error) {
          return error;
        });

      if (response.status === 200) {
        useAlert(response.data.message);
        this.getEmbedding(this.currentPage);
        return true;
      } else {
        useAlert(response.data.message);
        return false;
      }
      // const message =
      //   'Este documento no es posible entrenar, tal vez contiene demasiadas imágenes.';
      // useAlert(message);
      return true;
    },

    async onToggleOptions(data) {
      this.getForumsAccounts();
      this.showOptions = true;
    },

    async getEmbedding(current_page) {
      const { access_token, account_id } = this.currentUser;
      const searchQuery = this.searchQueryEmbedding;
      const searchTrained = this.searchTrainedEmbedding;
      const perPages = this.perPages;
      const trainedFilter = this.trainedFilter;
      const origenFilter = this.origenFilter;

      this.showLoading = true;
      try {
        const urlBaseApi = process.env.WINTOOK_OPENAI;
        const urlApi = `${urlBaseApi}/v1/responses/getEmbedding`;
        const response = await axios
          .post(
            urlApi,
            {
              account_id,
              current_page,
              searchQuery,
              searchTrained,
              perPages,
              trainedFilter,
              origenFilter,
            },
            {
              headers: {
                'Content-Type': 'application/json',
                'access-token': access_token,
              },
            }
          )
          .then(function (resp) {
            return resp;
          })
          .catch(function (error) {
            return error;
          });

        if (response.status === 200) {
          this.dataEmbedding = response.data.data;
          this.metaEmbedding = response.data.meta;
          this.currentPage = this.metaEmbedding.current_page;
          this.showLoading = false;
        } else {
          this.metaEmbedding = {};
          this.currentPage = 1;
          this.dataEmbedding = null;
          this.similarity = 0.0;
        }
      } catch (error) {
        console.error(
          'Error fetching getEmbedding:',
          error.response ? error.response.data : error.message
        );
      }

      // const options = {
      //   method: "GET",
      //   url: `https://devopenai.wintook.com/v1/responses/getEmbedding`,
      //   headers: {
      //     "access-token": access_token,
      //   },
      //   data: {
      //     account_id: 287,
      //   },
      // };

      // try {
      //   const response = await axios.request(options);
      //   if (response.status === 200) {
      //     // this.metaEmbedding = result.meta;
      //     // this.currentPage = this.metaEmbedding.current_page;
      //     this.dataEmbedding = response.data;
      //     this.showLoading = false;
      //     // this.similarity = result.data[0].similarity;
      //   } else {
      //     this.metaEmbedding = {};
      //     this.currentPage = 1;
      //     this.dataEmbedding = {};
      //     this.similarity = 0.0;
      //   }
      // } catch (error) {
      //   console.error(
      //     "Error fetching forums type:",
      //     error.response ? error.response.data : error.message
      //   );
      // }
    },

    async onTogglePages(event) {
      this.perPages = event.target.value;
      this.searchQueryEmbedding = '';
      this.getEmbedding(DEFAULT_PAGE);
    },

    async onToggleTrainedFilter(event) {
      this.trainedFilter = event.target.value;
      this.searchQueryEmbedding = '';
      this.getEmbedding(DEFAULT_PAGE);
    },

    async onToggleOrigenFilter(event) {
      this.origenFilter = event.target.value;
      this.searchQueryEmbedding = '';
      this.getEmbedding(DEFAULT_PAGE);
    },
  },
};
</script>

<template>
  <div>
    <div class="mt-2 flex-1">
      <div class="grid grid-cols-1 md:grid-cols-1 xl:grid-cols-1 gap-4">
        <div class="w-full">
          <EmbeddingHeader :search-query="searchQueryEmbedding" :search-trained="searchTrainedEmbedding"
            :on-input-search="onInputSearchEmbedding" :on-search-submit="onSearchSubmitEmbedding"
            :on-toggle-create="onToggleCreateEmbedding" :on-toggle-pages="onTogglePages"
            :on-toggle-trained-filter="onToggleTrainedFilter" :on-toggle-origen-filter="onToggleOrigenFilter"
            :on-toggle-update="onToggleUpdateEmbedding" :on-toggle-update-foro="onToggleUpdateForo"
            :on-toggle-options="onToggleOptions" :similarity="similarity" />

          <!-- <TableFooter :current-page="Number(metaEmbedding.current_page)" :total-count="metaEmbedding.count"
            :page-size="metaEmbedding.page_size" @page-change="onPageChangeEmbedding" /> -->
          
          <TableFooter :current-page="metaEmbedding.current_page" :total-count="metaEmbedding.count"
            :page-size="10" @pageChange="onPageChangeEmbedding" />

            <!-- <TableFooter
              class="border-t border-slate-75 dark:border-slate-700/50"
              :current-page="Number(meta.currentPage)"
              :total-count="meta.count"
              :page-size="15"
              @pageChange="onPageChange"
            /> -->

          <EmbeddingTable :data-table="dataEmbedding" :on-toggle-edit="onToggleTrained"
            :on-toggle-update="onToggleUpdate"
            :on-toggle-prompt="onTogglePrompt" />

          <div v-show="showLoading" class="column p-8">
            <div class="custom-loader" />
          </div>
        </div>
      </div>
    </div>

    <woot-modal :show.sync="showPrompts" :on-close="hidePrompts">
      <div class="h-auto overflow-auto flex flex-col">
        <woot-modal-header header-title="Titulo de Modal" />
        <form class="flex flex-col w-full" @submit.prevent="setContentPrompts()">
          <div class="w-full">
            <label>
              {{ 'Prompts de Contenido' }}
              <textarea v-model.trim="dataSelectResponse.content_prompts" type="text" rows="8"
                placeholder="Describe los prompts de contenido..." />
            </label>
          </div>
          <div class="flex flex-row justify-end gap-2 py-2 px-0 w-full">
            <WootSubmitButton :button-text="$t('CANNED_MGMT.EDIT.FORM.SUBMIT')" />
            <button class="button clear" @click.prevent="onClose">
              {{ $t('CANNED_MGMT.EDIT.CANCEL_BUTTON_TEXT') }}
            </button>
          </div>
        </form>
      </div>
    </woot-modal>



    <woot-modal :show.sync="showOptions" :on-close="hideOptions" size="medium">
      <div class="h-auto overflow-auto flex flex-col">
        <woot-modal-header header-title="Control de Foros para entrenamiento." />
        <div class="flex flex-col w-full p-5">
          <div class="w-full overflow-x-auto text-slate-700 dark:text-slate-200">
            <table class="min-w-full divide-y divide-slate-75 dark:divide-slate-700">
              <thead>
                <th class="py-4 pr-4 text-left font-semibold text-slate-700 dark:text-slate-300">
                  {{ 'Nombre del Foro' }}
                </th>
                <th class="py-4 pr-4 text-left font-semibold text-slate-700 dark:text-slate-300">
                  {{ 'URL Foro' }}
                </th>
                <th class="py-4 pr-4 text-left font-semibold text-slate-700 dark:text-slate-300" colspan="2">
                  {{ 'Opciones' }}
                </th>
              </thead>
              <tbody class="divide-y divide-slate-50 dark:divide-slate-800">
                <tr v-for="data in forumsAccounts" :key="data.id" class="pt-1">
                  <td>{{ data.forum_account }}</td>
                  <td>
                    <span> {{ data.forum_url }} </span>
                  </td>
                  <td>
                    <woot-button class="px-3" icon="arrow-download" variant="smooth" size="small" color-scheme="primary"
                      icon-size="14" @click="updateForumsAccounts(data)">
                      {{ 'Actualizar' }}
                    </woot-button>
                  </td>
                  <td class="">
                    <woot-button class="px-3" icon="delete" variant="smooth" size="small" color-scheme="alert"
                      icon-size="14" @click="setDelete(data.id)">
                      {{ 'Borrar' }}
                    </woot-button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </woot-modal>


  </div>
</template>

<style scoped lang="scss">
.custom-loader {
  width: 100%;
  height: 20px;
  background: linear-gradient(90deg, #0000, #a722f4) left -50px top 0/50px 20px no-repeat #e4e4ed;
  animation: ct2 1s infinite linear;
}

@keyframes ct2 {
  100% {
    background-position: right -50px top 0;
  }
}

@import '~dashboard/assets/scss/variables';
</style>
