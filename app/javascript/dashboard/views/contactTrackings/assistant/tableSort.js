// proyecto@asistente_agentes_ia — ORDEN POR ENCABEZADO
// ============================================================================
// Lo usan las dos tablas del Asistente: Conversaciones y Agentes IA. UNA sola
// definición a propósito — dos comparadores para dos tablas de la misma pantalla
// se separan, y el que se queda atrás no falla: ordena distinto.
//
// Vive fuera de los componentes para poder probarlo. Un comparador se rompe en
// los bordes —la celda vacía, el número que llega como texto, el empate— y
// ninguno de esos casos se ve mirando la pantalla: se ve como "el orden quedó
// raro".
//
// EL ORDEN ES DEL LADO DEL CLIENTE, a propósito. Las dos listas llegan completas:
// las conversaciones topan en 50 (TrackingAssistantSession::LIST_LIMIT) y la
// auditoría recorre los agentes de la cuenta de una sola vez. Ordenar en servidor
// sería un viaje de red por cada clic en un encabezado.
//
// CADA TABLA DECLARA EL TIPO DE SUS COLUMNAS, y esa declaración es también la
// lista de lo ordenable: una columna sin declarar no se ordena. Así no puede
// pasar que una columna sea ordenable pero se compare como texto por descuido —
// que es como 10 termina antes que 9.
// ============================================================================

export const NUMBER = 'number';
export const DATE = 'date';
export const TEXT = 'text';

function value(row, key, type) {
  if (type === NUMBER) return Number(row[key]) || 0;
  if (type === DATE) return new Date(row[key] || 0).getTime();

  return (row[key] || '').toString().toLowerCase();
}

/**
 * Copia ordenada de `rows`. `columns` es el mapa {campo: tipo} de esa tabla.
 *
 * Una celda vacía se compara como cadena vacía (o como 0), así que en asc queda
 * primero y en desc última. No se le da trato especial: agruparlas aparte haría
 * que el orden inverso dejara de ser el inverso, y eso confunde más que ayuda.
 *
 * NO muta `rows`: es el arreglo que llega del backend, y mutarlo haría que el
 * orden dependiera de cuántas veces se tocó el encabezado.
 */
export function sortRows(rows, sort, columns) {
  const type = columns[sort?.key];
  if (!type) return [...rows];

  const sign = sort.order === 'asc' ? 1 : -1;
  return [...rows].sort((a, b) => {
    const left = value(a, sort.key, type);
    const right = value(b, sort.key, type);
    // Desempate por id, para que el orden sea estable: sin esto dos filas con la
    // misma fecha se intercambian entre repintados y la tabla parpadea.
    if (left === right) return (a.id || 0) - (b.id || 0);

    return left > right ? sign : -sign;
  });
}

/**
 * Qué orden sigue al tocar un encabezado. Una columna nueva arranca en DESC: en
 * fechas, ids y cantidades lo que se busca es lo más nuevo o lo más grande.
 */
export function nextOrder(current, key) {
  if (current?.key !== key) return { key, order: 'desc' };

  return { key, order: current.order === 'desc' ? 'asc' : 'desc' };
}
