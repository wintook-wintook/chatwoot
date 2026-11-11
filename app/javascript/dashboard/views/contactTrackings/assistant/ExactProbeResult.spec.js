import { shallowMount } from '@vue/test-utils';
import ExactProbeResult from './ExactProbeResult.vue';

const montar = result =>
  shallowMount(ExactProbeResult, {
    propsData: { result },
    mocks: { $t: (c, a) => (a ? `${c} ${JSON.stringify(a)}` : c) },
  });

describe('ExactProbeResult', () => {
  it('hoja_buscar: qué buscó, qué regresaría y las filas', () => {
    const texto = montar({
      kind: 'sheet_lookup',
      status: 'ok',
      sheet: 'Precios',
      criteria: ['Producto = Pantalón'],
      returns: ['Precio'],
      found: ['480'],
      rows: ['Producto: Pantalón · Precio: 480'],
      more: 2,
    }).text();

    expect(texto).toContain('PROBE.SHEET_LOOKUP_OK');
    expect(texto).toContain('"criteria":"Producto = Pantalón"');
    expect(texto).toContain('480');
    expect(texto).toContain('Producto: Pantalón · Precio: 480');
    expect(texto).toContain('PROBE.MORE_ROWS {"count":2}');
  });

  it('hoja_buscar sin el dato dice qué preguntaría', () => {
    expect(
      montar({
        kind: 'sheet_lookup',
        status: 'needs_value',
        asked: 'Producto',
      }).text()
    ).toContain('PROBE.SHEET_LOOKUP_NEEDS_VALUE');
  });

  it('ERP: con qué valores corrió y la tabla', () => {
    const wrapper = montar({
      kind: 'erp',
      status: 'ok',
      params: { texto: 'hp', linea: 'COMPUTO' },
      columns: ['NOMBRE', 'PRECIO'],
      rows: [{ NOMBRE: 'HP 240', PRECIO: 13499 }],
      partial: true,
    });
    const texto = wrapper.text();

    expect(texto).toContain('texto = hp');
    expect(texto).toContain('linea = COMPUTO');
    expect(wrapper.findAll('td').wrappers.map(td => td.text())).toEqual([
      'HP 240',
      '13499',
    ]);
    expect(texto).toContain('PROBE.ERP_PARTIAL');
  });

  it('hoja en modo datos y ERP sin «?» muestran el texto que daría', () => {
    expect(
      montar({
        kind: 'sheet_data',
        status: 'ok',
        answer: 'El total es 733',
      }).text()
    ).toContain('El total es 733');
    expect(
      montar({ kind: 'erp', status: 'ok', rendered: '• HP 240' }).text()
    ).toContain('• HP 240');
  });
});
