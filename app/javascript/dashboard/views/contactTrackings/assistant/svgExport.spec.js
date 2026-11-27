import { inlineStyles, svgMarkup } from './svgExport';

// proyecto@diagrama_agente_ia F5 — el diagrama como archivo
const svgDe = html => {
  document.body.innerHTML = html;
  return document.body.querySelector('svg');
};

describe('svgExport', () => {
  it('copia los estilos calculados al elemento y quita las clases', () => {
    const svg = svgDe(
      '<svg width="10" height="10"><rect class="fill-woot-50" style="fill: rgb(1, 2, 3)"></rect></svg>'
    );
    const copia = svg.cloneNode(true);

    inlineStyles(svg, copia);

    const rect = copia.querySelector('rect');
    expect(rect.getAttribute('class')).toBeNull();
    expect(rect.getAttribute('style')).toContain('fill:rgb(1, 2, 3)');
  });

  it('el archivo lleva el espacio de nombres y su fondo, sin tocar el original', () => {
    const svg = svgDe(
      '<svg width="10" height="10" role="img"><text class="x">hola</text></svg>'
    );

    const texto = svgMarkup(svg, 'rgb(15, 23, 42)');

    expect(texto).toContain('xmlns="http://www.w3.org/2000/svg"');
    expect(texto).toContain('fill="rgb(15, 23, 42)"');
    expect(texto).toContain('hola');
    expect(texto).not.toContain('role=');
    expect(svg.querySelector('text').getAttribute('class')).toBe('x');
  });
});
