// proyecto@asistente_agentes_ia — fase A de PROMPT STUDIO
// ============================================================================
// Qué cambió en una edición, listo para dibujar. Lo que llega del backend son dos
// cosas distintas y se muestran distinto:
//   summary  lo que el MODELO dice que cambió, en palabras
//   touched  lo que cambió DE VERDAD (DraftDiff), pieza por pieza
// Medido sobre el v6.11: el modelo declara de menos. Por eso lo real se muestra
// siempre, y lo que tocó sin mencionarlo va marcado.
// ============================================================================

// Orden de lectura: primero lo que se quitó —es lo que más cuesta notar—, después
// lo que cambió, al final lo agregado.
const KIND_ORDER = { removed: 0, changed: 1, added: 2 };

export const changeRows = changes => {
  const touched = Array.isArray(changes?.touched) ? changes.touched : [];

  return [...touched]
    .filter(row => row && row.key && KIND_ORDER[row.kind] !== undefined)
    .sort((a, b) => KIND_ORDER[a.kind] - KIND_ORDER[b.kind])
    .map(row => ({
      key: row.key,
      kind: row.kind,
      undeclared: row.declared === false,
    }));
};

export const hasChanges = changes =>
  changeRows(changes).length > 0 ||
  (Array.isArray(changes?.summary) && changes.summary.length > 0);
