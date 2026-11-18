import { wordDiff, diffHtml } from '../wordDiff';

// proyecto@arreglar_predefinidas F2 — los cambios palabra por palabra.
describe('wordDiff', () => {
  it('marca solo lo que cambió', () => {
    expect(wordDiff('Llamenos al 55 1234', 'Llámenos al 55 1234')).toEqual([
      { type: 'del', text: 'Llamenos ' },
      { type: 'ins', text: 'Llámenos ' },
      { type: 'same', text: 'al 55 1234' },
    ]);
  });

  it('escapa el HTML del texto', () => {
    const html = diffHtml('<b>hola</b>', '<b>hola</b> mundo');
    expect(html).not.toContain('<b>');
    expect(html).toContain('&lt;b&gt;hola&lt;/b&gt;');
    expect(html).toContain('<ins');
  });
});
