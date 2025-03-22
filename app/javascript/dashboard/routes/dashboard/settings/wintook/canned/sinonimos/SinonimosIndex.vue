<template>
    <div>
        <div class="mt-2 flex-1">
        <div class="grid grid-cols-2 md:grid-cols-2 xl:grid-cols-2 gap-4">
            <div class="w-full">
                            <sinonimos-raiz-header
                                :search-query="searchQueryRaiz"
                                :on-input-search="onInputSearchRaiz"
                                :on-search-submit="onSearchSubmitRaiz"
                                :on-toggle-create="onToggleCreateSinonimoRaiz"
                            />
                            <sinonimos-raiz-table
                                :data-sinonimos-raiz="dataSinonimosRaiz"
                                :on-toggle-edit="onToggleEditSinonimoRaiz"
                                :on-toggle-delete="onToggleDeletePalabraRaiz"
                                :on-toggle-filter-click="onToggleFilterClick"
                            />
                            <table-footer
                                @pageChange="onPageChangeSinonimosRaiz"
                                :current-page="Number(metaSininimosRaiz.current_page)"
                                :total-count="metaSininimosRaiz.count"
                                :page-size="metaSininimosRaiz.page_size"
                            />
            </div>
            <div class="w-full">
                            <sinonimos-header
                                :search-query="searchQuerySinonimo"
                                :on-input-search="onInputSearchSinonimo"
                                :on-search-submit="onSearchSubmitSinonimo"
                                :on-toggle-create-sinonimo="onToggleCreateSinonimo"
                                :on-toggle-update="onToggleUpdateSinonimo"
                            />
                            <sinonimos-table
                                :data-sinonimos="dataSinonimos"
                                :on-toggle-edit="onToggleEditSinonimo"
                                :on-toggle-delete="onToggleDeleteSinonimo"
                            />
                            <table-footer
                                @pageChange="onPageChangeSinonimos"
                                :current-page="Number(metaSininimos.current_page)"
                                :total-count="metaSininimos.count"
                                :page-size="metaSininimos.page_size"
                            />
            </div>
            </div>
        </div>

        <woot-modal :show.sync="showSinonimo" :on-close="hideSinonimo">
            <div class="column content-box">
                <woot-modal-header :header-title="'Sínonimos'"/>
                <form @submit.prevent="setSinonimo">
                    <label>
                        Palabra Raíz de Sínonimo
                        <select v-model="dataSinonimo.palabra_sinonimo_id">
                            <option :value="0">{{ 'Seleccione Palabra Raíz' }}</option>
                            <option v-for="d in this.dataPalabrasRaizSelect" 
                                :key="d.palabra_id" :value="d.palabra_id">
                                {{ d.palabra }}
                            </option>
                        </select>
                    </label>
                    <label>Descripción de Sínonimo
                        <input type="text" v-model="dataSinonimo.palabra"/>
                    </label>
                    <label>
                        <input type="hidden" v-model="dataSinonimo.palabra_id"/>
                    </label>
                    <div>
                        <woot-button type="submit"
                            :is-disabled="!dataSinonimo.palabra.length || !dataSinonimo.palabra_sinonimo_id || wordCounterSinonimo()">
                            Guardar
                        </woot-button>
                    </div>
                </form>
            </div>
        </woot-modal>
        <woot-modal :show.sync="showSinonimoRaiz" :on-close="hideSinonimoRaiz">
            <div class="column content-box">
                <woot-modal-header :header-title="'Palabra Raíz de Sínonimos'"/>
                <form @submit.prevent="setSinonimoRaiz">
                    <label>Descripción de Palabra Raíz de Sínonimos
                        <input type="text" v-model="dataSinonimoRaiz.palabra"/>
                    </label>
                    <label>
                        <input type="hidden" v-model="dataSinonimoRaiz.palabra_id"/>
                    </label>
                    <label>
                        <input type="hidden" v-model="dataSinonimoRaiz.palabra_sinonimo_id"/>
                    </label>
                    <div>
                        <woot-button type="submit"
                            :is-disabled="!dataSinonimoRaiz.palabra.length || wordCounterRaiz()">
                                Guardar
                        </woot-button>
                    </div>
                </form>
            </div>
        </woot-modal>
        <woot-delete-modal :show.sync="showDeleteConfirmationPalabraRaiz"
            :on-close="closeDeletePopupPalabraRaiz" :on-confirm="confirmDeletionPalabraRaiz"
            :title="'Confirmar eliminación'"
            :message="deleteMessagePalabraRaiz" 
            :confirm-text="deleteConfirmTextPalabraRaiz"
            :reject-text="deleteRejectTextPalabraRaiz"/>
        <woot-delete-modal :show.sync="showDeleteConfirmationSinonimo"
            :on-close="closeDeletePopupSinonimo" :on-confirm="confirmDeletionSinonimo"
            :title="'Confirmar eliminación'"
            :message="deleteMessageSinonimo" 
            :confirm-text="deleteConfirmTextSinonimo"
            :reject-text="deleteRejectTextSinonimo"/>
    </div>
