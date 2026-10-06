<template>
    <div>
        <div class="mt-2 flex-1">
        <div class="grid grid-cols-2 md:grid-cols-2 xl:grid-cols-2 gap-4">
            <div class="w-full">
                            <h5 class="mb-0 text-slate-800 dark:text-slate-100">Palabras raíz</h5>
                            <p class="mt-0 mb-0 text-xs text-slate-400">Da click en una raíz para ver sus sinónimos.</p>
                            <sinonimos-raiz-header
                                :search-query="searchQueryRaiz"
                                :on-input-search="onInputSearchRaiz"
                                :on-search-submit="onSearchSubmitRaiz"
                                :on-toggle-create="onToggleCreateSinonimoRaiz"
                            />
                            <sinonimos-raiz-table
                                :data-sinonimos-raiz="dataSinonimosRaiz"
                                :selected-id="palabra_sinonimo_filter_id"
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
                            <h5 class="mb-0 text-slate-800 dark:text-slate-100">
                                Sinónimos
                                <span v-if="raizSeleccionadaNombre"
                                    class="ml-1 inline-flex items-center gap-1 px-2 py-0.5 align-middle text-xs font-normal rounded bg-woot-50 dark:bg-woot-800/40 text-woot-600 dark:text-woot-200">
                                    de: {{ raizSeleccionadaNombre }}
                                    <button type="button" class="font-semibold leading-none" title="Ver todos" @click="onToggleUpdateSinonimo">✕</button>
                                </span>
                            </h5>
                            <p class="mt-0 mb-0 text-xs text-slate-400">
                                {{ raizSeleccionadaNombre ? 'Sinónimos de esta raíz.' : 'Mostrando todos los sinónimos.' }}
                            </p>
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
                            <option v-for="d in dataPalabrasRaizSelect"
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
                        Categoría semántica <span class="text-slate-400">(opcional)</span>
                        <select v-model="dataSinonimoRaiz.sinonimo_semantico_id">
                            <option :value="null">{{ 'Sin categoría' }}</option>
                            <option v-for="c in sinonimoSemanticos"
                                :key="c.id" :value="c.id">
                                {{ c.nombre }}
                            </option>
                        </select>
                    </label>
                    <label>
                        <input type="hidden" v-model="dataSinonimoRaiz.palabra_id"/>
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
    import { mapGetters } from 'vuex';
    import { useAlert } from 'dashboard/composables';

    import SinonimosRaizTable from './SinonimosRaizTable';
    import SinonimosRaizHeader from './SinonimosRaizHeader';
    import SinonimosTable from './SinonimosTable';
    import SinonimosHeader from './SinonimosHeader';
    import TableFooter from 'dashboard/components/widgets/TableFooter';

    import PalabrasSinonimosAPI from 'dashboard/api/palabrasSinonimos';
    import SinonimosSemanticosAPI from 'dashboard/api/sinonimosSemanticos';

    const DEFAULT_PAGE = 1;

    export default {
        data() {
            return {
                searchQuerySinonimo: '',
                searchQueryRaiz: '',

                dataSinonimosRaiz: [],
                dataSinonimoRaiz: {
                    palabra_id: 0,
                    palabra: '',
                    palabra_sinonimo_id: 0,
                    sinonimo_semantico_id: null,
                },
                dataSinonimos: [],
                dataSinonimo: {
                    palabra_id: 0,
                    palabra: '',
                    palabra_sinonimo_id: 0,
                },
                metaSininimos: {},
                metaSininimosRaiz: {},

                dataPalabrasRaizSelect: [],
                sinonimoSemanticos: [],

                showSinonimo: false,
                showSinonimoRaiz: false,

                showDeleteConfirmationPalabraRaiz: false,
                showDeleteConfirmationSinonimo: false,

                palabra_sinonimo_filter_id: 0,
                raizSeleccionadaNombre: '',
            }
        },
        components: {
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
                const base = `${this.$t('LABEL_MGMT.DELETE.CONFIRM.MESSAGE')} ${
                    this.dataSinonimoRaiz.palabra
                } ?`;
                const n = this.dataSinonimoRaiz.sinonimos_count || 0;
                if (n > 0) {
                    return `${base} Se eliminarán también sus ${n} sinónimo${n === 1 ? '' : 's'}.`;
                }
                return base;
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
            this.getSemanticos();
            this.getSinonimosRaiz(DEFAULT_PAGE);
            this.getSinonimos(DEFAULT_PAGE);
        },
        methods: {
            wordCounterRaiz() {
                return this.dataSinonimoRaiz.palabra.trim().split(/\s+/).length > 1;
            },
            wordCounterSinonimo() {
                return this.dataSinonimo.palabra.trim().split(/\s+/).length > 1;
            },

            // -------- Catálogo semántico (fijo) --------
            async getSemanticos() {
                try {
                    const { data } = await SinonimosSemanticosAPI.get();
                    this.sinonimoSemanticos = data;
                } catch (error) {
                    this.sinonimoSemanticos = [];
                }
            },

            // -------- Palabras raíz --------
            async getSinonimosRaiz(page) {
                try {
                    const { data } = await PalabrasSinonimosAPI.raices({
                        search: this.searchQueryRaiz,
                        page,
                    });
                    this.metaSininimosRaiz = data.meta;
                    this.dataSinonimosRaiz = data.data;
                } catch (error) {
                    this.metaSininimosRaiz = {};
                    this.dataSinonimosRaiz = [];
                }
            },

            async setSinonimoRaiz() {
                try {
                    const { palabra_id, palabra, sinonimo_semantico_id } = this.dataSinonimoRaiz;
                    if (palabra_id) {
                        await PalabrasSinonimosAPI.actualizar(palabra_id, {
                            palabra,
                            sinonimo_semantico_id: sinonimo_semantico_id || null,
                        });
                    } else {
                        await PalabrasSinonimosAPI.crearRaiz({
                            palabra,
                            sinonimoSemanticoId: sinonimo_semantico_id || null,
                        });
                    }
                    useAlert('Palabra raíz guardada.');
                    this.showSinonimoRaiz = false;
                    this.getSinonimosRaiz(DEFAULT_PAGE);
                } catch (error) {
                    useAlert('No se pudo guardar la palabra raíz.');
                }
            },

            // -------- Sinónimos --------
            async getSinonimos(page) {
                try {
                    const { data } = await PalabrasSinonimosAPI.sinonimos({
                        raizId: this.palabra_sinonimo_filter_id,
                        search: this.searchQuerySinonimo,
                        page,
                    });
                    this.metaSininimos = data.meta;
                    this.dataSinonimos = data.data;
                } catch (error) {
                    this.metaSininimos = {};
                    this.dataSinonimos = [];
                }
            },

            async setSinonimo() {
                try {
                    const { palabra_id, palabra, palabra_sinonimo_id } = this.dataSinonimo;
                    if (palabra_id) {
                        await PalabrasSinonimosAPI.actualizar(palabra_id, { palabra });
                    } else {
                        await PalabrasSinonimosAPI.crearSinonimo({
                            palabra,
                            palabraSinonimoId: palabra_sinonimo_id,
                        });
                    }
                    useAlert('Sinónimo guardado.');
                    this.showSinonimo = false;
                    this.getSinonimos(DEFAULT_PAGE);
                } catch (error) {
                    useAlert('No se pudo guardar el sinónimo.');
                }
            },

            async getPalabrasRaizSelect() {
                try {
                    const { data } = await PalabrasSinonimosAPI.raicesSelect();
                    this.dataPalabrasRaizSelect = data.data;
                } catch (error) {
                    this.dataPalabrasRaizSelect = [];
                }
            },

            // -------- Búsqueda --------
            onSearchSubmitRaiz() {
                this.getSinonimosRaiz(DEFAULT_PAGE);
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
                this.getSinonimos(DEFAULT_PAGE);
            },
            onInputSearchSinonimo(event) {
                const newQuery = event.target.value;
                const refetchAll = !!this.searchQuerySinonimo && newQuery === '';
                this.searchQuerySinonimo = newQuery;
                if (refetchAll) {
                    this.getSinonimos(DEFAULT_PAGE);
                }
            },

            // -------- Modales / acciones --------
            hideSinonimo() {
                this.showSinonimo = false;
            },
            hideSinonimoRaiz() {
                this.showSinonimoRaiz = false;
            },
            onToggleCreateSinonimo() {
                this.dataSinonimo = {
                    palabra_id: 0,
                    palabra: '',
                    palabra_sinonimo_id: this.palabra_sinonimo_filter_id,
                };
                this.getPalabrasRaizSelect();
                this.showSinonimo = true;
            },
            onToggleCreateSinonimoRaiz() {
                this.dataSinonimoRaiz = {
                    palabra_id: 0,
                    palabra: '',
                    palabra_sinonimo_id: 0,
                    sinonimo_semantico_id: null,
                };
                this.showSinonimoRaiz = true;
            },
            onToggleEditSinonimo(data) {
                this.getPalabrasRaizSelect();
                this.dataSinonimo = { ...data };
                this.showSinonimo = true;
            },
            onToggleEditSinonimoRaiz(data) {
                this.dataSinonimoRaiz = {
                    ...data,
                    sinonimo_semantico_id: data.sinonimo_semantico_id || null,
                };
                this.showSinonimoRaiz = true;
            },
            onToggleUpdateSinonimo() {
                this.searchQuerySinonimo = '';
                this.palabra_sinonimo_filter_id = 0;
                this.raizSeleccionadaNombre = '';
                this.getSinonimos(DEFAULT_PAGE);
            },
            onToggleFilterClick(row) {
                this.palabra_sinonimo_filter_id = row.palabra_id;
                this.raizSeleccionadaNombre = row.palabra;
                this.getSinonimos(DEFAULT_PAGE);
            },
            onPageChangeSinonimos(page) {
                this.getSinonimos(page);
            },
            onPageChangeSinonimosRaiz(page) {
                this.getSinonimosRaiz(page);
            },

            // -------- Borrado raíz --------
            onToggleDeletePalabraRaiz(data) {
                this.dataSinonimoRaiz = data;
                this.showDeleteConfirmationPalabraRaiz = true;
            },
            closeDeletePopupPalabraRaiz() {
                this.showDeleteConfirmationPalabraRaiz = false;
            },
            confirmDeletionPalabraRaiz() {
                this.closeDeletePopupPalabraRaiz();
                this.deleteSinonimoRaiz();
            },
            async deleteSinonimoRaiz() {
                try {
                    await PalabrasSinonimosAPI.eliminar(this.dataSinonimoRaiz.palabra_id);
                    useAlert('Palabra raíz eliminada.');
                    this.palabra_sinonimo_filter_id = 0;
                    this.getSinonimosRaiz(DEFAULT_PAGE);
                    this.getSinonimos(DEFAULT_PAGE);
                } catch (error) {
                    useAlert('No se pudo eliminar la palabra raíz.');
                }
            },

            // -------- Borrado sinónimo --------
            onToggleDeleteSinonimo(data) {
                this.dataSinonimo = data;
                this.showDeleteConfirmationSinonimo = true;
            },
            closeDeletePopupSinonimo() {
                this.showDeleteConfirmationSinonimo = false;
            },
            confirmDeletionSinonimo() {
                this.closeDeletePopupSinonimo();
                this.deleteSinonimo();
            },
            async deleteSinonimo() {
                try {
                    await PalabrasSinonimosAPI.eliminar(this.dataSinonimo.palabra_id);
                    useAlert('Sinónimo eliminado.');
                    this.getSinonimos(DEFAULT_PAGE);
                } catch (error) {
                    useAlert('No se pudo eliminar el sinónimo.');
                }
            },
        }
    }

    </script>

    <style scoped lang="scss">
        @import '~dashboard/assets/scss/variables';
    </style>
