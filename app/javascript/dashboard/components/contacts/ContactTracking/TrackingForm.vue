<!-- 
  ================================================================================
  proyecto@contact_tracking
  ================================================================================
  Componente: TrackingForm.vue
  Descripción: Formulario para crear/editar seguimientos
  Líneas: ~300
  ================================================================================
-->

<template>
    <form @submit.prevent="handleSubmit" class="space-y-2 flex-1 flex flex-col w-full">

            <!-- Aviso de duplicación desde seguimiento completado -->
            <div v-if="duplicateSource" class="flex items-center gap-2 p-3 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-200 dark:border-blue-700">
                <fluent-icon icon="copy" size="16" class="text-blue-600 dark:text-blue-400 shrink-0" />
                <p class="text-xs text-blue-800 dark:text-blue-200">
                    <strong>Continuación del seguimiento</strong>
                </p>
            </div>

            <!-- Aviso de edición restringida después del primer intento -->
            <div v-if="isAfterFirstAttempt" class="flex items-center gap-2 p-3 bg-yellow-50 dark:bg-yellow-900/20 rounded-lg border border-yellow-200 dark:border-yellow-700">
                <fluent-icon icon="warning" size="16" class="text-yellow-600 dark:text-yellow-400 shrink-0" />
                <p class="text-xs text-yellow-800 dark:text-yellow-200">
                    Ya se envió el primer intento. Solo puedes modificar el <strong>Objetivo</strong>, <strong>Contexto IA</strong> y <strong>Prompt Complementario</strong>.
                </p>
            </div>

            <!-- Selector de plantilla de seguimiento -->
            <div v-if="trackingTemplates.length > 0 && !isAfterFirstAttempt" class="flex items-center gap-2">
                <div class="flex-1 min-w-0 pt-1">
                    <MultiselectDropdown
                        :options="templateOptions"
                        :selected-item="selectedTemplateItem"
                        :has-thumbnail="false"
                        multiselector-title="Plantillas de seguimiento"
                        multiselector-placeholder="Seleccionar plantilla..."
                        no-search-result="No se encontraron plantillas"
                        input-placeholder="Buscar plantilla..."
                        @click="onSelectTemplate"
                    />
                </div>
                <woot-button
                    v-if="templateApplied"
                    variant="smooth"
                    color-scheme="alert"
                    @click="onClearTemplate"
                >
                    Limpiar
                </woot-button>
                <woot-button
                    variant="smooth"
                    color-scheme="secondary"
                    icon="arrow-clockwise"
                    :is-loading="isLoadingTemplates"
                    @click="$emit('reload-templates')"
                />
                <woot-button
                    variant="smooth"
                    :is-disabled="!selectedTemplateId"
                    @click="onApplyTemplate"
                >
                    Aplicar
                </woot-button>
            </div>

            <!-- Objetivo -->
            <woot-input v-model.trim="formData.objective" :label="$t('CONTACT_TRACKING.FORM.OBJECTIVE.LABEL')"
                :placeholder="$t('CONTACT_TRACKING.FORM.OBJECTIVE.PLACEHOLDER')" :class="{ error: errors.objective }"
                :error="errors.objective" type="text" @blur="validateField('objective')"
                @input="clearError('objective')" />

            
            <!-- Contexto IA y Prompt Complementario (en tabs) -->
            <div class="flex-1 flex flex-col">
                <!-- Tabs para Contexto y Prompt Complementario -->
                <woot-tabs
                    class="context-tabs [&_.tabs]:p-0 [&_.tabs]:mb-2"
                    :index="activeContextTab"
                    @change="onContextTabChange"
                >
                    <woot-tabs-item name="📝 Contexto" :show-badge="false" />
                    <woot-tabs-item name="💡 Prompt Complementario" :show-badge="false" />
                </woot-tabs>

                <!-- Tab 0: Contexto -->
                <div v-show="activeContextTab === 0">
                    <textarea v-model="formData.ai_context" rows="5"
                        :placeholder="$t('CONTACT_TRACKING.FORM.AI_CONTEXT.PLACEHOLDER')"
                        class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200"
                        :class="{ 'border-red-500 dark:border-red-500': errors.ai_context }"
                        @blur="validateField('ai_context')"
                        @input="clearError('ai_context')" />
                    <div class="flex justify-between items-center mt-1">
                        <span v-if="errors.ai_context" class="text-red-500 text-xs">
                            {{ errors.ai_context }}
                        </span>
                        <span v-else class="text-xs text-slate-500 dark:text-slate-400">
                            {{ $t('CONTACT_TRACKING.FORM.AI_CONTEXT.HELP') }}
                        </span>
                        <div class="flex gap-3">
                            <a v-if="originalAiContext" href="#"
                                class="text-xs text-slate-500 hover:text-slate-700 dark:hover:text-slate-300"
                                @click.prevent="restoreOriginal('ai_context')">
                                ↩ Restaurar original
                            </a>
                            <!-- [FEATURE:AI_LOADING_INDICATOR] - Botón con estado de carga -->
                            <a href="#"
                                class="text-xs inline-flex items-center gap-1"
                                :class="formData.ai_context && formData.ai_context.trim() && !isImprovingAI ? 'text-woot-500 hover:text-woot-600 cursor-pointer' : 'text-slate-300 dark:text-slate-600 cursor-not-allowed'"
                                @click.prevent="formData.ai_context && formData.ai_context.trim() && !isImprovingAI && improveWithAI('ai_context')">
                                <span v-if="isImprovingAI" class="inline-block w-4 h-4 border-2 border-woot-500 border-t-transparent rounded-full animate-spin"></span>
                                <span v-else>✨</span>
                                {{ isImprovingAI ? 'Procesando...' : 'Mejorar con IA' }}
                            </a>
                        </div>
                    </div>
                </div>

                <!-- Tab 1: Prompt Complementario -->
                <div v-show="activeContextTab === 1">
                    <textarea v-model="formData.complementary_prompt" rows="5"
                        placeholder="Instrucciones adicionales para responder preguntas del cliente sobre este seguimiento. Ejemplo: Precios, horarios de atención, información de contacto específica..."
                        class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200" />
                    <div class="flex justify-between items-center mt-1">
                        <span class="text-xs text-slate-500 dark:text-slate-400">
                            Este prompt se usará cuando el cliente haga preguntas relacionadas con el seguimiento.
                        </span>
                        <div class="flex gap-3">
                            <a v-if="originalComplementaryPrompt" href="#"
                                class="text-xs text-slate-500 hover:text-slate-700 dark:hover:text-slate-300"
                                @click.prevent="restoreOriginal('complementary_prompt')">
                                ↩ Restaurar original
                            </a>
                            <!-- [FEATURE:AI_LOADING_INDICATOR] - Botón con estado de carga -->
                            <a href="#"
                                class="text-xs inline-flex items-center gap-1"
                                :class="canGeneratePrompt && !isImprovingAI ? 'text-woot-500 hover:text-woot-600 cursor-pointer' : 'text-slate-300 dark:text-slate-600 cursor-not-allowed'"
                                @click.prevent="canGeneratePrompt && !isImprovingAI && improveWithAI('complementary_prompt')">
                                <span v-if="isImprovingAI" class="inline-block w-4 h-4 border-2 border-woot-500 border-t-transparent rounded-full animate-spin"></span>
                                <span v-else>✨</span>
                                {{ isImprovingAI ? 'Procesando...' : 'Generar Prompt con IA' }}
                            </a>
                        </div>
                    </div>
                </div>
            </div>


            <!-- Fecha y Hora + Intentos + Tiempo + Unidad -->
            <div class="flex gap-4">
                <!-- Fecha y Hora -->
                <label :class="{ error: errors.scheduled_for }" class="flex-1">
                    {{ $t('CONTACT_TRACKING.FORM.SCHEDULED_FOR.LABEL') }}
                    <span class="text-red-500">*</span>
                    <input v-model="formData.scheduled_for" type="datetime-local" :min="minDateTime"
                        :disabled="!!editingTracking || isAfterFirstAttempt"
                        class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200 dark:border-slate-600 rounded-md px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:bg-slate-100 dark:disabled:bg-slate-800"
                        :class="{ 'border-red-500 dark:border-red-500': errors.scheduled_for }"
                        @blur="validateField('scheduled_for')" @input="clearError('scheduled_for')" />
                    <span v-if="errors.scheduled_for" class="text-red-500 text-xs mt-1 block">
                        {{ errors.scheduled_for }}
                    </span>
                </label>

                <!-- Intentos -->
                <label class="flex-1">
                    <span class="text-sm font-semibold text-slate-700 dark:text-slate-300">
                        {{ $t('CONTACT_TRACKING.FORM.MAX_ATTEMPTS.LABEL') }}
                    </span>
                    <input v-model.number="formData.max_attempts" type="number" min="1" max="6"
                        :disabled="!!editingTracking || isAfterFirstAttempt"
                        class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border-2 border-slate-200 dark:border-slate-600 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:bg-slate-100 dark:disabled:bg-slate-800" />
                </label>

                <!-- Tiempo entre intentos -->
                <label class="flex-1">
                    <span class="text-sm font-semibold text-slate-700 dark:text-slate-300">
                        ⏱️ Tiempo entre intentos
                    </span>
                    <input v-model.number="formData.retry_interval_value" type="number" :min="getMinValue()"
                        :disabled="!!editingTracking || isAfterFirstAttempt"
                        class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border-2 border-slate-200 dark:border-slate-600 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:bg-slate-100 dark:disabled:bg-slate-800"
                        :class="{ 'border-red-500': !intervalValidation.isValid }" placeholder="Ej: 30"
                        @blur="validateIntervalField" />
                </label>

                <!-- Selector de unidad -->
                <label class="flex-1">
                    <span class="text-sm font-semibold text-slate-700 dark:text-slate-300">
                        Intervalo
                    </span>
                    <select v-model="formData.retry_interval_unit" @change="adjustMinValue"
                        :disabled="!!editingTracking || isAfterFirstAttempt"
                        class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border-2 border-slate-200 dark:border-slate-600 rounded-lg px-3 py-2 text-sm font-medium focus:outline-none focus:ring-1 focus:ring-woot-200 focus:border-woot-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:bg-slate-100 dark:disabled:bg-slate-800">
                        <option value="minutes">Minutos</option>
                        <option value="hours">Horas</option>
                        <option value="days">Días</option>
                    </select>
                </label>
            </div>

            <!-- Mensaje de error del intervalo -->
            <div v-if="!intervalValidation.isValid" class="mt-2">
                <p class="text-xs text-red-600 dark:text-red-400 font-semibold">
                    {{ intervalValidation.message }}
                </p>
            </div>

            <!-- Helper text -->
            <div v-else class="mt-2">
                <p class="text-xs text-slate-500 dark:text-slate-400">
                    💡 {{ getIntervalHelpText() }}
                </p>
            </div>

            <!-- Preview del timeline -->
            <!-- <div 
                v-if="formData.max_attempts > 1"
                class="mt-3 p-3 bg-slate-50 dark:bg-slate-800 rounded-lg"
            >
                <p class="text-xs font-semibold text-slate-700 dark:text-slate-300 mb-2">
                    📊 Timeline de intentos:
                </p>
                <div class="space-y-1">
                    <div 
                        v-for="idx in formData.max_attempts" 
                        :key="idx"
                        class="text-xs text-slate-600 dark:text-slate-400"
                    >
                        <span class="font-semibold">Intento {{ idx }}:</span>
                        {{ getAttemptTime(idx - 1) }}
                    </div>
                </div>
            </div> -->

            

            <!-- Botones -->
            <div
                class="flex justify-between items-center gap-2 pt-4 border-t border-slate-200 dark:border-slate-700 mt-auto">
                <div>
                    <woot-button v-if="editingTracking" variant="clear" color-scheme="alert" type="button" @click.prevent="handleCancel">
                        <fluent-icon icon="dismiss-circle" size="16" />
                        Cancelar edición
                    </woot-button>
                </div>

                <div class="flex gap-2">
                    <woot-button variant="clear" type="button" @click.prevent="handleClose">
                        Cancelar
                    </woot-button>

                    <woot-button :is-loading="isCreating" :is-disabled="!isFormValid || !integrationAvailable"
                        type="submit">
                        <fluent-icon icon="add" size="16" />
                        {{ editingTracking ? 'Actualizar' : 'Crear Seguimiento' }}
                    </woot-button>
                </div>
            </div>
    </form>
