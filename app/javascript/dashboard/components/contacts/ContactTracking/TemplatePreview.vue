<!--
  ================================================================================
  proyecto@contact_tracking
  ================================================================================
  Componente: TemplatePreview.vue
  Descripción: Preview visual de plantilla WhatsApp estilo teléfono
  Versión: 2.0 - Con reemplazo de variables Liquid
  ================================================================================
-->

<template>
    <div class="template-preview-card h-full">

        <!-- Header -->
        <div class="preview-header">
            <fluent-icon icon="eye" size="16" class="text-green-600" />
            <span class="text-xs font-semibold text-slate-700 dark:text-slate-300">
                Vista previa
            </span>
            <!-- Toggle para ver variables -->
            <button
                class="ml-auto text-[10px] px-2 py-0.5 rounded bg-slate-200 dark:bg-slate-700 hover:bg-slate-300 dark:hover:bg-slate-600 transition-colors"
                @click="showRawVariables = !showRawVariables"
            >
                {{ showRawVariables ? '👁️ Ver datos' : '🔧 Ver variables' }}
            </button>
        </div>

        <!-- Preview tipo teléfono -->
        <div class="preview-phone">

            <!-- Header del teléfono -->
            <div class="phone-header py-1 px-2">
                <div class="flex items-center gap-3">
                    <div class="w-7 h-7 rounded-full bg-green-600 flex items-center justify-center">
                        <fluent-icon icon="chat-multiple" size="10" class="text-white" />
                    </div>
                    <div>
                        <p class="text-[11px] font-semibold text-slate-800 dark:text-slate-200">
                            WhatsApp Business
                        </p>
                    </div>
                    <div>
                        <p class="text-[9px] text-slate-500 dark:text-slate-400">
                            En línea
                        </p>
                    </div>
                </div>
            </div>

            <!-- Body del teléfono -->
            <div class="phone-body p-3">
                <div class="message-bubble">
                    <div
                        class="message-content text-xs leading-relaxed"
                        v-html="formattedPreviewText"
                    />
                    <div class="message-time text-[8px]">
                        {{ currentTime }} ✓✓
                    </div>
                </div>
            </div>
        </div>

        <!-- ⭐ Resumen de variables -->
        <div v-if="previewResult.replacements.length > 0" class="variables-summary mt-3">
            <div class="text-[10px] font-semibold text-slate-600 dark:text-slate-400 mb-1">
                📊 Variables detectadas:
            </div>
            <div class="flex flex-wrap gap-1">
                <span
                    v-for="(repl, idx) in previewResult.replacements"
                    :key="idx"
                    class="variable-badge"
                    :class="repl.resolved ? 'resolved' : 'unresolved'"
                    :title="repl.resolved ? `Valor: ${repl.value}` : 'Sin valor - falta dato'"
                >
                    {{ repl.resolved ? '✅' : '⚠️' }} {{ repl.variable }}
                </span>
            </div>
        </div>

        <!-- Metadata -->
        <div class="template-meta space-y-1 mt-3">
            <div class="meta-item">
                <span class="meta-label text-[10px]">Plantilla:</span>
                <span class="meta-value text-[10px] truncate">{{ templateName }}</span>
            </div>
            <div class="meta-item">
                <span class="meta-label text-[10px]">Idioma:</span>
                <span class="meta-value text-[10px]">{{ templateLanguage }}</span>
            </div>
            <div class="meta-item">
                <span class="meta-label text-[10px]">Estado:</span>
                <span class="meta-value text-[10px] text-green-600">✅ Aprobada</span>
            </div>
            <div v-if="hasUnresolvedVariables" class="meta-item">
                <span class="meta-label text-[10px] text-amber-600">⚠️ Alerta:</span>
                <span class="meta-value text-[10px] text-amber-600">Variables sin resolver</span>
            </div>
        </div>

    </div>
</template>

<script>
import {
    replaceTemplateVariables,
    replaceTemplateVariablesWithData,
    getCurrentTime
} from '../../../helper/trackingHelpers';

