// Portal de Dali — al abrir algo de la plataforma desde el portal (una cotización,
// un caso), se guarda de dónde vino para mostrar «Volver a Dali» (Dashboard.vue).
// En la app instalada del iPhone no hay botón de atrás: sin esto no habría regreso.
const KEY = 'kontrolya.dali.return';

export const markDaliReturn = path => {
  try {
    window.sessionStorage.setItem(KEY, path);
  } catch {
    // Sin almacenamiento: no se muestra «Volver a Dali».
  }
};

export const daliReturnPath = () => {
  try {
    return window.sessionStorage.getItem(KEY);
  } catch {
    return null;
  }
};

export const clearDaliReturn = () => {
  try {
    window.sessionStorage.removeItem(KEY);
  } catch {
    // nada
  }
};
