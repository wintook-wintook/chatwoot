// ================================================================================
// proyecto@contact_tracking
// /home/chatwoot/chatwoot/app/javascript/dashboard/composables/useWhatsappTemplates.js
// ================================================================================
// Composable: useWhatsappTemplates
// Descripción: Lógica reutilizable para manejo de plantillas WhatsApp
// ================================================================================

import { ref, watch } from 'vue';
import { 
    extractTemplateBody, 
    replaceTemplateVariables,
    getCurrentTime 
} from '../helper/trackingHelpers';

export function useWhatsappTemplates(props) {
  // =====================================================
  // STATE
  // =====================================================
  const availableTemplates = ref([]);
  const isLoadingTemplates = ref(false);
  const activeTemplateTab = ref(0);

  // =====================================================
  // METHODS
  // =====================================================
  const loadWhatsAppTemplates = async (inboxId, store) => {
    if (!inboxId) return;

    isLoadingTemplates.value = true;

    try {
      // Obtener inbox del store Vuex correctamente
      const inboxes = store?.getters['inboxes/getInboxes'] || [];
      const inbox = inboxes.find(i => i.id === inboxId);

      if (!inbox) {
        console.warn(`[useWhatsappTemplates] Inbox ${inboxId} no encontrado`);
        availableTemplates.value = [];
        return;
      }

      if (inbox.message_templates && Array.isArray(inbox.message_templates)) {
        availableTemplates.value = inbox.message_templates.map(template => ({
          id: template.id || template.name,
          name: template.name,
          language: template.language,
          status: template.status,
          category: template.category,
          components: template.components || [],
          body: extractTemplateBody(template),
        }));
        
        console.log(`[useWhatsappTemplates] Cargadas ${availableTemplates.value.length} plantillas`);
      } else {
        console.warn('[useWhatsappTemplates] No se encontraron message_templates en el inbox');
        availableTemplates.value = [];
      }
    } catch (error) {
      console.error('[useWhatsappTemplates] Error loading templates:', error);
      availableTemplates.value = [];
    } finally {
      isLoadingTemplates.value = false;
    }
  };

  const getTemplatePreview = (templateName) => {
    const template = availableTemplates.value.find(t => t.name === templateName);
    if (!template) return 'Plantilla no encontrada';

    const preview = template.body || 'Sin contenido';
    return replaceTemplateVariables(preview);
  };

  const getTemplateCategory = (templateName) => {
    const template = availableTemplates.value.find(t => t.name === templateName);
    return template?.category || 'N/A';
  };

  const getAttemptTabName = (index, maxAttempts) => {
    const number = index + 1;
    if (index === 0) {
      return `🎯 Primer contacto (${number}/${maxAttempts})`;
    } else if (index === maxAttempts - 1) {
      return `🔴 Último intento (${number}/${maxAttempts})`;
    } else {
      return `🔄 Seguimiento (${number}/${maxAttempts})`;
    }
  };

  // =====================================================
  // WATCHERS
  // =====================================================
  watch(
    () => props.inboxId,
    (newInboxId) => {
      if (newInboxId && props.store) {
        loadWhatsAppTemplates(newInboxId, props.store);
      }
    },
    { immediate: true }
  );

  // =====================================================
  // RETURN
  // =====================================================
  return {
    availableTemplates,
    isLoadingTemplates,
    activeTemplateTab,
    loadWhatsAppTemplates,
    getTemplatePreview,
    getTemplateCategory,
    getAttemptTabName,
    getCurrentTime,
  };
}