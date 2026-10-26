// proyecto@asistente_agentes_ia — CUÁNTO VAN LAS INSTRUCCIONES INICIALES
// ============================================================================
// Las instrucciones que se llenan conversando (DraftingChat) siguen la plantilla:
// una sección por título ##. Una sección cuenta como llena si tiene texto propio,
// sin contar sus subtítulos vacíos ni las notas <!-- -->.
// ============================================================================

const sinNotas = texto => texto.replace(/<!--[\s\S]*?-->/g, '');

// { sections: [{ title, filled }], filled, total }
export const instructionsProgress = (md = '') => {
  const sections = [];
  let actual = null;
  sinNotas(md)
    .split('\n')
    .forEach(linea => {
      const titulo = linea.match(/^##\s+(.+?)\s*$/);
      if (titulo) {
        actual = { title: titulo[1], filled: false };
        sections.push(actual);
        return;
      }
      if (!actual) return;
      const texto = linea.replace(/^#{3,}\s*/, '').replace(/^[-*]\s*/, '');
      if (!/^#{3,}/.test(linea) && texto.trim()) actual.filled = true;
    });
  return {
    sections,
    filled: sections.filter(s => s.filled).length,
    total: sections.length,
  };
};

// "# Instrucciones iniciales: Leo" → "instrucciones_leo.md"
export const instructionsFilename = (md = '') => {
  const titulo = (md.match(/^#\s+Instrucciones iniciales:\s*(.+)$/m) || [])[1];
  const slug = (titulo || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');
  return slug ? `instrucciones_${slug}.md` : 'instrucciones_iniciales.md';
};
