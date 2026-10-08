// proyecto@asistente_agentes_ia — fase C de PROMPT STUDIO
// ============================================================================
// Las marcas <PENDIENTE: …> de un borrador que se arma a la vista. La regla es la
// misma que en el backend (ContactTrackings::Assistant::PendingMarkers): si las
// dos difieren, la pantalla diría "terminado" sobre algo que no se puede guardar.
// ============================================================================
const PENDING_RE = /<\s*(?:PENDIENTE|PENDING)\b[^>]*>/gi;

export const PENDING_CODE = 'pending_marker';

export const pendingCount = text =>
  (String(text || '').match(PENDING_RE) || []).length;

// Hallazgos bloqueantes que NO son marcas: los que sí son un problema.
export const realBlocking = validation =>
  (validation?.blocking || []).filter(finding => finding.code !== PENDING_CODE);
