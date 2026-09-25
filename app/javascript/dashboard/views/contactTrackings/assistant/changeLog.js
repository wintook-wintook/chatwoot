// proyecto@asistente_agentes_ia — LA BITÁCORA DE CAMBIOS DEL ENTRENAMIENTO
// ============================================================================
// Pedido del usuario (25/09/2026): ver paso a paso qué cambió, quién y cuándo, como
// un registro aparte. Sale de las versiones de la sesión (TrackingAssistantSession):
// cada una trae qué piezas cambiaron, cuántas líneas y lo que declaró el Asistente.
// ============================================================================

// De la más nueva a la más vieja: es lo que se quiere ver primero.
export const logEntries = (versions = []) =>
  [...versions].reverse().map(v => ({
    n: v.n,
    at: v.at,
    source: v.autosaved ? 'autosave' : v.source,
    summary: v.summary || '',
    changes: v.changes || [],
    notes: v.notes || [],
    added: v.lines?.added ?? null,
    removed: v.lines?.removed ?? null,
  }));

// La bitácora como .md, para descargarla. `t` traduce, `formatDate` da la fecha.
export const changeLogMarkdown = (versions, t, formatDate, title = '') => {
  const partes = [`# ${t('LOG_MD_TITLE')}${title ? ` — ${title}` : ''}`];
  logEntries(versions).forEach(e => {
    const lineas = [
      `## ${t('LOG_VERSION', { n: e.n })} · ${formatDate(e.at)} · ${t(
        `LOG_SOURCE_${e.source.toUpperCase()}`
      )}`,
    ];
    if (e.summary) lineas.push(e.summary);
    if (e.added !== null)
      lineas.push(t('LOG_LINES', { added: e.added, removed: e.removed }));
    e.changes.forEach(c => lineas.push(`- ${c}`));
    e.notes.forEach(n => lineas.push(`  - ${n}`));
    partes.push(lineas.join('\n'));
  });
  return `${partes.join('\n\n')}\n`;
};
