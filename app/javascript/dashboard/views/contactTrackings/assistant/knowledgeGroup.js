// proyecto@asistente_agentes_ia — CONOCIMIENTO SUGERIDO, DEL LADO DE LA PANTALLA
// ============================================================================
// Las respuestas predefinidas de un agente llevan un prefijo común («PATITAS …») y
// la ruta busca solo en ese grupo: @buscar_predefinidas(PATITAS). Ver
// KnowledgeSuggestions en el backend.
// ============================================================================

const PENDING_RE = /<\s*(?:PENDIENTE|PENDING)\b[^>]*>/i;
// Solo la directiva sin grupo: una con grupo ya eligió dónde buscar.
const BARE_CANNED_RE = /@buscar_predefinidas(?!\s*\()/gi;

export const hasPending = text => PENDING_RE.test(text || '');

// Lo que se puede crear: sin <PENDIENTE:> y con texto.
export const creatable = item =>
  item.status !== 'existing' &&
  Boolean((item.content || '').trim()) &&
  !hasPending(item.content);

// Qué mostrar de cada una, según cómo está AHORA (se pudo editar el texto).
export const itemState = item => {
  if (item.status === 'existing') return 'existing';
  if (hasPending(item.content)) return 'missing';
  if ((item.unverified || []).length && !item.checkedByHand)
    return 'unverified';
  return 'ready';
};

// Las rutas del Entrenamiento que buscan en TODAS las predefinidas pasan a buscar
// solo en las del agente. Solo en las líneas @ruta: en la prosa la directiva no se
// ejecuta (y el comprobador ya lo marca).
export const withCannedGroup = (draft, group) =>
  (draft || '')
    .split('\n')
    .map(linea =>
      /^\s*@ruta\(/i.test(linea)
        ? linea.replace(BARE_CANNED_RE, `@buscar_predefinidas(${group})`)
        : linea
    )
    .join('\n');
