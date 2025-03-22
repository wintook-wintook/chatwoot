<template>
  <div>
    <div class="mt-2 flex-1">
      <div class="grid grid-cols-1 md:grid-cols-1 xl:grid-cols-1 gap-4">
        <div class="w-full">
          <vocabulario-header
            :search-query="searchQueryVocabulario"
            :on-input-search="onInputSearchVocabulario"
            :on-search-submit="onSearchSubmitVocabulario"
            :on-toggle-create="onToggleCreateVocabulario"
            :on-toggle-update="onToggleUpdateVocabulario"
          />
          <vocabulario-table
            :data-table="dataVocabulario"
            :on-toggle-edit="onToggleEditPalabra"
            :on-toggle-delete="onToggleDeletePalabra"
          />
          <table-footer
            @pageChange="onPageChangeVocabulario"
            :current-page="Number(metaVocabulario.current_page)"
            :total-count="metaVocabulario.count"
            :page-size="metaVocabulario.page_size"
          />
        </div>
      </div>
    </div>

      <woot-modal :show.sync="showPalabra" :on-close="hidePalabra">
        <div class="column content-box">
          <woot-modal-header
            :header-title="'Vocabulario EVAi'"
            :header-content="'Reglas para esta palabra para la búsqueda en la base de dato de conocimiento.'"
          />

          <form @submit.prevent="setPalabraVocabulario">
            <label>{{ 'Regla General:' }}</label>
            <div class="w-full flex items-center">
              <ol>
                <li style="font-size: 13px">
                  El algoritmo de búsqueda avanzada excluye todas las palabras
                  en 1 a 3 caracteres.
                </li>
                <li style="font-size: 13px">
                  Se excluye todos los numeró de 1 y 2 caracteres.
                </li>
                <li style="font-size: 13px">
                  Se recomienda excluir palabras tales como HASTA, DESDE, COMO,
                  Etc..
                </li>
              </ol>
            </div>

            <div class="w-full flex items-center gap-2">
             <label :class="{}"
              >Descripción de Palabra
              <input type="text" v-model="dataPalabra.palabraClave" />
            </label> 
            </div>
            
            <div class="w-full flex items-center">
              <label :class="{}">
              <input type="hidden" v-model="dataPalabra.palabraClaveId" />
            </label>
            </div>
            
            <div class="w-full flex items-center">
             <label
              >{{ 'Consideraciones de esta palabra para la búsqueda.' }}
            </label> 
            </div>
            

            <div class="w-full flex items-center gap-2">
              <div class="w-full flex items-center gap-2">
                <input
                  id="palabra_incluir"
                  v-model="dataPalabra.excluirPalabra"
                  class="notification--checkbox"
                  type="radio"
                  value="false"
                  @input="handleExcluirPalabra"
                />
                <label for="palabra_incluir">{{ 'Incluir ' }}</label>
              </div>
              <div class="w-full flex items-center gap-2">
                <input
                  id="palabra_excluir"
                  v-model="dataPalabra.excluirPalabra"
                  class="notification--checkbox"
                  type="radio"
                  value="true"
                  @input="handleExcluirPalabra"
                />
                <label for="palabra_excluir">{{ 'Excluir' }}</label>
              </div>
            </div>

            <label>{{ 'Propiedades de esta palabra.' }}</label>

            <div class="w-full flex items-center gap-2">
              <input
                v-model="dataPalabra.activarClave"
                type="checkbox"
                :disabled="disabledExcluir"
              />
              <label>{{ 'Es palabra clave.' }}</label>
            </div>
            <div class="w-full flex items-center gap-2">
              <input
                v-model="dataPalabra.activarRespuesta"
                type="checkbox"
                :disabled="disabledExcluir"
              />
              <label>{{ 'Dar una respuesta por default.' }}</label>
            </div>

            <div class="w-full flex items-center gap-2">
              <input
                v-model="dataPalabra.apagarBot"
                type="checkbox"
                :disabled="disabledExcluir"
              />
              <label>{{ 'Apagar el Bot al dar la respuesta..' }}</label>
            </div>
            <div class="w-full flex items-center gap-2">
              <label>
                Descripción de respuesta por default
                <input
                  type="text"
                  v-model="dataPalabra.palabraRespuesta"
                  :disabled="disabledExcluir"
                />
              </label>
            </div>
            <div>
              <!-- <woot-button :is-disabled="isDisabledPalabra()" type="submit">
                            Guardar
                        </woot-button> -->
              <woot-button type="submit">Guardar</woot-button>
            </div>
          </form>
        </div>
      </woot-modal>

      <woot-delete-modal
        :show.sync="showDeleteConfirmationPalabra"
        :on-close="closeDeletePopupPalabra"
        :on-confirm="confirmDeletionPalabra"
        :title="'Confirmar eliminación'"
        :message="deleteMessagePalabra"
        :confirm-text="deleteConfirmTextPalabra"
        :reject-text="deleteRejectTextPalabra"
      />
  </div>