</template>
    
    <script>
    import axios from "axios";
    import { mapGetters } from 'vuex';
    import { useAlert } from 'dashboard/composables';
    // import Integration from '../Integration';
    
    import SinonimosRaizTable from './SinonimosRaizTable';
    import SinonimosRaizHeader from './SinonimosRaizHeader';
    import SinonimosTable from './SinonimosTable';
    import SinonimosHeader from './SinonimosHeader';
    import TableFooter from 'dashboard/components/widgets/TableFooter';
    // import TableFooter from '../../../components/widgets/TableFooter';
    const DEFAULT_PAGE = 1;
    
    export default {
        data() {
            return {
                searchQuerySinonimo: '',
                searchQueryRaiz: '',

                dataSinonimosRaiz: {},
                dataSinonimoRaiz: { 
                    palabra_id: 0, 
                    palabra: '',
                    palabra_sinonimo_id: 0
                },
                dataSinonimos: {},
                dataSinonimo: { 
                    palabra_id: 0, 
                    palabra: '',
                    palabra_sinonimo_id: 0
                },
                dataPalabraClave: {},
                metaSininimos: {},
                metaSininimosRaiz: {},

                dataPalabrasRaizSelect: {},

                showSinonimo: false,
                showSinonimoRaiz: false,
    
                palabraClaveId: 0,
                palabra_raiz_id: 0,
    
                showDeleteConfirmationPopup: false,

                showDeleteConfirmationPalabraRaiz: false,
                showDeleteConfirmationSinonimo: false,

                palabra_sinonimo_filter_id: 0,
            }
        },
        components: {
            // Integration,
            SinonimosRaizTable,
            SinonimosRaizHeader,
            SinonimosTable,
            SinonimosHeader,
            TableFooter
        },
        computed: {
            ...mapGetters({
                currentUser: 'getCurrentUser',
            }),
            deleteConfirmTextPalabraClave() {
                return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.YES')} ${
                    this.dataPalabraClave.palabra_clave
                }`;
            },
            deleteRejectTextPalabraClave() {
                return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.NO')} ${
                    this.dataPalabraClave.palabra_clave
                }`;
            },
            deleteMessagePalabraClave() {
                return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.MESSAGE')} ${
                    this.dataPalabraClave.palabra_clave
                } ?`;
            },

            deleteConfirmTextPalabraRaiz() {
                return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.YES')} ${
                    this.dataSinonimoRaiz.palabra
                }`;
            },
            deleteRejectTextPalabraRaiz() {
                return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.NO')} ${
                    this.dataSinonimoRaiz.palabra
                }`;
            },
            deleteMessagePalabraRaiz() {
                return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.MESSAGE')} ${
                    this.dataSinonimoRaiz.palabra
                } ?`;
            },


            deleteConfirmTextSinonimo() {
                return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.YES')} ${
                    this.dataSinonimo.palabra
                }`;
            },
            deleteRejectTextSinonimo() {
                return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.NO')} ${
                    this.dataSinonimo.palabra
                }`;
            },
            deleteMessageSinonimo() {
                return `${this.$t('LABEL_MGMT.DELETE.CONFIRM.MESSAGE')} ${
                    this.dataSinonimo.palabra
                } ?`;
            },
        },
        mounted() {
            this.getSinonimosRaiz(DEFAULT_PAGE);
            this.getSinonimos(DEFAULT_PAGE);
        },
        methods: {
            wordCounterRaiz(){
                const count = this.dataSinonimoRaiz.palabra.split(" ").length;
                if (count>1) {
                    return true;
                }
                return false;
            },

            wordCounterSinonimo(){
                const count = this.dataSinonimo.palabra.split(" ").length;
                if (count>1) {
                   return true;
                }
                return false;
            },
            async getSinonimosRaiz(page){
                let account_id  = this.currentUser.account_id;
                let searchQuery = this.searchQueryRaiz;
                let result = await axios.get(process.env.WINTOOK_BOT+'/api/getSinonimosRaiz', {
                    params: {
                    account_id     : account_id, 
                    current_page   : page,
                    searchQuery    : searchQuery,
                    }
                })
                .then(function (resp) { return resp.data; })
                .catch(function (error) { return error; });
                if (result.status == 200) {
                    this.metaSininimosRaiz = result.meta;
                    this.dataSinonimosRaiz = result.data;
                }
            },

            async setSinonimoRaiz() {

                let palabra             = this.dataSinonimoRaiz.palabra;
                let access_token        = this.currentUser.access_token;
                let account_id          = this.currentUser.account_id;
                let palabra_id          = this.dataSinonimoRaiz.palabra_id;
            
                let result =  await axios.post(process.env.WINTOOK_BOT+'/api/setSinonimoRaiz', {
                    params: { 
                        access_token, account_id, palabra_id, palabra,
                    }
                })
                .then(function (resp) { return resp.data; })
                .catch(function (error) { return error; });
                if (result.status === 200) {
                    useAlert(result.msg);
                    this.showSinonimoRaiz = false;
                    this.getSinonimosRaiz(DEFAULT_PAGE);
                } 
                if (result.status === 350) {
                    useAlert(result.msg);
                } 
            },


            async getSinonimos(page){
                let account_id  = this.currentUser.account_id;
                let searchQuery = this.searchQuerySinonimo;
                let palabra_sinonimo_filter_id = this.palabra_sinonimo_filter_id;

                let result = await axios.get(process.env.WINTOOK_BOT+'/api/getSinonimos', {
                    params: {
                        account_id     : account_id, 
                        current_page   : page,
                        searchQuery    : searchQuery,
                        palabra_sinonimo_filter_id: palabra_sinonimo_filter_id,
                    }
                })
                .then(function (resp) { return resp.data; })
                .catch(function (error) { return error; });
                if (result.status === 200) {
                    this.metaSininimos = result.meta;
                    this.dataSinonimos = result.data.map(item => {
                        return {
                        ...item,
                        };
                    });
                }
                if (result.status === 400) {
                    this.metaSininimos = {};
                    this.dataSinonimos = [];
                }
            },

            async setSinonimo() {

                let access_token        = this.currentUser.access_token;
                let account_id          = this.currentUser.account_id;
                let palabra_id          = this.dataSinonimo.palabra_id;
                let palabra             = this.dataSinonimo.palabra;
                let palabra_sinonimo_id = this.dataSinonimo.palabra_sinonimo_id;

                let result =  await axios.post(process.env.WINTOOK_BOT+'/api/setSinonimo', {
                    params: { 
                        access_token, account_id, palabra_id, palabra, palabra_sinonimo_id,
                    }
                })
                .then(function (resp) { return resp.data; })
                .catch(function (error) { return error; });
                if (result.status === 200) {
                    useAlert(result.msg);
                    this.showSinonimo = false;
                    this.getSinonimos(DEFAULT_PAGE);
                } 
                if (result.status === 350) {
                    useAlert(result.msg);
                } 
            },


            async getPalabrasRaizSelect(){
                let account_id  = this.currentUser.account_id;
                let result = await axios.get(process.env.WINTOOK_BOT+'/api/getPalabrasRaizSelect', {
                    params: {
                        account_id     : account_id
                    }
                })
                .then(function (resp) { return resp.data; })
                .catch(function (error) { return error; });
                if (result.status == 200) {
                    this.dataPalabrasRaizSelect = result.data;
                    console.log(this.dataPalabrasRaizSelect);
                }
            },

            
    
            deleteVocabulario(data) {
                this.dataPalabraClave = data;
                console.log(this.dataPalabraClave.palabra_clave);
                this.showDeleteConfirmationPopupPalabraClave = true;
            },
    
            onSearchSubmitRaiz() {
                if (this.searchQueryRaiz) {
                    this.getSinonimosRaiz(DEFAULT_PAGE);
                }
            },
            onInputSearchRaiz(event) {
                const newQuery = event.target.value;
                const refetchAll = !!this.searchQueryRaiz && newQuery === '';
                this.searchQueryRaiz = newQuery;
                if (refetchAll) {
                    this.getSinonimosRaiz(DEFAULT_PAGE);
                }
            },


            onSearchSubmitSinonimo() {
                if (this.searchQuerySinonimo) {
                    this.palabra_sinonimo_filter_id = 0;
                    this.getSinonimos(DEFAULT_PAGE);
                }
            },
            onInputSearchSinonimo(event) {
                const newQuery = event.target.value;
                const refetchAll = !!this.searchQuerySinonimo && newQuery === '';
                this.searchQuerySinonimo = newQuery;
                if (refetchAll) {
                    this.getSinonimos(DEFAULT_PAGE);
                }
            },


            onPageChange(page) {
                //this.selectedContactId = '';
                this.getSinonimosRaiz(page);
            },
            hideSinonimo() {
                this.showSinonimo = false;
            },
            hideSinonimoRaiz() {
                this.showSinonimoRaiz = false;
            },
            onToggleCreateSinonimo() {
                let palabra_sinonimo_filter_id = this.palabra_sinonimo_filter_id
                this.dataSinonimo = { 
                    palabra_id: 0, 
                    palabra: '',
                    palabra_sinonimo_id: palabra_sinonimo_filter_id
                };
                this.getPalabrasRaizSelect();
                this.showSinonimo = true;
            },

            onToggleCreateSinonimoRaiz() {
                this.dataSinonimoRaiz = { 
                    palabra_id: 0, 
                    palabra: '',
                    palabra_sinonimo_id: 0
                };
                this.showSinonimoRaiz = true;
            },

            onToggleEditSinonimo(data) {
                this.getPalabrasRaizSelect();
                this.dataSinonimo = data;
                this.showSinonimo = true;
            },

            onToggleEditSinonimoRaiz(data) {
                this.dataSinonimoRaiz = data;
                this.showSinonimoRaiz = true;
            },
            
            closeDeletePopupPalabraClave() {
                this.showDeleteConfirmationPopupPalabraClave = false;
            },
    
            confirmDeletionPalabraClave() {
                this.closeDeletePopupPalabraClave();
                this.deletePalabraClave();
            },
    

            async deletePalabraClave() {
                let token             = this.currentUser.access_token;
                let palabra_clave_id  = this.dataPalabraClave.palabra_clave_id;
                let account_id        = this.currentUser.account_id;
                let response = await axios.get(process.env.WINTOOK_BOT+'/api/deleteVocabulario', {
                    params: { 
                    token             : token, 
                    account_id        : account_id, 
                    palabra_clave_id  : palabra_clave_id,
                    }
                })
                .then(function (resp)   { return resp.data; })
                .catch(function (error) { return error;     });
                if (response.status === 200) {
                    useAlert('Se ha eliminado palabra del vocabulario...');
                    this.getSinonimosRaiz();
                }
            },
            onPageChangeSinonimos(page) {
                this.getSinonimos(page);
            },
            onPageChangeSinonimosRaiz(page) {
                this.getSinonimosRaiz(page);
            },
            
            confirmDeletionPalabraRaiz() {
                this.closeDeletePopupPalabraRaiz();
                this.deleteSinonimoRaiz();
            },
            closeDeletePopupPalabraRaiz() {
                this.showDeleteConfirmationPalabraRaiz = false;
            },
            onToggleDeletePalabraRaiz(data) {
                this.dataSinonimoRaiz = data;
                this.showDeleteConfirmationPalabraRaiz = true;
            },
            async deleteSinonimoRaiz() {
                let { access_token, account_id }                  = this.currentUser;
                let { palabra_id, palabra, palabra_sinonimo_id }  = this.dataSinonimoRaiz;
                let response = await axios.post(process.env.WINTOOK_BOT+'/api/deleteSinonimoRaiz', {
                    data: {  access_token, account_id, palabra_id, palabra, palabra_sinonimo_id }
                })
                .then(function (resp)   { return resp.data; })
                .catch(function (error) { return error;     });
                if (response.status === 200) {
                    useAlert(response.msg);
                    this.getSinonimosRaiz(DEFAULT_PAGE);
                    this.getSinonimos(DEFAULT_PAGE);
                }
            },


            
            onToggleUpdateSinonimo() {
                this.searchQuerySinonimo = "";
                this.palabra_sinonimo_filter_id = 0;
                this.getSinonimos(DEFAULT_PAGE);
            },

            confirmDeletionSinonimo() {
                this.closeDeletePopupSinonimo();
                this.deleteSinonimo();
            },
            closeDeletePopupSinonimo() {
                this.showDeleteConfirmationSinonimo = false;
            },
            onToggleDeleteSinonimo(data) {
                this.dataSinonimo = data;
                this.showDeleteConfirmationSinonimo = true;
            },
            async deleteSinonimo() {
                let { access_token, account_id }                  = this.currentUser;
                let { palabra_id, palabra, palabra_sinonimo_id }  = this.dataSinonimo;
                let response = await axios.post(process.env.WINTOOK_BOT+'/api/deleteSinonimo', {
                    data: {  access_token, account_id, palabra_id, palabra, palabra_sinonimo_id }
                })
                .then(function (resp)   { return resp.data; })
                .catch(function (error) { return error;     });
                if (response.status === 200) {
                    useAlert(response.msg);
                    this.getSinonimos(DEFAULT_PAGE);
                }
            },
            onToggleFilterClick(data) {
                let { palabra_sinonimo_id }  = data;
                this.palabra_sinonimo_filter_id = palabra_sinonimo_id;
                this.getSinonimos(DEFAULT_PAGE);
            },
        }
    }
    
    </script>
    
    <style scoped lang="scss">
        @import '~dashboard/assets/scss/variables';
    </style>