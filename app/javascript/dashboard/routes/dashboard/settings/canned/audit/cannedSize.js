// proyecto@auditoria_predefinidas — EL TAMAÑO QUE VE EL AGENTE
// ============================================================================
// Lo que el agente recibe de una predefinida es «nombre: contenido»
// (KnowledgeItemSyncJob#extract_content) hasta MAX_CHARS
// (KnowledgeBaseResponseService::MAX_ITEM_CHARS). Si pasa, recibe el nombre y las
// secciones que más se parecen a la pregunta (KnowledgeBase::SectionFit), no todo.
// Mismos números que CannedResponses::Audit::Report.
// ============================================================================
export const MAX_CHARS = 2000;
export const WARN_CHARS = 1600;

export const agentChars = (shortCode, content) =>
  `${shortCode || ''}: ${content || ''}`.length;

// 'ok' | 'near' | 'over'
export const sizeLevel = chars => {
  if (chars > MAX_CHARS) return 'over';
  if (chars > WARN_CHARS) return 'near';
  return 'ok';
};

// Los bloques como los parte SectionFit: párrafos separados por línea en blanco; un
// encabezado suelto (una línea, en mayúsculas, ≤ 60) va con el párrafo que sigue.
const isHeading = block =>
  !block.includes('\n') &&
  block.length <= 60 &&
  block === block.toUpperCase() &&
  /\p{L}/u.test(block);

export const blocksOf = text =>
  (text || '')
    .split(/\n\s*\n/)
    .map(b => b.trim())
    .filter(Boolean)
    .reduce((out, block) => {
      if (out.length && isHeading(out[out.length - 1])) {
        out[out.length - 1] = `${out[out.length - 1]}\n\n${block}`;
      } else {
        out.push(block);
      }
      return out;
    }, []);

// Clases de color por nivel (texto y barra), en claro y oscuro.
export const LEVEL_TEXT = {
  ok: 'text-green-700 dark:text-green-400',
  near: 'text-amber-700 dark:text-amber-400',
  over: 'text-red-700 dark:text-red-400',
};
export const LEVEL_BAR = {
  ok: 'bg-green-500',
  near: 'bg-amber-500',
  over: 'bg-red-500',
};
