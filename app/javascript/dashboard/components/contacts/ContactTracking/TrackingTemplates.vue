<!-- 
  ================================================================================
  proyecto@contact_tracking
  ================================================================================
  Componente: TrackingTemplates.vue
  Descripción: Gestión de plantillas WhatsApp por intento
  Líneas: ~350
  ================================================================================
-->

<template>
    <div class="space-y-3 flex-1 flex flex-col">

        <!-- Sin plantillas disponibles -->
        <div 
            v-if="availableTemplates.length === 0 && !isLoadingTemplates"
            class="flex items-center justify-center flex-1 bg-slate-50 dark:bg-slate-800 rounded-lg border-2 border-dashed border-slate-300 dark:border-slate-600"
        >
            <div class="text-center px-8 py-12">
                <fluent-icon icon="warning" size="56" class="text-yellow-500 mb-4" />
                <h4 class="text-lg font-semibold text-slate-700 dark:text-slate-300 mb-2">
                    No hay plantillas disponibles
                </h4>
                <p class="text-sm text-slate-600 dark:text-slate-400">
                    Este inbox no tiene plantillas de WhatsApp configuradas.<br>
                    Contacta al administrador para agregar plantillas en Meta Business.
                </p>
            </div>
        </div>

        <!-- Loading -->
        <div v-else-if="isLoadingTemplates" class="flex items-center justify-center flex-1">
            <spinner size="small" />
        </div>

        <!-- Sub-tabs por intento -->
        <div v-else class="flex-1 flex flex-col">
            <woot-tabs 
                class="font-medium [&_.tabs]:p-0 mb-4 attempt-tabs"
                :index="activeTemplateTab" 
                @change="onTemplateTabChange"
            >
                <woot-tabs-item
                    v-for="(template, index) in localTemplates"
                    :key="index"
                    :name="getAttemptTabName(index, maxAttempts)"
                />
            </woot-tabs>

            <!-- Contenido del sub-tab actual -->
            <div class="flex-1 flex flex-col space-y-2 overflow-y-auto">
                <div 
                    v-for="(template, index) in localTemplates"
                    v-show="activeTemplateTab === index" 
                    :key="index"
                    class="flex-1 flex flex-col space-y-2"
                >
                    <!-- Layout de dos columnas -->
                    <div class="grid grid-cols-1 lg:grid-cols-[45%_54%] gap-2">
                        
                        <!-- Columna Izquierda: Selector + Info -->
                        <div class="space-y-2">

                            <!-- Selector de plantilla -->
                            <div class="template-selector-card">
                                <label class="text-xs font-semibold text-slate-700 dark:text-slate-300 mb-2 block">
                                    📱 Plantilla para este intento:
                                </label>
                                <select 
                                    v-model="localTemplates[index]"
                                    class="w-full bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border-1 border-slate-200 dark:border-slate-600 rounded-lg px-5 py-2 text-sm font-normal focus:outline-none focus:ring-1 focus:ring-green-500 focus:border-green-500 transition-all hover:border-green-400"
                                    :disabled="isLoadingTemplates"
                                    @change="updateTemplates"
                                >
                                    <option value="">📝 Sin plantilla - Mensaje normal</option>
                                    <option 
                                        v-for="tpl in availableTemplates" 
                                        :key="tpl.id"
                                        :value="tpl.name"
                                    >
                                        📱 {{ tpl.name }} ({{ tpl.language }})
                                    </option>
                                </select>
                                <p class="text-[10px] text-slate-500 dark:text-slate-400 mt-1.5">
                                    💡 Usa "Sin plantilla" si la ventana de 24h está abierta
                                </p>
                            </div>

                            <!-- Info box -->
                            <div class="info-box mt-4">
                                <fluent-icon icon="info" size="20" class="text-blue-600 flex-shrink-0" />
                                <div class="text-sm text-slate-600 dark:text-slate-400">
                                    <strong class="text-slate-800 dark:text-slate-200">Importante:</strong>
                                    <ul class="mt-2 space-y-1 list-disc list-inside">
                                        <li>Las plantillas deben estar aprobadas por Meta Business</li>
                                        <li>Si no seleccionas plantilla, se enviará mensaje normal (solo válido dentro de ventana de 24h)</li>
                                        <li>Puedes combinar plantillas y mensajes normales según el intento</li>
                                    </ul>
                                </div>
                            </div>

                        </div>

                        <!-- Columna Derecha: Preview -->
                        <div>

                            <!-- Preview de la plantilla seleccionada -->
                            <template-preview
                                v-if="localTemplates[index]"
                                :template-name="localTemplates[index]"
                                :available-templates="availableTemplates"
                            />

                            <!-- Mensaje cuando no hay plantilla -->
                            <div 
                                v-else
                                class="no-template-message h-full flex flex-col items-center justify-center p-6"
                            >
                                <fluent-icon icon="chat-empty" size="40" class="text-slate-300 dark:text-slate-600 mb-2" />
                                <h4 class="text-sm font-semibold text-slate-600 dark:text-slate-400 mb-1.5 text-center">
                                    Sin plantilla
                                </h4>
                                <p class="text-xs text-slate-500 dark:text-slate-500 text-center max-w-xs leading-relaxed">
                                    Se usará un mensaje normal con IA. Solo funciona con ventana de 24h abierta.
                                </p>
                            </div>

                        </div>

                    </div>

                </div>
            </div>
        </div>

    </div>
