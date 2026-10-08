import {
  sourceFromDirective,
  integrationFromDirective,
} from './sourceDirective';

describe('sourceFromDirective', () => {
  it('lee el tipo y el nombre de la fuente que nombra la ruta', () => {
    expect(sourceFromDirective('{{hoja:CATALOGO DE CARRERAS}}')).toEqual({
      source_type: 'google_sheet',
      name: 'CATALOGO DE CARRERAS',
    });
    expect(sourceFromDirective('{{doc: Manual }}')).toEqual({
      source_type: 'google_doc',
      name: 'Manual',
    });
    expect(sourceFromDirective('@buscar_foro(Foro Soporte)')).toEqual({
      source_type: 'discourse',
      name: 'Foro Soporte',
    });
    expect(sourceFromDirective('@soporte_contpaq(CONTPAQi)')).toEqual({
      source_type: 'contpaq_support',
      name: 'CONTPAQi',
    });
  });

  it('las predefinidas o los artículos no se crean como fuente', () => {
    expect(sourceFromDirective('@buscar_predefinidas(UNIVERSIDAD)')).toBeNull();
    expect(sourceFromDirective('@buscar_articulo')).toBeNull();
  });

  it('@discourse es la integración del canal, no una fuente', () => {
    expect(sourceFromDirective('@discourse')).toBeNull();
    expect(integrationFromDirective('@discourse')).toBe('discourse');
    expect(integrationFromDirective('{{hoja:X}}')).toBeNull();
  });
});
