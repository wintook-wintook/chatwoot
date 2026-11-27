// proyecto@crear_agente_conversando — F2: ESCRIBIR «%» OFRECE LOS DATOS FIJOS
// ============================================================================
// Al teclear «%» al empezar una palabra, aparece la lista de datos fijos; elegir uno
// cambia ese «%» por «%NOMBRE%». Un «%» pegado a un número («30%») no abre nada.
// Funciones PURAS sobre el texto y la posición del cursor (las usan el modal de
// sección y el editor del Entrenamiento).
// ============================================================================

// ¿El cursor quedó justo después de un «%» que empieza una cita?
export const percentTriggerAt = (text, caret) => {
  if (!text || caret < 1 || text[caret - 1] !== '%') return false;
  const antes = caret >= 2 ? text[caret - 2] : '';
  return !/[\p{L}\d_%]/u.test(antes);
};

// Cambia el «%» que está antes del cursor por «%NOMBRE%» y deja el cursor después.
export const insertConstant = (text, caret, name) => {
  const cita = `%${name}%`;
  const inicio = caret - 1;
  return {
    text: text.slice(0, inicio) + cita + text.slice(caret),
    caret: inicio + cita.length,
  };
};
