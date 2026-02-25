<!-- 
  ================================================================================
  proyecto@contact_tracking
  /home/chatwoot/chatwoot/app/javascript/dashboard/components/contacts/ContactTracking/TemplatePreview.vue
  ================================================================================
  Componente: TemplatePreview.vue
  Descripción: Preview visual de plantilla WhatsApp estilo teléfono
  Líneas: ~150
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
                    <div class="message-content text-xs leading-relaxed">
                        {{ previewText }}
                    </div>
                    <div class="message-time text-[8px]">
                        {{ currentTime }} ✓✓
                    </div>
                </div>
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
        </div>

    </div>
</template>

<script>
import { 
    replaceTemplateVariables, 
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
    },

    computed: {
        template() {
            return this.availableTemplates.find(t => t.name === this.templateName);
        },

        templateLanguage() {
            return this.template?.language || 'es';
        },

        previewText() {
            if (!this.template) return 'Plantilla no encontrada';

            const preview = this.template.body || 'Sin contenido';
            return replaceTemplateVariables(preview);
        },

        currentTime() {
            return getCurrentTime();
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
</style>