// ================================================================================
// proyecto@contact_tracking
// ================================================================================
// Helpers: trackingHelpers
// Descripción: Funciones de utilidad compartidas para el sistema de seguimientos
// Ubicación: app/javascript/dashboard/helpers/trackingHelpers.js
// ================================================================================

/**
 * Formatea una fecha a formato local legible
 * @param {string|Date} dateString - Fecha en formato ISO o Date object
 * @returns {string} Fecha formateada (ej: "15/01/24, 14:30")
 */
export const formatDateTime = (dateString) => {
    if (!dateString) return 'N/A';
    
    const date = new Date(dateString);
    
    if (isNaN(date.getTime())) {
      return 'Fecha inválida';
    }
  
    return date.toLocaleString('es-ES', {
      day: '2-digit',
      month: '2-digit',
      year: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
  };
  
  /**
   * Formatea solo la fecha sin hora
   * @param {string|Date} dateString - Fecha en formato ISO o Date object
   * @returns {string} Fecha formateada (ej: "15/01/2024")
   */
  export const formatDate = (dateString) => {
    if (!dateString) return 'N/A';
    
    const date = new Date(dateString);
    
    if (isNaN(date.getTime())) {
      return 'Fecha inválida';
    }
  
    return date.toLocaleString('es-ES', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    });
  };
  
  /**
   * Calcula el tiempo restante hasta una fecha
   * @param {string|Date} scheduledFor - Fecha programada
   * @returns {string} Tiempo restante humanizado (ej: "En 2 horas", "En 3 días")
   */
  export const getTimeRemaining = (scheduledFor) => {
    if (!scheduledFor) return 'N/A';
    
    const now = new Date();
    const target = new Date(scheduledFor);
    const diffMs = target - now;
  
    if (diffMs < 0) {
      return 'Vencido';
    }
  
    const diffMinutes = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMinutes / 60);
    const diffDays = Math.floor(diffHours / 24);
  
    if (diffDays > 0) {
      return `En ${diffDays} día${diffDays > 1 ? 's' : ''}`;
    } else if (diffHours > 0) {
      return `En ${diffHours} hora${diffHours > 1 ? 's' : ''}`;
    } else if (diffMinutes > 0) {
      return `En ${diffMinutes} minuto${diffMinutes > 1 ? 's' : ''}`;
    } else {
      return 'Ahora mismo';
    }
  };
  
  /**
   * Convierte intervalo a minutos totales
   * @param {number} value - Valor del intervalo
   * @param {string} unit - Unidad (minutes, hours, days)
   * @returns {number} Total de minutos
   */
  export const convertToMinutes = (value, unit) => {
    const multipliers = {
      minutes: 1,
      hours: 60,
      days: 1440,
    };
  
    return value * (multipliers[unit] || 1);
  };
  
  /**
   * Convierte minutos a formato legible
   * @param {number} totalMinutes - Total de minutos
   * @returns {string} Formato legible (ej: "2h 30m", "3 días")
   */
  export const formatMinutesToReadable = (totalMinutes) => {
    if (totalMinutes < 60) {
      return `${totalMinutes} minutos`;
    } else if (totalMinutes < 1440) {
      const hours = Math.floor(totalMinutes / 60);
      const mins = totalMinutes % 60;
      return `${hours}h ${mins > 0 ? mins + 'm' : ''}`.trim();
    } else {
      const days = Math.floor(totalMinutes / 1440);
      const hours = Math.floor((totalMinutes % 1440) / 60);
      return `${days}d ${hours > 0 ? hours + 'h' : ''}`.trim();
    }
  };
  
  /**
   * Calcula el tiempo estimado de cada intento
   * @param {number} attemptIndex - Índice del intento (0-based)
   * @param {number} intervalValue - Valor del intervalo
   * @param {string} intervalUnit - Unidad del intervalo
   * @returns {string} Tiempo estimado legible
   */
  export const getAttemptEstimatedTime = (attemptIndex, intervalValue, intervalUnit) => {
    if (attemptIndex === 0) {
      return 'Ahora (inmediato)';
    }
  
    const totalMinutes = convertToMinutes(intervalValue, intervalUnit) * attemptIndex;
    return `En ${formatMinutesToReadable(totalMinutes)}`;
  };
  
  /**
   * Obtiene la clase CSS según el estado
   * @param {string} status - Estado del tracking
   * @returns {string} Clase CSS
   */
  export const getStatusClass = (status) => {
    const statusClasses = {
      pending: 'status-pending',
      scheduled: 'status-scheduled',
      active: 'status-active',
      paused: 'status-paused',
      completed: 'status-completed',
      cancelled: 'status-cancelled',
      failed: 'status-failed',
    };
  
    return statusClasses[status] || 'status-default';
  };
  
  /**
   * Obtiene la etiqueta traducida del estado
   * @param {string} status - Estado del tracking
   * @returns {string} Etiqueta en español
   */
  export const getStatusLabel = (status) => {
    const statusLabels = {
      pending: 'Pendiente',
      scheduled: 'Programado',
      active: 'Activo',
      paused: 'Pausado',
      completed: 'Completado',
      cancelled: 'Cancelado',
      failed: 'Fallido',
    };
  
    return statusLabels[status] || status;
  };
  
  /**
   * Obtiene el ícono según el estado
   * @param {string} status - Estado del tracking
   * @returns {string} Nombre del ícono Fluent
   */
  export const getStatusIcon = (status) => {
    const statusIcons = {
      pending: 'clock',
      scheduled: 'calendar-clock',
      active: 'play-circle',
      paused: 'pause-circle',
      completed: 'checkmark-circle',
      cancelled: 'dismiss-circle',
      failed: 'error-circle',
    };
  
    return statusIcons[status] || 'info';
  };
  
  /**
   * Valida si un estado puede ser pausado
   * @param {string} status - Estado actual
   * @returns {boolean}
   */
  export const canPause = (status) => {
    return ['active', 'scheduled'].includes(status);
  };
  
  /**
   * Valida si un estado puede ser reanudado
   * @param {string} status - Estado actual
   * @returns {boolean}
   */
  export const canResume = (status) => {
    return status === 'paused';
  };
  
  /**
   * Valida si un estado puede ser cancelado
   * @param {string} status - Estado actual
   * @returns {boolean}
   */
  export const canCancel = (status) => {
    return !['completed', 'cancelled'].includes(status);
  };
  
  /**
   * Valida si un estado puede ser editado
   * @param {string} status - Estado actual
   * @returns {boolean}
   */
  export const canEdit = (status) => {
    return !['completed', 'cancelled', 'failed'].includes(status);
  };

  /**
   * Valida si un seguimiento completado puede duplicarse
   * @param {string} status - Estado actual
   * @returns {boolean}
   */
  export const canDuplicate = (status) => status === 'completed';
  
  /**
   * Obtiene el mínimo datetime permitido (fecha actual)
   * @returns {string} Datetime en formato "YYYY-MM-DDTHH:mm"
   */
  export const getMinDateTime = () => {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    
    return `${year}-${month}-${day}T${hours}:${minutes}`;
  };
  
  /**
   * Convierte fecha de Date object a formato datetime-local
   * @param {Date|string} date - Fecha a convertir
   * @returns {string} Formato "YYYY-MM-DDTHH:mm"
   */
  export const toDatetimeLocal = (date) => {
    if (!date) return '';
    
    const d = new Date(date);
    
    if (isNaN(d.getTime())) {
      return '';
    }
  
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    const hours = String(d.getHours()).padStart(2, '0');
    const minutes = String(d.getMinutes()).padStart(2, '0');
    
    return `${year}-${month}-${day}T${hours}:${minutes}`;
  };
  
  /**
   * Valida límites de intervalo según unidad
   * @param {number} value - Valor del intervalo
   * @param {string} unit - Unidad (minutes, hours, days)
   * @returns {object} { isValid: boolean, message: string }
   */
  export const validateInterval = (value, unit) => {
    const limits = {
      minutes: { min: 3, max: 1440, warning: 'Entre 3 min y 24 horas' },  // Cambiado de 5 a 3
      hours: { min: 1, max: 72, warning: 'Entre 1 y 72 horas' },
      days: { min: 1, max: 30, warning: 'Entre 1 y 30 días' }
    };

    const limit = limits[unit];

    if (!limit) {
      return { isValid: false, message: 'Unidad no válida' };
    }

    // Validación mínima global (3 minutos)  // Cambiado de 5 a 3
    const totalMinutes = convertToMinutes(value, unit);

    if (totalMinutes < 3) {  // Cambiado de 5 a 3
      return {
        isValid: false,
        message: '⚠️ El intervalo mínimo es de 3 minutos'  // Cambiado de 5 a 3
      };
    }
  
    if (value < limit.min || value > limit.max) {
      return {
        isValid: false,
        message: `⚠️ ${limit.warning}`
      };
    }
  
    return { isValid: true, message: '' };
  };
  
  /**
   * Obtiene texto de ayuda según la unidad de intervalo
   * @param {number} value - Valor del intervalo
   * @param {string} unit - Unidad del intervalo
   * @returns {string} Texto de ayuda
   */
  export const getIntervalHelpText = (value, unit) => {
    const unitLabels = {
      minutes: 'minutos',
      hours: 'horas',
      days: 'días'
    };
  
    const recommendations = {
      minutes: '⚡ Seguimiento inmediato (3-60 min recomendado)',  // Cambiado de 5 a 3
      hours: '⏰ Seguimiento en el día (1-12h recomendado)',
      days: '📅 Seguimiento espaciado (1-7 días recomendado)'
    };
  
    return `Cada intento será enviado después de ${value} ${unitLabels[unit]}. ${recommendations[unit]}`;
  };
  
  /**
   * Normaliza respuesta de la API de seguimientos
   * @param {any} response - Respuesta de la API
   * @returns {Array} Array de trackings
   */
  export const normalizeTrackingsResponse = (response) => {
    if (Array.isArray(response)) return response;
    if (response?.trackings && Array.isArray(response.trackings)) return response.trackings;
    if (response?.data?.trackings && Array.isArray(response.data.trackings)) return response.data.trackings;
    if (response?.data && Array.isArray(response.data)) return response.data;
    return [];
  };
  
  /**
   * Extrae el cuerpo de una plantilla WhatsApp
   * @param {object} template - Objeto de plantilla
   * @returns {string} Texto del cuerpo
   */
  export const extractTemplateBody = (template) => {
    if (!template || !template.components) return '';
    
    const bodyComponent = template.components.find(c => c.type === 'BODY');
    return bodyComponent?.text || '';
  };
  
  /**
   * Reemplaza variables de plantilla con placeholders
   * @param {string} text - Texto con variables {{1}}, {{2}}, etc.
   * @returns {string} Texto con placeholders [Variable 1], etc.
   */
  export const replaceTemplateVariables = (text) => {
    if (!text) return '';
    return text.replace(/\{\{(\d+)\}\}/g, (match, num) => `[Variable ${num}]`);
  };

  /**
   * ⭐ NUEVO: Reemplaza variables Liquid con datos reales del contacto
   * Soporta: {{contact.name}}, {{contact.custom_attributes.X}}, {{1}}, {{2}}, etc.
   * @param {string} text - Texto con variables
   * @param {object} contactData - Datos del contacto
   * @param {object} trackingData - Datos del tracking (opcional)
   * @returns {object} { text: string, replacements: array }
   */
  export const replaceTemplateVariablesWithData = (text, contactData = {}, trackingData = {}) => {
    if (!text) return { text: '', replacements: [] };

    const replacements = [];
    let processedText = text;

    // ⭐ Procesar variables Liquid: {{contact.name}}, {{contact.custom_attributes.X}}
    // Regex actualizado para soportar números en nombres de atributos (ej: factura_monto_568)
    processedText = processedText.replace(
      /\{\{([a-z_][a-z0-9_]*(?:\.[a-z_][a-z0-9_]*)+)\}\}/gi,
      (match, varPath) => {
        const value = resolveLiquidVariable(varPath, contactData, trackingData);
        const displayValue = value || `[${varPath}]`;
        replacements.push({
          variable: varPath,
          value: value,
          resolved: !!value
        });
        return displayValue;
      }
    );

    // ⭐ Procesar variables numeradas legacy: {{1}}, {{2}}
    processedText = processedText.replace(
      /\{\{(\d+)\}\}/g,
      (match, num) => {
        const value = resolveNumberedVariable(parseInt(num), contactData, trackingData);
        const displayValue = value || `[Variable ${num}]`;
        replacements.push({
          variable: `{{${num}}}`,
          value: value,
          resolved: !!value
        });
        return displayValue;
      }
    );

    return { text: processedText, replacements };
  };

  /**
   * Resuelve una variable Liquid a su valor
   */
  const resolveLiquidVariable = (varPath, contactData, trackingData) => {
    const parts = varPath.toLowerCase().split('.');
    const root = parts.shift();

    switch (root) {
      case 'contact':
        return resolveContactVariable(parts, contactData);
      case 'tracking':
        return resolveTrackingVariable(parts, trackingData);
      case 'current_date':
        return new Date().toLocaleDateString('es-MX');
      case 'current_time':
        return getCurrentTime();
      default:
        return null;
    }
  };

  /**
   * Resuelve variable de contacto
   */
  const resolveContactVariable = (parts, contactData) => {
    if (!parts.length || !contactData) return null;

    const property = parts.shift();

    switch (property) {
      case 'name':
        return contactData.name;
      case 'first_name':
        return contactData.name?.split(' ')[0];
      case 'last_name':
        return contactData.name?.split(' ').slice(1).join(' ');
      case 'email':
        return contactData.email;
      case 'phone_number':
      case 'phone':
        return contactData.phone_number;
      case 'custom_attributes':
        const attrKey = parts.shift();
        return contactData.custom_attributes?.[attrKey];
      default:
        // Intentar como atributo directo o custom_attribute
        return contactData[property] || contactData.custom_attributes?.[property];
    }
  };

  /**
   * Resuelve variable de tracking
   */
  const resolveTrackingVariable = (parts, trackingData) => {
    if (!parts.length || !trackingData) return null;

    const property = parts.shift();

    switch (property) {
      case 'objective':
        return trackingData.objective;
      case 'ai_context':
        return trackingData.ai_context;
      default:
        return trackingData[property];
    }
  };

  /**
   * Resuelve variable numerada (mapeo por posición)
   */
  const resolveNumberedVariable = (num, contactData, trackingData) => {
    switch (num) {
      case 1:
        return contactData.name || contactData.phone_number;
      case 2:
        return trackingData.objective || contactData.custom_attributes?.producto;
      case 3:
        return contactData.custom_attributes?.monto || new Date().toLocaleDateString('es-MX');
      default:
        return null;
    }
  };

  /**
   * Verifica si un canal es WhatsApp
   * @param {string} channelType - Tipo de canal
   * @returns {boolean}
   */
  export const isWhatsAppChannel = (channelType) => {
    return channelType === 'Channel::Whatsapp' ||
           channelType === 'whatsapp' ||
           channelType === 'Channel::WhatsappCloud';
  };
  
  /**
   * Obtiene hora actual en formato HH:mm
   * @returns {string} Hora actual (ej: "14:30")
   */
  export const getCurrentTime = () => {
    const now = new Date();
    return `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
  };
  
  /**
   * Trunca texto largo
   * @param {string} text - Texto a truncar
   * @param {number} maxLength - Longitud máxima (default: 50)
   * @returns {string} Texto truncado
   */
  export const truncateText = (text, maxLength = 50) => {
    if (!text) return '';
    if (text.length <= maxLength) return text;
    return `${text.substring(0, maxLength)}...`;
  };
  
  /**
   * Valida formato de email
   * @param {string} email - Email a validar
   * @returns {boolean}
   */
  export const isValidEmail = (email) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  };
  
  /**
   * Valida formato de teléfono (básico)
   * @param {string} phone - Teléfono a validar
   * @returns {boolean}
   */
  export const isValidPhone = (phone) => {
    const phoneRegex = /^[\d\s\-\+\(\)]+$/;
    return phoneRegex.test(phone) && phone.replace(/\D/g, '').length >= 10;
  };
  
  // ================================================================================
  // EXPORTS POR DEFECTO
  // ================================================================================
  export default {
    formatDateTime,
    formatDate,
    getTimeRemaining,
    convertToMinutes,
    formatMinutesToReadable,
    getAttemptEstimatedTime,
    getStatusClass,
    getStatusLabel,
    getStatusIcon,
    canPause,
    canResume,
    canCancel,
    canEdit,
    canDuplicate,
    getMinDateTime,
    toDatetimeLocal,
    validateInterval,
    getIntervalHelpText,
    normalizeTrackingsResponse,
    extractTemplateBody,
    replaceTemplateVariables,
    replaceTemplateVariablesWithData,
    isWhatsAppChannel,
    getCurrentTime,
    truncateText,
    isValidEmail,
    isValidPhone,
  };