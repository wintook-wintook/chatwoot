// proyecto@diagrama_agente_ia — F5: EL DIAGRAMA COMO ARCHIVO
// ============================================================================
// Plan: docs/diagrama_agente_ia_plan.md §6.6. El diagrama se pinta con clases de
// Tailwind (fill-/stroke-, modo oscuro, temas): fuera del dashboard esas clases no
// existen y un SVG copiado tal cual sale negro sobre transparente. Por eso al
// exportar se copia cada estilo YA CALCULADO al atributo del elemento, y se le pone
// el fondo del panel: el archivo se ve como se veía en pantalla, en claro u oscuro.
//
// PNG: el mismo SVG dibujado en un canvas al doble de tamaño (se lee bien al
// pegarlo en un documento o en un chat).
// ============================================================================

const SVG_NS = 'http://www.w3.org/2000/svg';
const STYLE_PROPS = [
  'fill',
  'stroke',
  'stroke-width',
  'stroke-dasharray',
  'opacity',
  'font-size',
  'font-weight',
  'font-family',
  'text-anchor',
  'letter-spacing',
  'text-transform',
];

// Recorre el original y la copia a la par: el original tiene los estilos calculados.
export function inlineStyles(original, copia, view = window) {
  const estilo = view.getComputedStyle(original);
  const reglas = STYLE_PROPS.map(prop => [prop, estilo.getPropertyValue(prop)])
    .filter(([, valor]) => valor && valor !== 'none' && valor !== 'normal')
    .map(([prop, valor]) => `${prop}:${valor}`);
  if (reglas.length) copia.setAttribute('style', reglas.join(';'));
  copia.removeAttribute('class');
  Array.from(original.children).forEach((hijo, i) => {
    if (copia.children[i]) inlineStyles(hijo, copia.children[i], view);
  });
}

// El texto del SVG listo para guardar, con su fondo.
export function svgMarkup(svg, background = '#ffffff', view = window) {
  const copia = svg.cloneNode(true);
  inlineStyles(svg, copia, view);
  copia.setAttribute('xmlns', SVG_NS);
  copia.removeAttribute('role');
  const fondo = view.document.createElementNS(SVG_NS, 'rect');
  fondo.setAttribute('width', '100%');
  fondo.setAttribute('height', '100%');
  fondo.setAttribute('fill', background);
  copia.insertBefore(fondo, copia.firstChild);
  return new XMLSerializer().serializeToString(copia);
}

const save = (blob, nombre) => {
  const enlace = document.createElement('a');
  enlace.href = URL.createObjectURL(blob);
  enlace.download = nombre;
  enlace.click();
  URL.revokeObjectURL(enlace.href);
};

export function downloadSvg(svg, nombre, background) {
  const texto = svgMarkup(svg, background);
  save(new Blob([texto], { type: 'image/svg+xml;charset=utf-8' }), nombre);
}

export function downloadPng(svg, nombre, background, escala = 2) {
  const texto = svgMarkup(svg, background);
  const ancho = Number(svg.getAttribute('width')) * escala;
  const alto = Number(svg.getAttribute('height')) * escala;
  return new Promise((resolve, reject) => {
    const imagen = new Image();
    imagen.onload = () => {
      const lienzo = document.createElement('canvas');
      lienzo.width = ancho;
      lienzo.height = alto;
      lienzo.getContext('2d').drawImage(imagen, 0, 0, ancho, alto);
      lienzo.toBlob(blob => {
        if (!blob) {
          reject(new Error('png'));
          return;
        }
        save(blob, nombre);
        resolve();
      }, 'image/png');
    };
    imagen.onerror = reject;
    imagen.src = `data:image/svg+xml;charset=utf-8,${encodeURIComponent(
      texto
    )}`;
  });
}
