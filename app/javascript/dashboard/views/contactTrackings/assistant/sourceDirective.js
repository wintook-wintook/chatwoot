// proyecto@asistente_agentes_ia — DE LA DIRECTIVA DE UNA RUTA A LA FUENTE QUE NOMBRA
// ============================================================================
// Pedido del usuario (25/09/2026): si la ruta nombra una fuente que no existe en la
// cuenta, poder crearla desde el Asistente sin salir de él. Esto dice qué tipo de
// fuente y con qué nombre abrir el modal de la Base de Conocimiento (AddSourceModal).
// ============================================================================

// El Asistente escucha esto para recargar su lista de fuentes y volver a comprobar.
export const ASSISTANT_SOURCES_CHANGED = 'assistant:sources-changed';

const PATTERNS = [
  [/\{\{\s*hoja\s*:\s*([^}]+?)\s*\}\}/i, 'google_sheet'],
  [/\{\{\s*doc\s*:\s*([^}]+?)\s*\}\}/i, 'google_doc'],
  [/@buscar_foro\(\s*([^)]+?)\s*\)/i, 'discourse'],
  [/@soporte_contpaq\(\s*([^)]+?)\s*\)/i, 'contpaq_support'],
];

// { source_type, name } o null si no es una fuente que se crea en la Base de
// Conocimiento (una directiva de predefinidas o de artículos no lo es).
export const sourceFromDirective = directive => {
  const texto = directive || '';
  const hallado = PATTERNS.find(([patron]) => patron.test(texto));
  if (!hallado) return null;
  const [patron, tipo] = hallado;
  return { source_type: tipo, name: texto.match(patron)[1] };
};
