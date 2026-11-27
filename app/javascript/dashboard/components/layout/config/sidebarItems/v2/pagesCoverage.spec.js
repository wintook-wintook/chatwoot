// Dali (Assistant::Pages) liga y abre las pantallas de config/assistant/pages.json.
// Esta prueba revisa que cada opción del menú esté ahí: si agregas una pantalla al
// menú, agrégala también a pages.json (clave, path y nombre como en el menú) y, si
// hace falta, a la guía que la explica (config/assistant/guides, `pages:`).
import pagesFile from '../../../../../../../../config/assistant/pages.json';
import { getSidebarItemsV2, primaryMenuV2 } from './index';

const ACCOUNT = 1;
const PREFIX = `/app/accounts/${ACCOUNT}/`;
const withoutQuery = path => path.split('?')[0];

const menuPaths = () => {
  const paths = new Set();
  const walk = items =>
    (items || []).forEach(item => {
      if (item.toState && item.toState.startsWith(PREFIX)) {
        paths.add(withoutQuery(item.toState.slice(PREFIX.length)));
      }
      walk(item.children);
    });
  // Ventas y Servicio cambian de menú según la ruta: se recorren las dos.
  // Los botones `hidden` (CrmZeus, se entra con Ctrl+L) y su submenú no van a
  // pages.json: Dali no debe ligar ni mencionar lo que está oculto.
  ['home', 'tickets_list'].forEach(name => {
    const route = { name, params: {} };
    const primary = primaryMenuV2(ACCOUNT, route);
    const hidden = new Set(primary.filter(i => i.hidden).map(i => i.key));
    walk(primary.filter(i => !i.hidden));
    getSidebarItemsV2(ACCOUNT, route)
      .secondaryMenu.filter(menu => !hidden.has(menu.parentNav))
      .forEach(menu => walk(menu.menuItems));
  });
  return [...paths];
};

describe('Pantallas de Dali (config/assistant/pages.json)', () => {
  const pages = Object.entries(pagesFile.pages);
  const known = new Set(pages.map(([, page]) => withoutQuery(page.path)));

  it('cada opción del menú tiene su pantalla para que Dali la ligue', () => {
    const missing = menuPaths().filter(path => !known.has(path));
    expect(missing).toEqual([]);
  });

  it('cada pantalla trae path y nombre', () => {
    pages.forEach(([key, page]) => {
      expect(key).toMatch(/^[a-z_]+$/);
      expect(page.path).toBeTruthy();
      expect(page.path.startsWith('/')).toBe(false);
      expect(page.label).toBeTruthy();
    });
  });
});
