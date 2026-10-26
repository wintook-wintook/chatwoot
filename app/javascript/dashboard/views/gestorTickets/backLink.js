// «Volver» al origen: la pantalla que abre una orden o una cotización le manda
// `?back=<su ruta>` y el botón regresa ahí, con su texto («Volver a Despacho»…).
// Solo rutas internas de la app; sin `back` cada pantalla usa su lista.

export const backPath = route => {
  const back = route.query.back;
  return typeof back === 'string' && back.startsWith('/app/') ? back : null;
};

// Qué es la pantalla de origen, para el texto del botón (CASE_TICKETS.BACK_TO.*).
export const backKind = path => {
  const bare = (path || '').split('?')[0];
  if (bare.endsWith('/tickets/metrics')) return 'METRICS';
  if (bare.endsWith('/tickets/dispatch')) return 'DISPATCH';
  if (/\/tickets\/quotes\/\d+$/.test(bare)) return 'QUOTE';
  if (/\/tickets\/\d+$/.test(bare)) return 'CASE';
  if (bare.includes('/conversations/')) return 'CONVERSATION';
  if (bare.includes('/contacts/')) return 'CONTACT';
  return 'OTHER';
};

// Para mandar como `query.back` desde la pantalla actual.
export const backQuery = (route, extra = {}) => {
  const query = new URLSearchParams(
    Object.entries({ ...route.query, ...extra }).filter(
      ([key, value]) => key !== 'back' && value != null && value !== ''
    )
  ).toString();
  return { back: query ? `${route.path}?${query}` : route.path };
};
