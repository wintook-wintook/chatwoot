// proyecto@crear_agente_conversando — F3: LAS PESTAÑAS QUE LLENA LA CONVERSACIÓN
// ============================================================================
// Plan: docs/creacion_conversacional_agentes_plan.md §6. Mientras se arma un agente
// conversando, el chat llena la Definición (objective, ai_context) y el texto de
// [VARIABLES] y [DATOS FIJOS] (ContactTrackings::Assistant::DraftingFields). Todo vive
// en `proposal` de la conversación. Aquí se pasa de ese texto a lo que muestran y
// editan los modales de F1/F2, y de vuelta: el mismo formato que el motor.
// ============================================================================
import { parseVariables, serializeVariables } from './agentVariables';
import { parseConstants, serializeConstants } from './agentConstants';

export const FIELD_KEYS = [
  'objective',
  'ai_context',
  'variables',
  'datos_fijos',
];

// Lo que se manda en cada turno: solo las cuatro llaves, en texto.
export const fieldsOf = proposal =>
  Object.fromEntries(
    FIELD_KEYS.map(llave => [llave, ((proposal || {})[llave] || '').trim()])
  );

export const variablesOf = body => parseVariables(body || '');
export const constantsOf = body => parseConstants(body || '');
export const variablesBody = value => serializeVariables(value);
export const constantsBody = value => serializeConstants(value);

// Cuántas de las tres pestañas tienen algo (Definición cuenta si hay Objetivo o Contexto).
export const filledCount = proposal => {
  const f = fieldsOf(proposal);
  return [f.objective || f.ai_context, f.variables, f.datos_fijos].filter(
    Boolean
  ).length;
};
