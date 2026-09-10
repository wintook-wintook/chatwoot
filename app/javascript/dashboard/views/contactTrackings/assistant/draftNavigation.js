// proyecto@asistente_agentes_ia — SALTAR A UN PUNTO DEL ENTRENAMIENTO
// ============================================================================
// El informe del comprobador es también el índice: tocar una rama o un hallazgo
// lleva a esa línea del texto. En un Entrenamiento de 645 líneas —los hay en
// producción— saber que "la rama comercial no tiene descripción" no sirve de
// nada si después hay que buscarla a mano.
//
// Vive fuera del componente por una razón concreta: así se puede probar sin
// montar la vista entera (que necesita store, router e i18n). La regla del
// límite de nombre de acá abajo se rompe sola y en silencio, y es justo el tipo
// de cosa que un spec tiene que sostener.
// ============================================================================

// Después del nombre de la rama solo puede venir su etiqueta, los dos puntos de
// la descripción, o el paréntesis de cierre.
const NAME_BOUNDARY = ' \t#:)';

/**
 * Número de línea (1-based) donde se declara una rama, o null.
 *
 * Se busca en el texto en vez de pedírselo al backend porque RouteMap no
 * registra la línea de cada rama, y agregárselo sería tocar el parser de
 * producción por una comodidad de la pantalla. Acá alcanza: los nombres de rama
 * son únicos (RouteMap hace uniq(&:name)) y la línea siempre empieza con
 * @ruta(nombre.
 */
export function findRouteLine(draft, name) {
  if (!draft || !name) return null;

  const needle = `@ruta(${name}`.toLowerCase();
  const index = draft.split('\n').findIndex(text => {
    const line = text.trimStart().toLowerCase();
    if (!line.startsWith(needle)) return false;

    // Sin esto, una rama llamada "sop" salta a la línea de "soporte".
    return NAME_BOUNDARY.includes(line.charAt(needle.length));
  });

  return index === -1 ? null : index + 1;
}

/**
 * Rango de caracteres [inicio, fin] de una línea (1-based), o null si no existe.
 * Se devuelve la línea ENTERA para poder seleccionarla: en un monoespaciado de
 * cientos de líneas, "algo se movió" no le dice a nadie cuál es.
 */
export function lineRange(draft, line) {
  if (!line || line < 1) return null;

  const lines = draft.split('\n');
  if (line > lines.length) return null;

  const start = lines
    .slice(0, line - 1)
    .reduce((total, text) => total + text.length + 1, 0);

  return [start, start + lines[line - 1].length];
}
