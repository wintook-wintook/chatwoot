import { renderWithPageLinks, pageLinkFromEvent } from '../assistantPageLinks';

const plain = text => `<p>${text}</p>`;

describe('assistantPageLinks', () => {
  it('vuelve liga la marca [[ruta|Nombre]]', () => {
    const html = renderWithPageLinks(
      'Entra a [[/app/accounts/1/tickets/commercial/board|Ventas › Oportunidades]] y pulsa «Nueva».',
      plain
    );
    expect(html).toContain(
      '<a href="/app/accounts/1/tickets/commercial/board" class="dali-page-link" data-dali-path="/app/accounts/1/tickets/commercial/board">Ventas › Oportunidades</a>'
    );
    expect(html).not.toContain('[[');
  });

  it('respeta la consulta (?tab=…) y escapa el nombre', () => {
    const html = renderWithPageLinks(
      '[[/app/accounts/1/start?tab=my_day|<b>Mi día</b>]]',
      plain
    );
    expect(html).toContain('data-dali-path="/app/accounts/1/start?tab=my_day"');
    expect(html).toContain('&lt;b&gt;Mi día&lt;/b&gt;');
  });

  it('no toca marcas que no son rutas de la cuenta', () => {
    const html = renderWithPageLinks('[[javascript:alert(1)|x]]', plain);
    expect(html).not.toContain('<a');
  });

  it('lee la ruta del clic', () => {
    const a = document.createElement('a');
    a.dataset.daliPath = '/app/accounts/1/contacts';
    const span = document.createElement('span');
    a.appendChild(span);
    expect(pageLinkFromEvent({ target: span })).toBe(
      '/app/accounts/1/contacts'
    );
    expect(pageLinkFromEvent({ target: document.createElement('p') })).toBe(
      null
    );
  });
});