</template>

<script>
import axios from 'axios';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';

// import Integration from '../../../routes/dashboard/settings/integrations/Integration';
// import Integration from '../../../settings/integrations/Integration';

import VocabularioTable from './VocabularioTable';
import VocabularioHeader from './VocabularioHeader';
import TableFooter from 'dashboard/components/widgets/TableFooter';
// import TableFooter from './../../../../../components/widgets/TableFooter';
// import TableFooter from '../../../components/widgets/TableFooter';
//import TableFooter from '../../../../dashboard/components/widgets/TableFooter';

const DEFAULT_PAGE = 1;

export default {
  data() {
    return {
      searchQueryVocabulario: '',

      dataVocabulario: {},
      dataPalabra: {},
      metaVocabulario: {},
      showPalabra: false,
      showDeleteConfirmationPalabra: false,
      disabledExcluir: false,
    };
  },
  components: {
    VocabularioTable,
    VocabularioHeader,
    TableFooter,
  },
  computed: {
    ...mapGetters({
      currentUser: 'getCurrentUser',
    }),

    deleteConfirmTextPalabra() {
      return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.YES')} ${
        this.dataPalabra.palabraClave
      }`;
    },
    deleteRejectTextPalabra() {
      return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.NO')} ${
        this.dataPalabra.palabraClave
      }`;
    },
    deleteMessagePalabra() {
      return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.MESSAGE')} ${
        this.dataPalabra.palabraClave
      } ?`;
    },
  },
  mounted() {
    this.getVocabulario(DEFAULT_PAGE);
  },
  methods: {
    async getVocabulario(current_page) {
      let { access_token, account_id } = this.currentUser;
      let searchQuery = this.searchQueryVocabulario;
      let result = await axios
        .get(process.env.WINTOOK_BOT + '/api/getVocabulario', {
          params: {
            access_token,
            account_id,
            current_page,
            searchQuery,
          },
        })
        .then(function (resp) {
          return resp.data;
        })
        .catch(function (error) {
          return error;
        });
      if (result.status == 200) {
        this.metaVocabulario = result.meta;
        this.dataVocabulario = result.data.map(item => {
          return {
            ...item,
            excluir: item.excluir ? 'Excluida' : 'Incluida',
            activar_clave: item.activar_clave ? 'Si' : 'No',
            activar_respuesta: item.activar_respuesta ? 'Si' : 'No',
            palabraClaveId: item.palabra_clave_id,
            palabraClave: item.palabra_clave,
            excluirPalabra: item.excluir,
            activarClave: item.activar_clave,
            activarRespuesta: item.activar_respuesta,
            palabraRespuesta: item.respuesta,
            apagarBot: item.apagar_bot,
          };
        });
      }
    },

    async setPalabraVocabulario() {
      let { access_token, account_id } = this.currentUser;
      let {
        palabraClaveId,
        palabraClave,
        excluirPalabra,
        activarClave,
        activarRespuesta,
        palabraRespuesta,
        apagarBot,
      } = this.dataPalabra;

      let result = await axios
        .post(process.env.WINTOOK_BOT + '/api/setPalabraVocabulario', {
          params: {
            access_token: access_token,
            account_id: account_id,
            palabra_clave_id: palabraClaveId,
            palabra_clave: palabraClave,
            excluir: excluirPalabra,
            activar_clave: activarClave,
            activar_respuesta: activarRespuesta,
            respuesta: palabraRespuesta,
            apagar_bot: apagarBot,
          },
        })
        .then(function (resp) {
          return resp.data;
        })
        .catch(function (error) {
          return error;
        });
      if (result.status === 200) {
        useAlert(result.msg);
        this.showPalabra = false;
        this.getVocabulario(DEFAULT_PAGE);
      }
      if (result.status === 350) {
        useAlert(result.msg);
      }
    },

    deleteVocabulario(data) {
      this.dataPalabra = data;
      this.showDeleteConfirmationPopupPalabraClave = true;
    },

    onSearchSubmitVocabulario() {
      if (this.searchQueryVocabulario) {
        this.getVocabulario(DEFAULT_PAGE);
      }
    },
    onInputSearchVocabulario(event) {
      const newQuery = event.target.value;
      const refetchAll = !!this.searchQueryVocabulario && newQuery === '';
      this.searchQueryVocabulario = newQuery;
      if (refetchAll) {
        this.getVocabulario(DEFAULT_PAGE);
      }
    },

    hidePalabra() {
      this.showPalabra = false;
    },
    onToggleCreateVocabulario() {
      this.dataPalabra = {
        palabraClaveId: 0,
        palabraClave: '',
        excluirPalabra: false,
        activarClave: false,
        activarRespuesta: false,
        palabraRespuesta: '',
        apagarBot: false,
      };
      (this.disabledExcluir = false), (this.showPalabra = true);
    },

    onToggleEditPalabra(data) {
      this.dataPalabra = data;
      console.log('data');
      console.log(data);
      this.disabledExcluir = data.excluirPalabra;
      this.showPalabra = true;
    },

    onPageChangeVocabulario(current_page) {
      this.getVocabulario(current_page);
    },
    onToggleUpdateVocabulario() {
      this.searchQueryVocabulario = '';
      this.getVocabulario(DEFAULT_PAGE);
    },

    confirmDeletionPalabra() {
      this.closeDeletePopupPalabra();
      this.deleteVocabulario();
    },
    closeDeletePopupPalabra() {
      this.showDeleteConfirmationPalabra = false;
    },
    onToggleDeletePalabra(data) {
      this.dataPalabra = data;
      this.showDeleteConfirmationPalabra = true;
    },
    async deleteVocabulario() {
      let { access_token, account_id } = this.currentUser;
      let { palabraClaveId } = this.dataPalabra;
      let response = await axios
        .post(process.env.WINTOOK_BOT + '/api/deleteVocabulario', {
          data: {
            access_token: access_token,
            account_id: account_id,
            palabra_clave_id: palabraClaveId,
          },
        })
        .then(function (resp) {
          return resp.data;
        })
        .catch(function (error) {
          return error;
        });
      if (response.status === 200) {
        useAlert(response.msg);
        this.getVocabulario(DEFAULT_PAGE);
      }
    },
    handleExcluirPalabra(e) {
      this.disabledExcluir = !this.disabledExcluir;

      if (this.disabledExcluir) {
        this.palabra.activarRespuesta = false;
        (this.palabra.apagarBot = false), (this.palabra.activarClave = false);
        this.palabra.palabraRespuesta = '';
      }
    },
    isDisabledPalabra() {
      let valor = false;
      if (!this.dataPalabra.palabraClave) {
        valor = true;
      } else {
        const contador = this.dataPalabra.palabraClave.split(' ');
        if (contador.length > 1) {
          valor = true;
        }
      }

      if (this.dataPalabra.activarRespuesta) {
        if (!this.dataPalabra.palabra) {
          valor = false;
        }
        valor = true;
      }

      return valor;
    },
  },
};
</script>

<style scoped lang="scss">
@import '~dashboard/assets/scss/variables';
</style>
