<!--
  ================================================================================
  proyecto@contact_tracking
  ================================================================================
  Componente: ContactTrackingModal.vue (REFACTORIZADO - ORQUESTADOR)
  Descripción: Modal principal que coordina sub-componentes
  Versión: 5.2.0 (UX Mejorada - Navegación Simplificada)
  Cambios en v5.2.0:
    - En "Seguimientos Activos": NO se muestran otros tabs
    - En "Captura/Plantillas": Se oculta lista, aparece botón "Volver"
    - Navegación clara entre vistas
    - Botón "Nuevo Seguimiento" en la lista
  ================================================================================
-->

<template>
    <woot-modal :show="show" :on-close="onClose" size="medium">
        <!-- Header personalizado con botón Volver a la derecha -->
        <div class="flex items-start justify-between px-8 pt-8 pb-0">
            <div>
                <h2 class="text-base font-semibold leading-6 text-slate-800 dark:text-slate-50">
                    {{ $t('CONTACT_TRACKING.TITLE') }}
                </h2>
                <p class="mt-2 text-sm leading-5 text-slate-600 dark:text-slate-300">
                    {{ $t('CONTACT_TRACKING.DESCRIPTION') }}
                </p>
            </div>
            <woot-button
                v-if="activeTab !== 0"
                
                color-scheme="success"
                icon="chevron-left"
                size="small"
                class="shrink-0 mt-6"
                @click="returnToList"
            >
                Volver a Seguimientos
            </woot-button>
        </div>

        <!-- Alerta de integración -->
        <div v-if="!integrationAvailable && hasCheckedIntegration" class="callout warning">
            <p>
                <fluent-icon icon="warning" size="16" />
                {{ $t('CONTACT_TRACKING.INTEGRATION_NOT_AVAILABLE') }}
            </p>
        </div>

        <div class="w-full flex flex-col">

            


            <!-- Tabs Principales (solo visibles cuando NO está en Seguimientos Activos) -->
            <woot-tabs v-if="activeTab !== 0" class="font-medium [&_.tabs]:p-0 mb-4 px-6" :index="mappedTabIndex"
                @change="onVisibleTabChange">
                <woot-tabs-item v-for="tab in visibleTabs" :key="tab.key" :name="tab.name" :show-badge="tab.showBadge"
                    :badge-count="tab.badgeCount" />
            </woot-tabs>

            <div class="flex-1 p-0 h-[520px] overflow-hidden">
                <div class="h-full flex flex-col">

                    <!-- TAB 0: LISTA DE SEGUIMIENTOS -->
                    <TrackingList v-show="activeTab === 0" class="px-6 pb-6 h-full overflow-auto"
                        :contact-id="contactId" :conversation-id="conversationId" :trackings="localTrackings"
                        :is-loading="isLoadingTrackings" @edit="handleEdit" @pause="handlePause" @resume="handleResume"
                        @cancel="handleCancel" @refresh="loadTrackings" @add-new="handleAddNew"
                        @duplicate="handleDuplicate" />

                    <!-- TAB 1: FORMULARIO -->
                    <TrackingForm ref="trackingFormRef" v-show="activeTab === 1" class="px-6 pb-6 h-full overflow-auto"
                        :contact-id="contactId" :conversation-id="conversationId" :current-chat="currentChat"
                        :integration-available="integrationAvailable" :editing-tracking="editingTracking"
                        :duplicate-source="duplicateSourceTracking"
                        :tracking-templates="filteredTrackingTemplates"
                        :is-loading-templates="isLoadingTemplates"
                        @submit="handleSubmit" @cancel="handleCancelEdit" @close="onClose"
                        @update:maxAttempts="maxAttempts = $event"
                        @reload-templates="reloadTemplates"
                        @apply-template="handleApplyTemplate"
                        @clear-template="handleClearTemplate" />

                    <!-- TAB 2: PLANTILLAS WHATSAPP -->
                    <TrackingTemplates v-show="activeTab === 2" class="px-6 pb-6 h-full overflow-auto"
                        :inbox-id="currentChat.inbox_id" :max-attempts="maxAttempts" :templates="whatsappTemplates"
                        @update:templates="updateTemplates" />

                </div>
            </div>
        </div>

        <!-- Modal de Reanudacion -->
        <ResumeTrackingModal v-if="trackingToResume" :show="showResumeModal" :tracking="trackingToResume"
            :contact-id="contactId" @close="handleResumeModalClose" @resumed="handleResumeSuccess" />

        <!-- Modal de Cancelación -->
        <CancelTrackingModal v-if="trackingToCancel" :show="showCancelModal" :tracking="trackingToCancel"
            :is-loading="isCancelling" @close="handleCancelModalClose" @confirm="handleCancelConfirm" />

        <!-- Modal informativo de plantillas -->
        <woot-modal :show="showTemplateWarning" :on-close="closeTemplateWarning" size="small">
            <div class="flex flex-col p-6">
                <woot-modal-header
                    header-title="Plantillas incompletas"
                    :header-content="templateWarningMessage"
                />
                <div class="flex items-start gap-3 p-4 mb-4 bg-yellow-50 dark:bg-yellow-900/20 rounded-lg border border-yellow-200 dark:border-yellow-700">
                    <fluent-icon icon="warning" size="20" class="text-yellow-600 dark:text-yellow-400 shrink-0 mt-0.5" />
                    <div class="text-sm text-yellow-800 dark:text-yellow-200">
                        <p class="font-medium mb-1">Todos los intentos deben tener una plantilla asignada.</p>
                        <p>Asigna una plantilla a cada intento antes de guardar el seguimiento.</p>
                    </div>
                </div>
                <div class="flex justify-end pt-2">
                    <woot-button @click="closeTemplateWarning">
                        Entendido
                    </woot-button>
                </div>
            </div>
        </woot-modal>
    </woot-modal>
