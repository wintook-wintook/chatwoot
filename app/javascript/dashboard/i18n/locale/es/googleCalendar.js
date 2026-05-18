export default {
  GOOGLE_CALENDAR: {
    HEADER: 'Google Calendar',
    CONNECT: {
      TITLE: 'Conectá tu Google Calendar',
      DESCRIPTION: 'Visualizá tus eventos, compartí disponibilidad con el equipo y creá citas directamente desde las conversaciones.',
      BUTTON: 'Conectar cuenta de Google',
      CONNECTING: 'Conectando...',
      MODAL: {
        TITLE: 'Conectar Google Calendar',
        DESCRIPTION: 'Chatwoot solicitará los siguientes permisos en tu cuenta de Google:',
        PERMISSIONS: [
          'Leer tus eventos de calendario',
          'Crear y editar eventos en tu nombre',
          'Ver tu disponibilidad (libre/ocupado)',
        ],
        CONFIRM: 'Conectar con Google',
        CANCEL: 'Cancelar',
      },
    },
    DISCONNECT: {
      BUTTON: 'Desconectar',
      CONFIRM: '¿Estás seguro de que querés desconectar tu Google Calendar?',
    },
    CONNECTED_AS: 'Conectado como',
    EVENTS: {
      TITLE: 'Mi Calendario',
      EMPTY: 'No hay eventos para este período',
      NEW_EVENT: 'Nuevo Evento',
      ALL_DAY: 'Todo el día',
    },
    CALENDAR: {
      WEEK: 'Semana',
      MONTH: 'Mes',
    },
    AGENDA: {
      TITLE: 'Próximos eventos',
      EMPTY: 'No hay eventos próximos',
      TODAY: 'Hoy',
      TOMORROW: 'Mañana',
    },
    AVAILABILITY: {
      TITLE: 'Disponibilidad del equipo',
      BUSY: 'Ocupado',
      FREE: 'Libre',
    },
    CREATE_EVENT: {
      TITLE: 'Crear Evento',
      FIELDS: {
        SUMMARY: 'Título',
        SUMMARY_PLACEHOLDER: 'Título del evento',
        START: 'Inicio',
        END: 'Fin',
        DESCRIPTION: 'Descripción',
        DESCRIPTION_PLACEHOLDER: 'Descripción del evento (opcional)',
        ATTENDEES: 'Invitados',
        ATTENDEES_PLACEHOLDER: 'email@ejemplo.com',
      },
      SUBMIT: 'Crear Evento',
      CANCEL: 'Cancelar',
      SUCCESS: 'Evento creado exitosamente',
      ERROR: 'No se pudo crear el evento. Intentá de nuevo.',
    },
    EDIT_EVENT: {
      TITLE: 'Editar Evento',
      SUBMIT: 'Guardar cambios',
      SUCCESS: 'Evento actualizado exitosamente',
      ERROR: 'No se pudo actualizar el evento. Intentá de nuevo.',
    },
    API: {
      CONNECT_ERROR: 'No se pudo conectar a Google Calendar',
      DISCONNECT_SUCCESS: 'Google Calendar desconectado',
      DISCONNECT_ERROR: 'No se pudo desconectar Google Calendar',
      FETCH_ERROR: 'Error al cargar los eventos del calendario',
    },
  },
};
