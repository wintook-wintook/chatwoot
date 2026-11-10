// K1 — dos personas en el mismo caso. Al cambiar algo se manda lo que el usuario VIO
// (`expected`, o el estado/etapa de donde parte). Si en el servidor ya es otro (lo cambió
// alguien más), contesta 409 y aquí se avisa a la ventana de conflicto (CaseConflictModal)
// con la forma de reintentar a la fuerza («Usar el mío»).
import { emitter } from 'shared/helpers/mitt';

export const CONFLICT_EVENT = 'caseConflict';

// El caso tal como lo tiene la pantalla: lista, tablero o el activo de un contacto.
export const findCaseTicket = (state, id) => {
  if (!state) return null;
  const n = Number(id);
  return (
    (state.ticketsList || []).find(t => t.id === n) ||
    (state.boardTickets || []).find(t => t.id === n) ||
    Object.values(state.activeTickets || {}).find(t => t && t.id === n) ||
    null
  );
};

// De los campos que se mandan, el valor que se veía (solo los que la pantalla conoce).
export const expectedFields = (ticket, fields = {}) => {
  if (!ticket) return undefined;
  const out = {};
  Object.keys(fields).forEach(key => {
    if (key === 'custom_attributes' && fields.custom_attributes) {
      const seen = ticket.custom_attributes || {};
      out.custom_attributes = Object.fromEntries(
        Object.keys(fields.custom_attributes).map(k => [k, seen[k] ?? null])
      );
    } else if (key in ticket) {
      out[key] = ticket[key] ?? null;
    }
  });
  return Object.keys(out).length ? out : undefined;
};

const sameValue = (a, b) => String(a ?? '') === String(b ?? '');

// De lo que manda un formulario, solo lo que el usuario CAMBIÓ respecto a lo que veía
// (así no regresa al valor viejo lo que otro cambió en otro campo), y lo que veía de eso.
// Las claves que la pantalla no conoce se mandan tal cual.
export const changedFields = (ticket, fields = {}) => {
  if (!ticket) return { payload: fields, expected: undefined };
  const payload = {};
  Object.entries(fields).forEach(([key, value]) => {
    if (key === 'custom_attributes' && value) {
      const seen = ticket.custom_attributes || {};
      const changed = Object.fromEntries(
        Object.entries(value).filter(([k, v]) => !sameValue(v, seen[k]))
      );
      if (Object.keys(changed).length) payload.custom_attributes = changed;
    } else if (!(key in ticket) || !sameValue(value, ticket[key])) {
      payload[key] = value;
    }
  });
  // Nada cambió: se manda igual (sin `expected`), para no romper a quien espera respuesta.
  if (!Object.keys(payload).length)
    return { payload: fields, expected: undefined };
  return { payload, expected: expectedFields(ticket, payload) };
};

// De qué estado (y etapa) parte un cambio de estado.
export const expectedState = (ticket, withColumn = false) => {
  if (!ticket) return {};
  const out = { expected_status: ticket.status };
  if (withColumn && ticket.case_type_column_id) {
    out.expected_column_id = ticket.case_type_column_id;
  }
  return out;
};

// Llama `send(opciones)`; ante conflicto avisa con `retry` (= send({ force: true })).
export const guarded = async send => {
  try {
    return await send({});
  } catch (error) {
    const data = error.response && error.response.data;
    if (
      error.response &&
      error.response.status === 409 &&
      data &&
      data.conflict
    ) {
      emitter.emit(CONFLICT_EVENT, {
        ...data,
        retry: () => send({ force: true }),
      });
    }
    throw error;
  }
};
