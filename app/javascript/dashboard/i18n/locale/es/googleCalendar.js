export default {
  GOOGLE_CALENDAR: {
    HEADER: 'Google Calendar',
    CONNECT: {
      TITLE: 'Conecta tu Google Calendar',
      DESCRIPTION:
        'Visualiza tus eventos, comparte disponibilidad con el equipo y crea citas directamente desde las conversaciones.',
      BUTTON: 'Conectar cuenta de Google',
      CONNECTING: 'Conectando...',
      MODAL: {
        TITLE: 'Conectar Google Calendar',
        DESCRIPTION:
          'Se solicitarán los siguientes permisos en tu cuenta de Google:',
        PERMISSIONS: [
          'Leer tus eventos de calendario',
          'Crear y editar eventos en tu nombre',
          'Crear y gestionar tus calendarios',
          'Ver tu disponibilidad (libre/ocupado)',
        ],
        CONFIRM: 'Conectar con Google',
        CANCEL: 'Cancelar',
      },
    },
    DISCONNECT: {
      BUTTON: 'Desconectar',
      CONFIRM: '¿Estás seguro de que quieres desconectar tu Google Calendar?',
    },
    RECONNECT: {
      BUTTON: 'Reconectar',
    },
    CONNECTED_AS: 'Conectado como',
    EVENTS: {
      TITLE: 'Mi Calendario',
      EMPTY: 'No hay eventos para este período',
      NEW_EVENT: 'Nueva tarea agendada',
      ALL_DAY: 'Todo el día',
    },
    CALENDAR: {
      WEEK: 'Semana',
      MONTH: 'Mes',
      AGENDA: 'Agenda',
    },
    AGENDA: {
      TITLE: 'Próximos eventos',
      EMPTY: 'No hay eventos próximos',
      TODAY: 'Hoy',
      TOMORROW: 'Mañana',
    },
    CALENDARS: {
      TITLE: 'Mis calendarios',
      SUBSCRIBED: 'suscrito',
      SUBSCRIBE_BUTTON: 'Agregar otro calendario',
      SUBSCRIBE_PLACEHOLDER: 'email@ejemplo.com o ID del calendario',
      SUBSCRIBE_ADD: 'Agregar',
      SUBSCRIBE_MODAL_TITLE: 'Agregar otro calendario',
      SUBSCRIBE_MODAL_SUBTITLE:
        'Ingresa el email o el ID del calendario de Google que quieres ver. Debe estar compartido con tu cuenta.',
      MODE_CREATE: 'Crear nuevo',
      MODE_SUBSCRIBE: 'Suscribir existente',
      CREATE_HINT:
        'Crea un calendario secundario NUEVO en tu cuenta de Google (como "Crear calendario nuevo" de Google).',
      CREATE_PLACEHOLDER: 'Nombre del calendario (p. ej. Consultorio Norte)',
      CREATE_ADD: 'Crear',
      ADD_ERROR:
        'No se pudo agregar el calendario. Es posible que debas reconectar tu Google Calendar para habilitar esta función.',
      FIELD_NAME: 'Nombre',
      FIELD_DESCRIPTION: 'Descripción',
      FIELD_DESCRIPTION_PLACEHOLDER: 'Descripción del calendario (opcional)',
      FIELD_TIMEZONE: 'Zona horaria',
      FIELD_TIMEZONE_DEFAULT: 'Predeterminada de la cuenta',
      FIELD_COLOR: 'Color',
      EDIT_MODAL_TITLE: 'Editar calendario',
      EDIT_HINT:
        'Modifica el nombre, la descripción, la zona horaria y el color del calendario.',
      SAVE: 'Guardar',
    },
    AVAILABILITY: {
      TITLE: 'Disponibilidad del equipo',
      BUSY: 'Ocupado',
      FREE: 'Libre',
      NOT_CONNECTED: 'Sin calendario',
    },
    // fix/calendario_google — calendario de compañeros (Google aplica lo que cada uno comparte).
    SCHEDULE_FOR: {
      LABEL: 'Agendar a',
      ME: 'Mí',
      HINT: 'Para agendarle a un compañero, pídele «Hacer cambios» en «Compartir mi calendario».',
      FOR_OTHER_HINT:
        'Se guarda en el calendario de tu compañero y no en el tuyo. Él queda como responsable.',
    },
    SHARE_CALENDAR: {
      BUTTON: 'Compartir mi calendario',
      TITLE: 'Compartir mi calendario',
      DESCRIPTION:
        'Elige qué ve cada compañero de tu agenda. Se guarda en tu Google Calendar al momento y no le llega correo de aviso.',
      LEVELS: {
        NONE: 'Nada',
        FREE_BUSY: 'Solo libre/ocupado',
        DETAILS: 'Ver todos los detalles',
        SCHEDULE: 'Hacer cambios (puede agendarme)',
      },
      STATUS: {
        NOT_CONNECTED: 'Sin Google',
        SAME_GOOGLE: 'Mismo Google que tú',
        OWNER_RULE: 'Administra tu calendario (cámbialo en Google)',
      },
      LOADING: 'Cargando…',
      SAVING: 'Guardando…',
      SAVED: 'Guardado',
      EMPTY: 'No hay más agentes en esta cuenta.',
      LOAD_ERROR: 'No se pudo leer con quién compartes tu calendario.',
      RECONNECT:
        'Tu conexión con Google venció. Reconecta para compartir tu calendario.',
      TABS: {
        COWORKERS: 'Compañeros',
        OTHERS: 'Otras personas',
      },
      ADD: {
        LABEL: 'Compartir con otra persona',
        PLACEHOLDER: 'correo@ejemplo.com',
        BUTTON: 'Compartir',
        HINT: 'Para alguien que no es agente de esta cuenta. Necesita una cuenta de Google para ver tu calendario.',
      },
      REMOVE: 'Dejar de compartir',
      OTHERS_EMPTY:
        'Todavía no compartes tu calendario con nadie fuera de la cuenta.',
      LEVEL_HELP: {
        FREE_BUSY: 've tus horarios ocupados, sin títulos ni detalles.',
        DETAILS:
          've tus eventos con título, lugar y descripción (los privados, solo como ocupado).',
        SCHEDULE: 'además puede crearte eventos en tu calendario.',
      },
      GENERAL: {
        PUBLIC:
          'En Google tu calendario también es público ({level}). Eso se cambia en Google Calendar.',
        DOMAIN:
          'En Google lo compartes con todo {value} ({level}). Eso se cambia en Google Calendar.',
        GROUP:
          'En Google lo compartes con el grupo {value} ({level}). Eso se cambia en Google Calendar.',
      },
      ERRORS: {
        INVALID_EMAIL: 'Escribe un correo válido.',
        OWN_EMAIL: 'Ese es tu propio correo.',
        OWNER_RULE:
          'Esa persona administra tu calendario: cámbialo en Google Calendar.',
        NOT_CONNECTED: 'Ese compañero no tiene Google conectado.',
        SAME_GOOGLE: 'Ese compañero usa tu mismo Google.',
        RECONNECT:
          'Tu conexión con Google venció. Reconecta para compartir tu calendario.',
      },
      CLOSE: 'Cerrar',
    },
    COWORKERS: {
      // fix/calendario_eliminar F4 — color de cada compañero (solo lo ve quien lo escoge).
      COLOR: {
        OPEN: 'Configurar color',
        TITLE: 'Color de {name}',
        BACKGROUND: 'Fondo',
        TEXT: 'Letra',
        TEXT_AUTO: 'Automática',
        TEXT_WHITE: 'Blanca',
        TEXT_BLACK: 'Negra',
        SAMPLE: '{name} · Junta 10:00',
        DESCRIPTION:
          'Así se ven sus eventos en tu calendario. Solo tú ves este color; no cambia nada en Google.',
        PREVIEW: 'Vista previa',
        RESET: 'Restablecer',
        CANCEL: 'Cancelar',
        SAVE: 'Guardar',
      },
      TITLE: 'Compañeros',
      HINT: 'Palomea a un compañero para ver su agenda. Solo ves lo que te compartió en Google.',
      EMPTY: 'No hay más agentes en esta cuenta.',
      CONNECT_FIRST:
        'Conecta tu Google Calendar para ver la agenda de tus compañeros.',
      RECONNECT:
        'Tu conexión con Google venció. Reconecta para ver a tus compañeros.',
      NO_EVENTS: 'Sin eventos en estas fechas',
      BUSY_NOW: 'Ocupado ahora',
      FREE_NOW: 'Libre ahora',
      ACCESS: {
        NOT_CONNECTED: 'Sin Google',
        NONE: 'No compartido',
        FREE_BUSY: 'Solo ocupado',
        DETAILS: 'Ve detalles',
        CAN_SCHEDULE: 'Puedes agendarle',
        SAME_GOOGLE: 'Mismo Google que tú',
        ERROR: 'No disponible',
      },
      NONE_HELP: 'Pídele que comparta su calendario de Google con {email}.',
      BUSY: 'Ocupado',
      EVENT_MODAL: {
        TITLE: 'Agenda de {name}',
        READ_ONLY: 'Solo lectura: es un evento del calendario de tu compañero.',
        PRIVATE: 'Tu compañero no comparte los detalles de este evento.',
        WHEN: 'Cuándo',
        WHERE: 'Lugar',
        CLOSE: 'Cerrar',
      },
    },
    CREATE_EVENT: {
      TITLE: 'Nueva tarea agendada',
      TYPE: {
        EVENT: 'Tarea agendada',
        TASK: 'Tarea',
      },
      FIELDS: {
        CALENDAR: 'Calendario',
        CALENDAR_PRIMARY: 'Principal',
        SUMMARY: 'Título',
        SUMMARY_PLACEHOLDER: 'Título del evento',
        TASK_PLACEHOLDER: 'Título de la tarea',
        ALL_DAY: 'Todo el día',
        START: 'Inicio',
        END: 'Fin',
        DUE_DATE: 'Fecha de vencimiento',
        LOCATION: 'Ubicación',
        LOCATION_PLACEHOLDER: 'Agregar ubicación',
        DESCRIPTION: 'Descripción',
        DESCRIPTION_PLACEHOLDER: 'Descripción del evento (opcional)',
        NOTES: 'Notas',
        NOTES_PLACEHOLDER: 'Agregar notas (opcional)',
        ATTENDEES: 'Invitados',
        ATTENDEES_PLACEHOLDER: 'Escribe un email y presiona Enter',
      },
      SUBMIT: 'Crear tarea agendada',
      SUBMIT_TASK: 'Crear Tarea',
      CANCEL: 'Cancelar',
      SUCCESS: 'Evento creado exitosamente',
      SUCCESS_TASK: 'Tarea creada exitosamente',
      ERROR: 'No se pudo crear. Inténtalo de nuevo.',
    },
    AGENDA_LINK: {
      IS_VISIT: 'Es una visita al cliente',
      ADDRESS: 'Dirección de la visita',
      ADDRESS_PLACEHOLDER:
        'Si la dejas vacía, se usa la del caso o la organización',
      CONTACT: 'Contacto',
      ORGANIZATION: 'Organización',
      CASE: 'Caso (opcional)',
      NO_CASE: 'Sin caso',
      OPEN_CASE: 'Abrir caso',
      INTERNAL: 'Interno, sin cliente (solo en Google)',
      NO_TASK:
        'Este evento aún no tiene tarea agendada. Elige el contacto para crearla, o márcalo como interno.',
      TITLE_REQUIRED: 'Escribe el título.',
      CLIENT_REQUIRED: 'Elige el contacto o un caso, o márcalo como interno.',
      NOT_CONNECTED:
        'Sin Google conectado: lo que agendes queda solo en Kontrolya.',
      LEGEND_NO_TASK: 'Borde punteado: evento sin tarea',
    },
    EDIT_EVENT: {
      TITLE: 'Editar Evento',
      SUBMIT: 'Guardar cambios',
      SUCCESS: 'Evento actualizado exitosamente',
      ERROR: 'No se pudo actualizar el evento. Inténtalo de nuevo.',
      // fix/calendario_eliminar F2
      CLOSE: 'Cerrar',
      CANCEL_ITEM: 'Cancelar tarea agendada',
      CANCEL_ITEM_DONE: 'Tarea agendada cancelada',
    },
    // fix/calendario_eliminar F3
    DELETE_EVENT: {
      DELETE: 'Eliminar evento',
      DELETE_TITLE: '¿Eliminar «{title}»?',
      DELETE_DESC: 'Se borra de tu Google Calendar.',
      DELETE_CONFIRM: 'Eliminar',
      DELETE_DONE: 'Evento eliminado',
      REMOVE: 'Quitar de mi calendario',
      REMOVE_TITLE: '¿Quitar «{title}» de tu calendario?',
      REMOVE_DESC:
        'Te invitaron a este evento: solo se quita de tu calendario. Quien te invitó y los demás lo conservan.',
      REMOVE_CONFIRM: 'Quitar',
      REMOVE_DONE: 'Se quitó de tu calendario',
      ONLY_THIS: 'Solo este',
      ALL_SERIES: 'Toda la serie',
      NOTIFY: 'Avisar a los invitados ({count})',
      BACK: 'Volver',
      ERROR: 'No se pudo eliminar el evento. Inténtalo de nuevo.',
    },
    CREATE_FROM_CONVERSATION: 'Crear evento de calendario',
    SHARE_AGENDA: {
      TITLE: 'Enviar agenda a un contacto',
      DESCRIPTION: 'Elige el período y a quién enviarle la agenda.',
      PERIOD: 'Período',
      TODAY: 'Hoy',
      DAYS_3: '3 días',
      DAYS_7: '7 días',
      INBOX: 'Canal de envío',
      INBOX_PLACEHOLDER: 'Selecciona un canal',
      CONTACTS: 'Contactos',
      CONTACTS_PLACEHOLDER: 'Buscar contacto...',
      PREVIEW: 'Vista previa del mensaje',
      CANCEL: 'Cancelar',
      SEND: 'Enviar',
      SUCCESS: 'Agenda enviada exitosamente',
      ERROR: 'No se pudo enviar la agenda. Inténtalo de nuevo.',
    },
    API: {
      CONNECT_ERROR: 'No se pudo conectar a Google Calendar',
      DISCONNECT_SUCCESS: 'Google Calendar desconectado',
      DISCONNECT_ERROR: 'No se pudo desconectar Google Calendar',
      FETCH_ERROR: 'Error al cargar los eventos del calendario',
    },
  },
};