</template>

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import TrackingForm from './TrackingForm.vue';
import TrackingTemplates from './TrackingTemplates.vue';
import TrackingList from './TrackingList.vue';
import ResumeTrackingModal from './ResumeTrackingModal.vue';
import CancelTrackingModal from './CancelTrackingModal.vue';
import { normalizeTrackingsResponse } from '../../../helper/trackingHelpers';

export default {
    name: 'ContactTrackingModal',

    components: {
        TrackingForm,
        TrackingTemplates,
        TrackingList,
        ResumeTrackingModal,
        CancelTrackingModal,
    },

    props: {
        show: {
            type: Boolean,
            default: false,
        },
        contactId: {
            type: Number,
            required: true,
        },
        conversationId: {
            type: Number,
            default: null,
        },
        currentChat: {
            type: Object,
            default: () => ({}),
        },
    },

    data() {
        return {
            activeTab: 0,
            integrationAvailable: true,
            hasCheckedIntegration: false,
            isLoadingTrackings: false,
            localTrackings: [],
            editingTracking: null,
            isCreatingNew: false,
            whatsappTemplates: ['', '', ''],
            maxAttempts: 3,
            // Modal de reanudacion
            showResumeModal: false,
            trackingToResume: null,
            // Modal de cancelación
            showCancelModal: false,
            trackingToCancel: null,
            isCancelling: false,
            // Modal informativo de plantillas
            showTemplateWarning: false,
            templateWarningMessage: '',
            // Plantillas de seguimiento
            selectedTemplateId: null,
            isLoadingTemplates: false,
            // Duplicación de seguimiento completado
            duplicateSourceTracking: null,
        };
    },

    computed: {
        ...mapGetters({
            inboxes: 'inboxes/getInboxes',
            allTrackingTemplates: 'trackingTemplates/getTemplates',
        }),

        filteredTrackingTemplates() {
            const inboxId = this.currentChat?.inbox_id;
            if (!inboxId) return this.allTrackingTemplates;
            return this.allTrackingTemplates.filter(
                t => t.inbox_id === inboxId || t.inbox_id === Number(inboxId)
            );
        },

        tabs() {
            const baseTabs = [
                {
                    key: 0,
                    name: 'Seguimientos Activos',
                    showBadge: false,
                    badgeCount: 0,
                },
                {
                    key: 1,
                    name: 'Captura de Seguimiento',
                    showBadge: false,
                    badgeCount: 0,
                },
            ];

            if (this.isWhatsAppChannel && !this.isAfterFirstAttempt) {
                baseTabs.push({
                    key: 2,
                    name: 'Plantillas WhatsApp',
                    showBadge: false,
                    badgeCount: 0,
                });
            }

            return baseTabs;
        },

        visibleTabs() {
            // Cuando NO está en Seguimientos Activos, mostrar solo Captura y Plantillas
            return this.tabs.filter(tab => tab.key !== 0);
        },

        mappedTabIndex() {
            // Mapear el activeTab real al índice en visibleTabs
            // activeTab 1 (Captura) → índice 0 en visibleTabs
            // activeTab 2 (Plantillas) → índice 1 en visibleTabs
            if (this.activeTab === 1) return 0;
            if (this.activeTab === 2) return 1;
            return 0;
        },

        isAfterFirstAttempt() {
            return (this.editingTracking?.attempt_count ?? 0) > 0;
        },

        isWhatsAppChannel() {
            if (!this.currentChat || !this.currentChat.meta) return false;
            const channelType = this.currentChat.meta.channel;
            return channelType === 'Channel::Whatsapp' ||
                channelType === 'whatsapp' ||
                channelType === 'Channel::WhatsappCloud';
        },

        hasTemplatesConfigured() {
            return this.whatsappTemplates.filter(t => t).length > 0;
        },

        configuredTemplatesCount() {
            return this.whatsappTemplates.filter(t => t).length;
        },

        trackingsCount() {
            return this.localTrackings.length;
        },
    },

    watch: {
        show: {
            immediate: true,
            handler(newVal) {
                if (newVal) {
                    this.loadData();
                }
            },
        },
    },

    mounted() {
        if (this.show) {
            this.loadData();
        }
    },

    methods: {
        // =====================================================
        // NAVEGACIÓN DE TABS
        // =====================================================
        onTabChange(index) {
            this.activeTab = index;

            // Cargar trackings al entrar al tab 0 (Lista)
            if (index === 0) {
                this.loadTrackings();
            }
        },

        returnToList() {
            // Cancelar cualquier edición/creación activa y volver a la lista
            this.editingTracking = null;
            this.isCreatingNew = false;
            this.duplicateSourceTracking = null;
            this.whatsappTemplates = ['', '', ''];

            // Resetear formulario hijo
            this.$nextTick(() => {
                if (this.$refs.trackingFormRef?.resetForm) {
                    this.$refs.trackingFormRef.resetForm();
                }
            });

            this.activeTab = 0;
            this.loadTrackings();
        },

        onVisibleTabChange(visibleIndex) {
            // Mapear el índice de visibleTabs al activeTab real
            // índice 0 en visibleTabs → activeTab 1 (Captura)
            // índice 1 en visibleTabs → activeTab 2 (Plantillas)
            const realIndex = this.visibleTabs[visibleIndex]?.key;
            if (realIndex !== undefined) {
                this.onTabChange(realIndex);
            }
        },

        // =====================================================
        // CARGA DE DATOS
        // =====================================================
        async loadData() {
            await this.checkIntegration();
            await this.loadTrackings();
            this.loadTemplatesSilently();
        },

        async loadTemplatesSilently() {
            try {
                await this.$store.dispatch('trackingTemplates/get');
            } catch (_) { /* silencioso */ }
        },

        async checkIntegration() {
            this.integrationAvailable = true;
            this.hasCheckedIntegration = true;
        },

        async loadTrackings() {
            this.isLoadingTrackings = true;

            try {
                const response = await this.$store.dispatch('contactTrackings/fetch', {
                    contactId: this.contactId,
                    conversationId: this.currentChat.display_id,
                });

                this.localTrackings = this.normalizeResponse(response);
            } catch (error) {
                console.error('Error loading trackings:', error);
                useAlert('Error al cargar seguimientos');
                this.localTrackings = [];
            } finally {
                this.isLoadingTrackings = false;
            }
        },

        normalizeResponse(response) {
            return normalizeTrackingsResponse(response);
        },

        // =====================================================
        // HANDLERS DE ACCIONES
        // =====================================================
        // async handleSubmit(formData) {
        //     try {
        //         const payload = {
        //             ...formData,
        //             whatsapp_templates: this.isWhatsAppChannel ? this.whatsappTemplates : null,
        //         };

        //         if (this.editingTracking) {
        //             await this.updateTracking(payload);
        //         } else {
        //             await this.createTracking(payload);
        //         }

        //         this.editingTracking = null;
        //         this.activeTab = this.getTrackingsTabIndex;
        //         await this.loadTrackings();
        //     } catch (error) {
        //         const errorMessage = error.response?.data?.errors?.join(', ') ||
        //             error.response?.data?.error ||
        //             error.message ||
        //             'Ocurrió un error';
        //         useAlert(errorMessage);
        //     }
        // },
        async handleSubmit(formData) {
            try {
                const maxAttempts = formData.max_attempts || this.maxAttempts;

                // ⭐ VALIDAR PLANTILLAS WHATSAPP
                if (this.isWhatsAppChannel) {
                    const templatesCount = this.whatsappTemplates.filter(t => t && t.trim()).length;

                    // Si hay alguna plantilla configurada, todas deben estar presentes
                    if (templatesCount > 0 && templatesCount < maxAttempts) {
                        this.templateWarningMessage = `Tienes ${templatesCount} de ${maxAttempts} plantillas configuradas.`;
                        this.showTemplateWarning = true;
                        return;
                    }

                    // Verificar que no haya "huecos" (plantillas vacías entre las configuradas)
                    if (templatesCount > 0) {
                        for (let i = 0; i < maxAttempts; i++) {
                            if (!this.whatsappTemplates[i] || !this.whatsappTemplates[i].trim()) {
                                this.templateWarningMessage = `La plantilla del intento ${i + 1} está vacía.`;
                                this.showTemplateWarning = true;
                                return;
                            }
                        }
                    }
                }

                // ⭐ CONSTRUIR PAYLOAD CORRECTO
                const payload = {
                    contact_tracking: {
                        objective: formData.objective,
                        scheduled_for: formData.scheduled_for,
                        max_attempts: maxAttempts,
                        retry_interval_value: formData.retry_interval_value,
                        retry_interval_unit: formData.retry_interval_unit,
                        inbox_id: formData.inbox_id,

                        // ⭐ NO enviar conversation_id - currentChat.id es display_id, no el ID real
                        // TODO: Buscar el campo correcto con el ID real de la conversación
                        // conversation_id: this.currentChat?.id || null,

                        ai_context: formData.ai_context || null,
                        complementary_prompt: formData.complementary_prompt || null,  // ⭐ NUEVO: Instrucciones para preguntas

                        // ⭐ Incluir plantillas WhatsApp si es canal WhatsApp
                        whatsapp_templates: this.isWhatsAppChannel ? this.whatsappTemplates : []
                    }
                };

                console.log('📤 Payload a enviar:', payload);
                console.log('📤 currentChat:', this.currentChat);
                console.log('📤 currentChat.id:', this.currentChat?.id);
                console.log('📤 conversationId prop:', this.conversationId);

                if (this.editingTracking) {
                    await this.updateTracking(payload.contact_tracking);
                } else {
                    await this.createTracking(payload.contact_tracking);
                }

                // ✅ RESETEAR SOLO SI FUE EXITOSO
                this.editingTracking = null;
                this.isCreatingNew = false;
                this.whatsappTemplates = ['', '', ''];

                // Resetear formulario hijo
                if (this.$refs.trackingFormRef?.resetForm) {
                    this.$refs.trackingFormRef.resetForm();
                }

                this.activeTab = 0; // Volver al tab de Lista
                await this.loadTrackings();

            } catch (error) {
                console.error('❌ Error en handleSubmit:', error);
                console.error('❌ Error response:', error.response?.data);

                const errorMessage = error.response?.data?.errors?.join(', ') ||
                    error.response?.data?.error ||
                    error.message ||
                    'Ocurrió un error';
                useAlert(errorMessage);
            }
        },

        async createTracking(payload) {
            const result = await this.$store.dispatch('contactTrackings/create', {
                contactId: this.contactId,
                contact_tracking: payload,
            });

            if (result?.id) {
                this.localTrackings.push(result);
            }

            useAlert('Seguimiento creado correctamente');
        },

        async updateTracking(payload) {
            const result = await this.$store.dispatch('contactTrackings/update', {
                contactId: this.contactId,
                trackingId: this.editingTracking.id,
                contact_tracking: payload,
            });

            const index = this.localTrackings.findIndex(t => t.id === this.editingTracking.id);
            if (index !== -1) {
                this.$set(this.localTrackings, index, result);
            }

            useAlert('Seguimiento actualizado correctamente');
        },

        handleAddNew() {
            this.isCreatingNew = true;
            this.editingTracking = null;  // ⭐ Esto dispara el watcher que resetea el formulario
            this.duplicateSourceTracking = null;
            this.whatsappTemplates = ['', '', ''];
            this.maxAttempts = 3;

            // Resetear formulario hijo explícitamente
            this.$nextTick(() => {
                if (this.$refs.trackingFormRef?.resetForm) {
                    this.$refs.trackingFormRef.resetForm();
                }
            });

            // Cambiar al tab de Captura de Seguimiento
            this.activeTab = 1;
        },

        handleEdit(tracking) {
            this.editingTracking = tracking;
            this.isCreatingNew = false;
            this.duplicateSourceTracking = null;
            this.whatsappTemplates = tracking.whatsapp_templates || ['', '', ''];
            this.maxAttempts = tracking.max_attempts || 3;
            // Cambiar al tab de Captura de Seguimiento
            this.activeTab = 1;
        },

        handleDuplicate(tracking) {
            this.editingTracking = null;  // Asegura que se creará nuevo (no update)
            this.isCreatingNew = false;
            this.duplicateSourceTracking = tracking;
            this.maxAttempts = tracking.max_attempts || 3;
            this.whatsappTemplates = tracking.whatsapp_templates
                ? [...tracking.whatsapp_templates]
                : ['', '', ''];
            // Cambiar al tab de Captura de Seguimiento
            this.activeTab = 1;
        },

        handleCancelEdit() {
            // Volver a la lista de seguimientos
            this.returnToList();
        },

        async handlePause(trackingId) {
            try {
                await this.$store.dispatch('contactTrackings/pause', {
                    contactId: this.contactId,
                    trackingId,
                });
                useAlert('Seguimiento pausado correctamente');
                await this.loadTrackings();
            } catch (error) {
                useAlert('Error al pausar seguimiento');
            }
        },

        handleResume(trackingId) {
            // Buscar el tracking para mostrar info en el modal
            const tracking = this.localTrackings.find(t => t.id === trackingId);
            if (tracking) {
                this.trackingToResume = tracking;
                this.showResumeModal = true;
            }
        },

        handleResumeModalClose() {
            this.showResumeModal = false;
            this.trackingToResume = null;
        },

        async handleResumeSuccess() {
            this.showResumeModal = false;
            this.trackingToResume = null;
            await this.loadTrackings();
        },

        handleCancel(trackingId) {
            const tracking = this.localTrackings.find(t => t.id === trackingId);
            if (!tracking) return;
            this.trackingToCancel = tracking;
            this.showCancelModal = true;
        },

        handleCancelModalClose() {
            this.showCancelModal = false;
            this.trackingToCancel = null;
        },

        closeTemplateWarning() {
            this.showTemplateWarning = false;
            this.templateWarningMessage = '';
        },

        async handleCancelConfirm() {
            if (!this.trackingToCancel) return;
            this.isCancelling = true;
            try {
                await this.$store.dispatch('contactTrackings/cancel', {
                    contactId: this.contactId,
                    trackingId: this.trackingToCancel.id,
                });
                useAlert('Seguimiento cancelado correctamente');
                this.handleCancelModalClose();
                await this.loadTrackings();
            } catch (error) {
                useAlert('Error al cancelar seguimiento');
            } finally {
                this.isCancelling = false;
            }
        },

        async reloadTemplates() {
            this.isLoadingTemplates = true;
            try {
                await this.$store.dispatch('trackingTemplates/get');
            } finally {
                this.isLoadingTemplates = false;
            }
        },

        handleClearTemplate() {
            this.whatsappTemplates = ['', '', ''];
            this.maxAttempts = 3;
        },

        handleApplyTemplate(templateId) {
            const template = this.$store.getters['trackingTemplates/getTemplateById'](templateId);
            if (!template) return;

            // Poblar campos del formulario
            if (this.$refs.trackingFormRef?.applyFromTemplate) {
                this.$refs.trackingFormRef.applyFromTemplate(template);
            }

            // Poblar plantillas WhatsApp y número de intentos si la plantilla las tiene
            if (Array.isArray(template.whatsapp_templates) && template.whatsapp_templates.some(t => t)) {
                this.whatsappTemplates = [...template.whatsapp_templates];
                this.maxAttempts = template.whatsapp_templates.length;
            }
        },

        updateTemplates(templates) {
            this.whatsappTemplates = templates;
        },

        onClose() {
            this.$emit('close');
            this.editingTracking = null;
            this.isCreatingNew = false;
            this.duplicateSourceTracking = null;
            this.whatsappTemplates = ['', '', ''];
            this.activeTab = 0; // Resetear al tab inicial (Lista)
        },
    },
};
</script>

<style lang="scss" scoped>
.min-h-\[480px\] {
    min-height: 480px;
}

.callout.warning {
    @apply mb-4 p-4 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-md;

    p {
        @apply flex items-center gap-2 m-0 text-yellow-800 dark:text-yellow-200;
    }
}
</style>