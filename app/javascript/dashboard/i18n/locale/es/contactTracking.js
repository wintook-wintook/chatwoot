// ================================================================================
// proyecto@contact_tracking
// ================================================================================
// Traducciones en Español
// ================================================================================

export default {
    CONTACT_TRACKING: {
      TITLE: 'Gestión de Seguimientos',
      DESCRIPTION: 'Programa y gestiona seguimientos automáticos de contactos',
      INTEGRATION_NOT_AVAILABLE: 'La integración de seguimientos no está disponible para este inbox',
      
      TABS: {
        FORM: 'Nuevo Seguimiento',
        LIST: 'Seguimientos Activos',
      },
      
      FORM: {
        OBJECTIVE: {
          LABEL: 'Objetivo del Seguimiento',
          PLACEHOLDER: 'Ej: Dar seguimiento a cotización',
          ERROR: 'El objetivo es requerido',
        },
        SCHEDULED_FOR: {
          LABEL: 'Fecha y Hora',
          ERROR: 'La fecha y hora son requeridas',
        },
        // DATE: {
        //   LABEL: 'Fecha',
        //   ERROR: 'La fecha es requerida',
        // },
        // TIME: {
        //   LABEL: 'Hora',
        //   ERROR: 'La hora es requerida',
        // },
        INBOX: {
          LABEL: 'Canal',
          PLACEHOLDER: 'Selecciona un canal',
          ERROR: 'El canal es requerido',
        },
        MAX_ATTEMPTS: {
          LABEL: 'No. de Intentos',
        },
        INTERVAL_DAYS: {
          LABEL: 'Días entre Intentos',
          PLACEHOLDER: 'Opcional',
        },
        USE_AI: {
          LABEL: 'Usar IA para generar mensajes',
        },
        AI_CONTEXT: {
          LABEL: 'Contexto para la IA',
          PLACEHOLDER: 'Proporciona información adicional para que la IA genere mejores mensajes...',
          HELP: 'La IA usará este contexto para personalizar los mensajes de seguimiento',
        },
        BUTTONS: {
          CANCEL: 'Cancelar',
          CREATE: 'Crear Seguimiento',
          UPDATE: 'Actualizar',
        },
      },
      
      TABLE: {
        OBJECTIVE: 'Objetivo',
        SCHEDULED_FOR: 'Programado Para',
        INBOX: 'Canal',
        ATTEMPTS: 'Intentos',
        STATUS: 'Estado',
        ACTIONS: 'Acciones',
      },
      
      STATUS: {
        PENDING: 'Pendiente',
        SCHEDULED: 'Programado',
        ACTIVE: 'Activo',
        PAUSED: 'Pausado',
        COMPLETED: 'Completado',
        CANCELLED: 'Cancelado',
        FAILED: 'Fallido',
      },
      
      ACTIONS: {
        PAUSE: 'Pausar',
        RESUME: 'Reanudar',
        CANCEL: 'Cancelar',
        EDIT: 'Editar',
      },
      
      FILTERS: {
        STATUS: 'Filtrar por Estado',
        INBOX: 'Filtrar por Canal',
        SEARCH: 'Buscar',
        SEARCH_PLACEHOLDER: 'Buscar por objetivo...',
        ALL: 'Todos',
      },
      
      EMPTY_STATE: 'No hay seguimientos creados para este contacto',
      AI_ENABLED: 'Este seguimiento usa IA para generar mensajes',
      
      CONFIRM: {
        CANCEL_MESSAGE: '¿Estás seguro de cancelar este seguimiento?',
      },

      RESUME_MODAL: {
        TITLE: 'Reanudar Seguimiento',
        DESCRIPTION: 'Selecciona la fecha y hora para el siguiente intento de contacto',
        PAUSED_AT: 'Pausado el',
        CURRENT_ATTEMPT: 'Intento actual',
        SCHEDULED_FOR: 'Fecha y hora del siguiente intento',
        SCHEDULED_FOR_HELP: 'El bot enviará el mensaje en la fecha y hora seleccionada',
        CANCEL: 'Cancelar',
        SUBMIT: 'Reanudar',
        SUCCESS: 'Seguimiento reanudado correctamente',
        ERROR: 'Error al reanudar el seguimiento',
      },

      API: {
        FETCH_ERROR: 'Error al cargar seguimientos',
        CREATE_SUCCESS: 'Seguimiento creado correctamente',
        UPDATE_SUCCESS: 'Seguimiento actualizado correctamente',
        PAUSE_SUCCESS: 'Seguimiento pausado correctamente',
        RESUME_SUCCESS: 'Seguimiento reanudado correctamente',
        CANCEL_SUCCESS: 'Seguimiento cancelado correctamente',
        ERROR: 'Ocurrió un error. Intenta de nuevo',
      },
    },
    
    CONTACT_PANEL: {
      SCHEDULE_TRACKING: 'BotSeguimientos Automatizados',
      ACTIVE_TRACKINGS: 'Seguimientos Activos',
      INTEGRATION_WARNING : {
        TITLE: "⚠️ Integraciones Requeridas",
      MESSAGE: "Para usar el sistema de seguimientos necesitas activar las siguientes integraciones:",
      TRACKING_BOT: "Bot de Seguimientos",
      OPENAI: "OpenAI",
      NOT_ACTIVE: "No activa",
      INSTRUCTIONS_TITLE: "¿Cómo activarlas?",
      STEP_1: "Ve a Configuración → Integraciones",
      STEP_2: "Activa 'Bot de Seguimientos' para este inbox",
      STEP_3: "Activa 'OpenAI' con tu API Key",
      CANCEL: "Cancelar",
      ACCEPT: "Aceptar",
      GO_TO_INTEGRATIONS: "Ir a Integraciones"
      }
    },
  };