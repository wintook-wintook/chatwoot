import { engineCatalogMarkdown } from './engineCatalogMarkdown';

// La traducción de prueba devuelve la clave: así se ve qué texto va en cada lugar.
const t = clave => clave.replace('TRACKING_ASSISTANT_VIEW.', '');

describe('engineCatalogMarkdown', () => {
  const catalog = [
    {
      key: 'hoja',
      group: 'sources',
      syntax: '{{hoja:nombre}}',
      status: 'ready',
      items: ['{{hoja:facturas}}', '{{hoja:Precios}}'],
    },
    {
      key: 'agendar',
      group: 'actions',
      syntax: '@agendar_calendar',
      status: 'missing',
      items: [],
    },
  ];

  it('arma el documento por grupos, con cada ficha y lo que tiene la cuenta', () => {
    const md = engineCatalogMarkdown(catalog, t, {
      accountName: 'Wintook',
      date: new Date(2026, 8, 23),
    });

    expect(md).toContain('# CATALOG_MD_TITLE');
    expect(md).toContain('CATALOG_MD_ACCOUNT: Wintook');
    expect(md).toContain('## CATALOG_GROUP_SOURCES');
    expect(md).toContain('### `{{hoja:nombre}}` — CATALOG_STATUS_READY');
    expect(md).toContain(
      '**CATALOG_IN_ACCOUNT** `{{hoja:facturas}}` · `{{hoja:Precios}}`'
    );
    expect(md).toContain('**CATALOG_NEEDS** CATALOG_AGENDAR_NEEDS');
    expect(md.indexOf('CATALOG_GROUP_SOURCES')).toBeLessThan(
      md.indexOf('CATALOG_GROUP_ACTIONS')
    );
  });

  it('no escribe «En tu cuenta» si la cuenta no tiene nada', () => {
    const md = engineCatalogMarkdown([catalog[1]], t);

    expect(md).not.toContain('CATALOG_IN_ACCOUNT');
    expect(md).not.toContain('CATALOG_GROUP_SOURCES');
  });
});