</template>

<script>
import { mapGetters } from 'vuex';
import Spinner from 'shared/components/Spinner.vue';
import TemplatePreview from './TemplatePreview.vue';
import { extractTemplateBody } from '../../../helper/trackingHelpers';

export default {
    name: 'TrackingTemplates',
    
    components: {
        Spinner,
        TemplatePreview,
    },

    props: {
        inboxId: {
            type: Number,
            required: true,
        },
        maxAttempts: {
            type: Number,
            default: 3,
        },
        templates: {
            type: Array,
            default: () => ['', '', ''],
        },
    },

    emits: ['update:templates'],

    data() {
        return {
            localTemplates: [...this.templates],
            availableTemplates: [],
            isLoadingTemplates: false,
            activeTemplateTab: 0,
        };
    },

    computed: {
        ...mapGetters({
            inboxes: 'inboxes/getInboxes',
        }),
    },

    watch: {
        templates: {
            handler(newTemplates) {
                this.localTemplates = [...newTemplates];
            },
            deep: true,
        },

        maxAttempts: {
            immediate: true,
            handler(newMax) {
                this.adjustTemplatesArray(newMax);
            },
        },

        inboxId: {
            immediate: true,
            async handler(newInboxId) {
                if (newInboxId) {
                    await this.loadWhatsAppTemplates();
                }
            },
        },
    },

    methods: {
        async loadWhatsAppTemplates() {
            this.isLoadingTemplates = true;

            try {
                // 1. Forzar carga de inboxes si no están disponibles
                if (!this.inboxes || this.inboxes.length === 0) {
                    console.log('[TrackingTemplates] Inboxes no disponibles, forzando carga...');
                    await this.$store.dispatch('inboxes/get');
                }

                // 2. Usar el getter optimizado del store que busca en message_templates
                //    Y en additional_attributes.message_templates, además filtra plantillas con media
                const templates = this.$store.getters['inboxes/getWhatsAppTemplates'](this.inboxId);

                if (templates && templates.length > 0) {
                    this.availableTemplates = templates.map(template => ({
                        id: template.id || template.name,
                        name: template.name,
                        language: template.language,
                        status: template.status,
                        category: template.category,
                        components: template.components || [],
                        body: extractTemplateBody(template),
                    }));

                    console.log(`[TrackingTemplates] Cargadas ${this.availableTemplates.length} plantillas para inbox ${this.inboxId}`);
                } else {
                    console.warn('[TrackingTemplates] No se encontraron plantillas para el inbox', this.inboxId);
                    this.availableTemplates = [];
                }
            } catch (error) {
                console.error('[TrackingTemplates] Error loading templates:', error);
                this.availableTemplates = [];
            } finally {
                this.isLoadingTemplates = false;
            }
        },

        onTemplateTabChange(index) {
            this.activeTemplateTab = index;
        },

        getAttemptTabName(index, maxAttempts) {
            const number = index + 1;
            if (index === 0) {
                return `🎯 Primer contacto (${number}/${maxAttempts})`;
            } else if (index === maxAttempts - 1) {
                return `🔴 Último intento (${number}/${maxAttempts})`;
            } else {
                return `🔄 Seguimiento (${number}/${maxAttempts})`;
            }
        },

        adjustTemplatesArray(attempts) {
            // ⭐ LÍMITE: Máximo 6 tabs de plantillas
            const MAX_TEMPLATE_TABS = 6;
            const limitedAttempts = Math.min(attempts, MAX_TEMPLATE_TABS);

            if (attempts > MAX_TEMPLATE_TABS) {
                console.warn(`[TrackingTemplates] Intentos limitados a máximo ${MAX_TEMPLATE_TABS} (se intentó usar ${attempts})`);
            }

            const currentLength = this.localTemplates.length;

            if (currentLength < limitedAttempts) {
                while (this.localTemplates.length < limitedAttempts) {
                    this.localTemplates.push('');
                }
            } else if (currentLength > limitedAttempts) {
                this.localTemplates.splice(limitedAttempts);
            }

            this.updateTemplates();
        },

        updateTemplates() {
            this.$emit('update:templates', [...this.localTemplates]);
        },
    },
};
</script>

<style lang="scss" scoped>
.attempt-tabs {
    border-bottom: 2px solid var(--color-border);
    margin-bottom: var(--space-normal);
}

.template-selector-card {
    padding: var(--space-normal);
    background: var(--color-background-light);
    border: 1px solid var(--color-border);
    border-radius: var(--border-radius-normal);
}

.info-box {
    display: flex;
    align-items: flex-start;
    gap: var(--space-small);
    padding: var(--space-normal);
    background: rgba(59, 130, 246, 0.1);
    border-left: 3px solid #3b82f6;
    border-radius: var(--border-radius-small);
}

.no-template-message {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: var(--space-larger);
    background: var(--color-background-light);
    border: 2px dashed var(--color-border);
    border-radius: var(--border-radius-normal);
    min-height: 300px;
}

select {
    height: 38px !important;
    font-size: 14px !important;
}
</style>