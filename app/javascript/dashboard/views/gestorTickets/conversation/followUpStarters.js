// Ejemplos de arranque para «Delegar a agente» cuando la cuenta aún no tiene plantillas de
// seguimiento: se cargan en la ventana para ajustarlos; no se guardan hasta que el usuario
// pulse «Guardar como plantilla». Los textos van en ASSISTANT.AI_FOLLOW_UP.STARTERS.<KEY>.
export const STARTERS = {
  COLLECTION: {
    max_attempts: 3,
    interval_value: 2,
    interval_unit: 'days',
    on_finish: 'notify',
  },
  QUOTE: {
    max_attempts: 3,
    interval_value: 2,
    interval_unit: 'days',
    on_finish: 'notify',
  },
  APPOINTMENT: {
    max_attempts: 2,
    interval_value: 4,
    interval_unit: 'hours',
    on_finish: 'assign',
  },
  REACTIVATE: {
    max_attempts: 3,
    interval_value: 5,
    interval_unit: 'days',
    on_finish: 'notify',
  },
};

export const STARTER_KEYS = Object.keys(STARTERS);
