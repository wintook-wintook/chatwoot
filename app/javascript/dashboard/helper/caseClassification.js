// @tickets_cases — Plan-Clase-Comercial F2: clasificación por tipo de caso.
// Un servicio/categoría con `case_type_id` null es global (aplica a todos los
// tipos); con valor, solo se ofrece para ese tipo. Las subcategorías heredan el
// tipo de su categoría raíz, así que basta con filtrar las raíces.

export const appliesToType = (item, typeId) =>
  item.case_type_id === null ||
  item.case_type_id === undefined ||
  item.case_type_id === typeId;

export const forType = (list, typeId) =>
  (list || []).filter(item => appliesToType(item, typeId));

// ¿El id elegido sigue disponible para el tipo? (para limpiar al cambiar de tipo)
export const idAvailable = (list, id) =>
  !id ||
  (list || []).some(
    item =>
      item.id === id || (item.subcategories || []).some(sub => sub.id === id)
  );
