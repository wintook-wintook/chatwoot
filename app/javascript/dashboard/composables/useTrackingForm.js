// ================================================================================
// proyecto@contact_tracking
// ================================================================================
// Composable: useTrackingForm
// Descripción: Lógica reutilizable del formulario de seguimientos
// ================================================================================

import { ref, computed, watch } from 'vue';
import { useAlert } from 'dashboard/composables';
import {
    getMinDateTime,
    toDatetimeLocal,
    validateInterval,
    getIntervalHelpText as helperGetIntervalHelpText,
    convertToMinutes
} from '../helper/trackingHelpers';

export function useTrackingForm(props, emit) {
  // =====================================================
  // STATE
  // =====================================================
  const formData = ref({
    objective: '',
    scheduled_for: '',
    inbox_id: props.currentChat?.inbox_id || '',
    max_attempts: 3,
    retry_interval_value: 3,  // Cambiado de 5 a 3 minutos
    retry_interval_unit: 'minutes',
    use_ai: true,  // ⭐ Siempre habilitado - IA obligatoria para generar mensajes
    ai_context: '',
    complementary_prompt: '',  // ⭐ NUEVO: Instrucciones adicionales para responder preguntas
    keyword_actions: [],             // proyecto@contact_tracking
    calendar_integration_ids: [],    // proyecto@bot_seguimiento_calendar
  });

  const errors = ref({
    objective: '',
    scheduled_for: '',
    inbox_id: '',
    ai_context: '',  // ⭐ Validación obligatoria
  });

  const isCreating = ref(false);

  // =====================================================
  // COMPUTED
  // =====================================================
  const minDateTime = computed(() => {
    return getMinDateTime();
  });

  const retry_interval_in_minutes = computed(() => {
    return convertToMinutes(
      formData.value.retry_interval_value,
      formData.value.retry_interval_unit
    );
  });

  const intervalValidation = computed(() => {
    return validateInterval(
      formData.value.retry_interval_value,
      formData.value.retry_interval_unit
    );
  });

  const isFormValid = computed(() => {
    return (
      formData.value.objective.trim() !== '' &&
      formData.value.scheduled_for !== '' &&
      formData.value.inbox_id !== '' &&
      formData.value.ai_context.trim() !== '' &&  // ⭐ Contexto IA obligatorio
      intervalValidation.value.isValid
    );
  });

  // =====================================================
  // METHODS
  // =====================================================
  const validateField = (field) => {
    const value = formData.value[field];

    if (field === 'objective') {
      errors.value.objective = value.trim() === '' ? 'El objetivo es requerido' : '';
    } else if (field === 'scheduled_for') {
      errors.value.scheduled_for = value === '' ? 'La fecha y hora son requeridas' : '';
    } else if (field === 'inbox_id') {
      errors.value.inbox_id = value === '' ? 'El canal es requerido' : '';
    } else if (field === 'ai_context') {
      // ⭐ Validación obligatoria del contexto IA
      errors.value.ai_context = value.trim() === '' ? 'El contexto para la IA es requerido' : '';
    }
  };

  const clearError = (field) => {
    errors.value[field] = '';
  };

  const validateForm = () => {
    validateField('objective');
    validateField('scheduled_for');
    validateField('inbox_id');
    validateField('ai_context');  // ⭐ Validar contexto IA obligatorio

    return Object.values(errors.value).every(error => error === '');
  };

  const getMinValue = () => {
    const minValues = {
      minutes: 3,  // Cambiado de 5 a 3 minutos
      hours: 1,
      days: 1
    };
    return minValues[formData.value.retry_interval_unit] || 3;
  };

  const adjustMinValue = () => {
    const minValue = getMinValue();
    if (formData.value.retry_interval_value < minValue) {
      formData.value.retry_interval_value = minValue;
    }
  };

  const validateIntervalField = () => {
    // Trigger reactivity
    formData.value = { ...formData.value };
  };

  const getIntervalHelpText = () => {
    return helperGetIntervalHelpText(
      formData.value.retry_interval_value,
      formData.value.retry_interval_unit
    );
  };

  const loadEditingData = (tracking) => {
    if (!tracking) {
      resetForm();
      return;
    }

    formData.value = {
      objective: tracking.objective,
      scheduled_for: toDatetimeLocal(tracking.scheduled_for),
      inbox_id: tracking.inbox_id,
      max_attempts: tracking.max_attempts,
      retry_interval_value: tracking.retry_interval_value || 3,  // Cambiado de 5 a 3 minutos
      retry_interval_unit: tracking.retry_interval_unit || 'minutes',
      use_ai: true,  // ⭐ Siempre habilitado - IA obligatoria
      ai_context: tracking.ai_context || '',
      complementary_prompt: tracking.complementary_prompt || '',  // ⭐ NUEVO: Instrucciones adicionales
      keyword_actions: Array.isArray(tracking.keyword_actions)   // proyecto@contact_tracking
        ? tracking.keyword_actions.map(ka => ({ ...ka }))
        : [],
    };
  };

  const loadDuplicateData = (tracking) => {
    formData.value = {
      objective: tracking.objective || '',
      scheduled_for: '',  // Vacío: el usuario debe elegir nueva fecha
      inbox_id: tracking.inbox_id || '',
      max_attempts: tracking.max_attempts || 3,
      retry_interval_value: tracking.retry_interval_value || 3,
      retry_interval_unit: tracking.retry_interval_unit || 'minutes',
      use_ai: true,
      ai_context: tracking.ai_context || '',
      complementary_prompt: tracking.complementary_prompt || '',
      keyword_actions: Array.isArray(tracking.keyword_actions) // proyecto@contact_tracking
        ? tracking.keyword_actions.map(ka => ({ ...ka }))
        : [],
    };

    errors.value = {
      objective: '',
      scheduled_for: '',
      inbox_id: '',
      ai_context: '',
    };
  };

  const resetForm = () => {
    formData.value = {
      objective: '',
      scheduled_for: '',
      inbox_id: props.currentChat?.inbox_id || '',
      max_attempts: 3,
      retry_interval_value: 3,  // Cambiado de 5 a 3 minutos
      retry_interval_unit: 'minutes',
      use_ai: true,  // ⭐ Siempre habilitado - IA obligatoria
      ai_context: '',
      complementary_prompt: '',  // ⭐ NUEVO: Instrucciones adicionales
      keyword_actions: [],       // proyecto@contact_tracking
    };

    errors.value = {
      objective: '',
      scheduled_for: '',
      inbox_id: '',
      ai_context: '',
    };
  };

  const submitForm = async () => {
    if (!validateForm()) {
      return;
    }

    isCreating.value = true;

    try {
      const payload = {
        objective: formData.value.objective,
        scheduled_for: new Date(formData.value.scheduled_for).toISOString(),
        max_attempts: formData.value.max_attempts,
        retry_interval_value: formData.value.retry_interval_value,
        retry_interval_unit: formData.value.retry_interval_unit,
        inbox_id: formData.value.inbox_id,
        conversation_id: props.conversationId,
        ai_context: formData.value.ai_context || '',  // ⭐ Siempre enviar contexto (IA obligatoria)
        complementary_prompt: formData.value.complementary_prompt || '',  // ⭐ NUEVO: Instrucciones adicionales
        keyword_actions: formData.value.keyword_actions || [],             // proyecto@contact_tracking
        calendar_integration_ids: formData.value.calendar_integration_ids || [],  // proyecto@bot_seguimiento_calendar
      };

      // ⭐ SOLO emitir, NO resetear aquí
      // El reset se hace en el padre SOLO si el guardado fue exitoso
      emit('submit', payload);
    } finally {
      isCreating.value = false;
    }
  };

  // =====================================================
  // WATCHERS
  // =====================================================
  watch(
    () => props.editingTracking,
    (newTracking) => {
      if (newTracking) {
        // Cargar datos del tracking a editar
        loadEditingData(newTracking);
      } else {
        // Resetear formulario cuando es null (nuevo seguimiento)
        resetForm();
      }
    },
    { immediate: true }
  );

  // ⭐ NUEVO: Watcher para validar y emitir cambios de max_attempts al padre
  const isCorrectingAttempts = ref(false);

  watch(
    () => formData.value.max_attempts,
    (newMaxAttempts, oldMaxAttempts) => {
      // Evitar loop infinito cuando estamos corrigiendo
      if (isCorrectingAttempts.value) {
        isCorrectingAttempts.value = false;
        return;
      }

      // ⭐ Validar límites: mínimo 1, máximo 6
      const MIN_ATTEMPTS = 1;
      const MAX_ATTEMPTS = 6;

      if (newMaxAttempts < MIN_ATTEMPTS) {
        useAlert(`El número de intentos no puede ser menor a ${MIN_ATTEMPTS}`);
        isCorrectingAttempts.value = true;
        setTimeout(() => {
          formData.value.max_attempts = MIN_ATTEMPTS;
        }, 0);
        return;
      }

      if (newMaxAttempts > MAX_ATTEMPTS) {
        useAlert(`El número de intentos no puede ser mayor a ${MAX_ATTEMPTS}`);
        isCorrectingAttempts.value = true;
        setTimeout(() => {
          formData.value.max_attempts = MAX_ATTEMPTS;
        }, 0);
        return;
      }

      // Emitir solo si está en rango válido
      if (newMaxAttempts && newMaxAttempts > 0) {
        emit('update:maxAttempts', newMaxAttempts);
      }
    }
  );

  // =====================================================
  // RETURN
  // =====================================================
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
    validateForm,
    getMinValue,
    adjustMinValue,
    validateIntervalField,
    getIntervalHelpText,
    submitForm,
    resetForm,
    loadDuplicateData,
  };
}