export default {
    name: 'TemplatePreview',

    props: {
        templateName: {
            type: String,
            required: true,
        },
        availableTemplates: {
            type: Array,
            default: () => [],
        },
        // ⭐ NUEVO: Datos del contacto para reemplazar variables
        contactData: {
            type: Object,
            default: () => ({}),
        },
        // ⭐ NUEVO: Datos del tracking (objetivo, contexto)
        trackingData: {
            type: Object,
            default: () => ({}),
        },
    },

    data() {
        return {
            showRawVariables: false,
        };
    },

    computed: {
        template() {
            return this.availableTemplates.find(t => t.name === this.templateName);
        },

        templateLanguage() {
            return this.template?.language || 'es';
        },

        rawTemplateText() {
            if (!this.template) return 'Plantilla no encontrada';
            return this.template.body || 'Sin contenido';
        },

        previewResult() {
            if (!this.template) {
                return { text: 'Plantilla no encontrada', replacements: [] };
            }

            const bodyText = this.template.body || 'Sin contenido';

            // Si hay datos de contacto, usar el nuevo método
            if (this.contactData && Object.keys(this.contactData).length > 0) {
                return replaceTemplateVariablesWithData(bodyText, this.contactData, this.trackingData);
            }

            // Fallback al método antiguo
            return {
                text: replaceTemplateVariables(bodyText),
                replacements: []
            };
        },

        formattedPreviewText() {
            if (this.showRawVariables) {
                // Mostrar variables resaltadas en el texto original
                return this.highlightVariables(this.rawTemplateText);
            }

            // Mostrar texto con datos reemplazados y resaltados
            return this.highlightReplacedValues(this.previewResult.text, this.previewResult.replacements);
        },

        hasUnresolvedVariables() {
            return this.previewResult.replacements.some(r => !r.resolved);
        },

        currentTime() {
            return getCurrentTime();
        },
    },

    methods: {
        // Resalta las variables en el texto original
        highlightVariables(text) {
            if (!text) return '';

            // Resaltar variables Liquid (soporta números en nombres: factura_monto_568)
            let result = text.replace(
                /\{\{([a-z_][a-z0-9_]*(?:\.[a-z_][a-z0-9_]*)+)\}\}/gi,
                '<span class="variable-highlight liquid">{{$1}}</span>'
            );

            // Resaltar variables numeradas
            result = result.replace(
                /\{\{(\d+)\}\}/g,
                '<span class="variable-highlight numbered">{{$1}}</span>'
            );

            return result.replace(/\n/g, '<br>');
        },

        // Resalta los valores reemplazados
        highlightReplacedValues(text, replacements) {
            if (!text) return '';

            let result = text;

            // Resaltar valores que fueron reemplazados exitosamente
            replacements.forEach(repl => {
                if (repl.resolved && repl.value) {
                    const escapedValue = repl.value.toString().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                    const regex = new RegExp(escapedValue, 'g');
                    result = result.replace(regex, `<span class="value-highlight resolved">${repl.value}</span>`);
                }
            });

            // Resaltar placeholders no resueltos
            result = result.replace(
                /\[([^\]]+)\]/g,
                '<span class="value-highlight unresolved">[$1]</span>'
            );

            return result.replace(/\n/g, '<br>');
        },
    },
};
</script>

<style lang="scss" scoped>
.template-preview-card {
    padding: var(--space-normal);
    background: var(--color-background-light);
    border: 1px solid var(--color-border);
    border-radius: var(--border-radius-normal);
}

.preview-header {
    display: flex;
    align-items: center;
    gap: var(--space-smaller);
    margin-bottom: var(--space-normal);
    padding-bottom: var(--space-small);
    border-bottom: 1px solid var(--color-border);
}

.preview-phone {
    background: white;
    border: 2px solid #e5e7eb;
    border-radius: 24px;
    overflow: hidden;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.1);
    max-width: 400px;
    margin: 0 auto;
}

.phone-header {
    padding: var(--space-normal);
    background: linear-gradient(135deg, #25d366 0%, #128c7e 100%);
    color: white;
}

.phone-body {
    padding: var(--space-normal);
    min-height: 200px;
    background: #e5ddd5;
    background-image:
        repeating-linear-gradient(
            45deg,
            transparent,
            transparent 10px,
            rgba(255, 255, 255, .03) 10px,
            rgba(255, 255, 255, .03) 20px
        );
}

.message-bubble {
    background: white;
    padding: var(--space-small) var(--space-normal);
    border-radius: 8px 8px 8px 0;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
    max-width: 85%;
    position: relative;
}

.message-content {
    font-size: 14px;
    color: #1f2937;
    white-space: pre-wrap;
    line-height: 1.5;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
}

.message-time {
    font-size: 11px;
    color: #6b7280;
    text-align: right;
    margin-top: var(--space-smaller);
}

/* ⭐ NUEVO: Resumen de variables */
.variables-summary {
    padding: var(--space-small);
    background: rgba(59, 130, 246, 0.05);
    border: 1px solid rgba(59, 130, 246, 0.2);
    border-radius: var(--border-radius-small);
}

.variable-badge {
    display: inline-flex;
    align-items: center;
    gap: 2px;
    padding: 2px 6px;
    border-radius: 4px;
    font-size: 9px;
    font-family: monospace;

    &.resolved {
        background: rgba(34, 197, 94, 0.1);
        color: #16a34a;
        border: 1px solid rgba(34, 197, 94, 0.3);
    }

    &.unresolved {
        background: rgba(245, 158, 11, 0.1);
        color: #d97706;
        border: 1px solid rgba(245, 158, 11, 0.3);
    }
}

.template-meta {
    display: flex;
    flex-direction: column;
    gap: var(--space-small);
    margin-top: var(--space-normal);
    padding-top: var(--space-normal);
    border-top: 1px solid var(--color-border);
}

.meta-item {
    display: flex;
    justify-content: space-between;
    font-size: var(--font-size-small);
}

.meta-label {
    color: var(--s-600);
    font-weight: var(--font-weight-medium);
}

.meta-value {
    color: var(--color-body);
    font-weight: var(--font-weight-medium);
}

/* ⭐ NUEVO: Estilos para variables resaltadas */
:deep(.variable-highlight) {
    padding: 1px 4px;
    border-radius: 3px;
    font-family: monospace;
    font-size: 12px;

    &.liquid {
        background: rgba(139, 92, 246, 0.15);
        color: #7c3aed;
        border: 1px solid rgba(139, 92, 246, 0.3);
    }

    &.numbered {
        background: rgba(59, 130, 246, 0.15);
        color: #2563eb;
        border: 1px solid rgba(59, 130, 246, 0.3);
    }
}

:deep(.value-highlight) {
    padding: 1px 4px;
    border-radius: 3px;
    font-weight: 500;

    &.resolved {
        background: rgba(34, 197, 94, 0.15);
        color: #16a34a;
        border-bottom: 2px solid #22c55e;
    }

    &.unresolved {
        background: rgba(245, 158, 11, 0.15);
        color: #d97706;
        border-bottom: 2px dashed #f59e0b;
    }
}
</style>