</template>

<script>
import { useTrackingForm } from '../../../composables/useTrackingForm';
import { formatDateTime, getAttemptEstimatedTime } from '../../../helper/trackingHelpers';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';

export default {
    name: 'TrackingForm',

    components: {
        MultiselectDropdown,
    },

    props: {
        contactId: {
            type: Number,
            required: true,
        },
        trackingTemplates: {
            type: Array,
            default: () => [],
        },
        isLoadingTemplates: {
            type: Boolean,
            default: false,
        },
        conversationId: {
            type: Number,
            default: null,
        },
        currentChat: {
            type: Object,
            default: () => ({}),
        },
        integrationAvailable: {
            type: Boolean,
            default: true,
        },
        editingTracking: {
            type: Object,
            default: null,
        },
        duplicateSource: {
            type: Object,
            default: null,
        },
    },

    emits: ['submit', 'cancel', 'close', 'update:maxAttempts', 'reload-templates', 'apply-template', 'clear-template'],

    data() {
        return {
            activeContextTab: 0,
            selectedTemplateId: null,
            templateApplied: false,  // ⭐ Tab activo: 0 = Contexto, 1 = Prompt Complementario
            originalAiContext: null,  // Guarda texto original antes de mejorar con IA
            originalComplementaryPrompt: null,  // Guarda texto original antes de mejorar con IA
            // [FEATURE:AI_LOADING_INDICATOR] - Estado de carga para botones de IA
            isImprovingAI: false,
        };
    },

    computed: {
        isAfterFirstAttempt() {
            return (this.editingTracking?.attempt_count ?? 0) > 0;
        },
        templateOptions() {
            return this.trackingTemplates.map(t => ({ id: t.id, name: t.name }));
        },
        selectedTemplateItem() {
            if (!this.selectedTemplateId) return {};
            const tpl = this.trackingTemplates.find(t => t.id === this.selectedTemplateId);
            return tpl ? { id: tpl.id, name: tpl.name } : {};
        },
        canGeneratePrompt() {
            const hasObjective = this.formData.objective && this.formData.objective.trim();
            const hasContext = this.formData.ai_context && this.formData.ai_context.trim();
            return hasObjective && hasContext;
        },
    },

    watch: {
        editingTracking() {
            // Siempre iniciar en tab Contexto al crear/editar seguimiento
            this.activeContextTab = 0;
            // Limpiar textos originales guardados
            this.originalAiContext = null;
            this.originalComplementaryPrompt = null;
        },
        duplicateSource(newTracking) {
            if (newTracking) {
                this.loadDuplicateData(newTracking);
                this.activeContextTab = 0;
                this.originalAiContext = null;
                this.originalComplementaryPrompt = null;
            }
        },
    },

    setup(props, { emit }) {
        const {
            formData,
            errors,
            isCreating,
            minDateTime,
            intervalValidation,
            isFormValid,
            retry_interval_in_minutes,
            validateField,
            clearError,
            getMinValue,
            adjustMinValue,
            validateIntervalField,
            getIntervalHelpText,
            submitForm,
            resetForm,  // ⭐ Extraer resetForm del composable
            loadDuplicateData,
        } = useTrackingForm(props, emit);

        // Expuesto vía ref para que el modal padre pueda cargar una plantilla
        const applyFromTemplate = (template) => {
            if (!template) return;
            formData.value.objective = template.objective || '';
            formData.value.ai_context = template.ai_context || '';
            formData.value.complementary_prompt = template.complementary_prompt || '';
        };

        const clearTemplateFields = () => {
            formData.value.objective = '';
            formData.value.ai_context = '';
            formData.value.complementary_prompt = '';
        };

        return {
            formData,
            errors,
            isCreating,
            minDateTime,
            intervalValidation,
            isFormValid,
            retry_interval_in_minutes,
            validateField,
            clearError,
            getMinValue,
            adjustMinValue,
            validateIntervalField,
            getIntervalHelpText,
            submitForm,
            resetForm,
            loadDuplicateData,
            applyFromTemplate,
            clearTemplateFields,
        };
    },

    methods: {
        onContextTabChange(index) {
            this.activeContextTab = index;
        },

        onSelectTemplate(item) {
            this.selectedTemplateId = item?.id || null;
        },

        onApplyTemplate() {
            if (!this.selectedTemplateId) return;
            this.$emit('apply-template', this.selectedTemplateId);
            this.selectedTemplateId = null;
            this.templateApplied = true;
        },

        onClearTemplate() {
            this.clearTemplateFields();
            this.selectedTemplateId = null;
            this.templateApplied = false;
            this.$emit('clear-template');
        },

        async improveWithAI(field) {
            // [FEATURE:AI_LOADING_INDICATOR] - Evitar múltiples clicks
            if (this.isImprovingAI) return;

            const isGeneratePrompt = field === 'complementary_prompt';
            const mode = isGeneratePrompt ? 'generate_prompt' : 'improve';

            // Para generar prompt: usar el texto actual o el contexto como base
            let text;
            if (isGeneratePrompt) {
                text = (this.formData.complementary_prompt || '').trim() || (this.formData.ai_context || '').trim();
            } else {
                text = (this.formData[field] || '').trim();
            }

            if (!text) return;

            // Guardar original antes de mejorar
            if (field === 'ai_context') {
                this.originalAiContext = this.formData.ai_context;
            } else if (field === 'complementary_prompt') {
                this.originalComplementaryPrompt = this.formData.complementary_prompt;
            }

            // [FEATURE:AI_LOADING_INDICATOR] - Activar estado de carga
            this.isImprovingAI = true;

            try {
                const payload = {
                    contactId: this.contactId,
                    text,
                    mode
                };

                // Para generar prompt, enviar contexto y objetivo como datos adicionales
                if (isGeneratePrompt) {
                    payload.context = (this.formData.ai_context || '').trim();
                    payload.objective = (this.formData.objective || '').trim();
                }

                const response = await this.$store.dispatch('contactTrackings/improveText', payload);
                if (response?.improved_text) {
                    this.formData[field] = response.improved_text;
                }
            } catch (error) {
                console.error('Error mejorando texto con IA:', error);
                if (field === 'ai_context') {
                    this.originalAiContext = null;
                } else if (field === 'complementary_prompt') {
                    this.originalComplementaryPrompt = null;
                }
            } finally {
                // [FEATURE:AI_LOADING_INDICATOR] - Desactivar estado de carga
                this.isImprovingAI = false;
            }
        },

        restoreOriginal(field) {
            if (field === 'ai_context' && this.originalAiContext) {
                this.formData.ai_context = this.originalAiContext;
                this.originalAiContext = null;
            } else if (field === 'complementary_prompt' && this.originalComplementaryPrompt) {
                this.formData.complementary_prompt = this.originalComplementaryPrompt;
                this.originalComplementaryPrompt = null;
            }
        },

        getAttemptTime(attemptIndex) {
            return getAttemptEstimatedTime(
                attemptIndex,
                this.formData.retry_interval_value,
                this.formData.retry_interval_unit
            );
        },

        // handleSubmit() {
        //     const message = this.editingTracking
        //         ? `¿Estás seguro de actualizar este seguimiento?\n\nObjetivo: ${this.formData.objective}`
        //         : `¿Estás seguro de crear este seguimiento?\n\nObjetivo: ${this.formData.objective}\nFecha: ${formatDateTime(this.formData.scheduled_for)}`;

        //     if (confirm(message)) {
        //         this.submitForm();
        //     }
        // },

        async handleSubmit(event) {
            // ✅ CRÍTICO: Prevenir comportamiento por defecto del formulario
            if (event) {
                event.preventDefault();
                event.stopPropagation();
            }

            // ✅ Validar ANTES de enviar
            if (!this.isFormValid) {
                console.warn('⚠️ Formulario inválido, no se puede enviar');
                return;
            }

            // ✅ Enviar directamente sin confirmación
            try {
                console.log('✅ Ejecutando submitForm...');
                await this.submitForm();
            } catch (error) {
                console.error('❌ Error en submitForm:', error);
            }
        },
        
        handleCancel(event) {
            if (event) {
                event.preventDefault();
                event.stopPropagation();
            }
            this.$emit('cancel');
        },

        handleClose(event) {
            if (event) {
                event.preventDefault();
                event.stopPropagation();
            }
            this.$emit('close');
        },


        formatDateTime,
    },
};
</script>

<style lang="scss" scoped>
.ai-section {
    padding: var(--space-normal);
    background: var(--color-background-light);
    border: 1px solid var(--color-border);
    border-radius: var(--border-radius-normal);
}

input,
select,
textarea {
    height: auto !important;
    font-size: 14px !important;
}

input[type="datetime-local"],
input[type="number"],
select {
    height: 38px !important;
}
</style>