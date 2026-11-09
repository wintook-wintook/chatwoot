// fix/archivos_varios — NOMBRES DE LOS ARCHIVOS DEL AGENTE
// ============================================================================
// El nombre es la clave de la directiva {{nombre}}: letras, números, guion y guion
// bajo, hasta 60, único en el agente sin importar mayúsculas (AiAgentAttachment).
// Al subir varios a la vez, cada archivo trae su nombre sugerido y, si choca con uno
// que ya existe (o con otro de la misma tanda), se le agrega -2, -3…
// ============================================================================

export const NAME_FORMAT = /^[a-zA-Z0-9_-]+$/;
export const MAX_NAME = 60;

// «Catálogo 2026.pdf» → «catalogo-2026»
export const nameFromFile = filename => {
  const base = (filename || '')
    .replace(/\.[^.]+$/, '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, MAX_NAME);
  return base || 'archivo';
};

export const isValidName = name =>
  !!name && name.length <= MAX_NAME && NAME_FORMAT.test(name);

// El primero libre entre base, base-2, base-3… (sin pasar de 60).
export const uniqueName = (base, taken) => {
  const ocupados = new Set([...taken].map(n => n.toLowerCase()));
  if (!ocupados.has(base.toLowerCase())) return base;
  let n = 2;
  for (;;) {
    const sufijo = `-${n}`;
    const candidato = base.slice(0, MAX_NAME - sufijo.length) + sufijo;
    if (!ocupados.has(candidato.toLowerCase())) return candidato;
    n += 1;
  }
};

// ¿Este nombre choca con los del agente o con otro de la misma tanda?
export const isTaken = (name, existing, others) =>
  [...existing, ...others].some(
    n => (n || '').toLowerCase() === (name || '').toLowerCase()
  );
