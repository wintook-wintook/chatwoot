import {
  attributeVariables,
  recognizeVariable,
} from './templateVariableSources';

// feat/plantillas_variables_chatwoot F9.1
const atributos = [
  { attribute_key: 'edad', attribute_display_name: 'Edad' },
  { attribute_key: 'edad', attribute_display_name: 'Edad (conv.)' },
  { attribute_key: 'Fecha-Cita', attribute_display_name: 'Fecha' },
  { attribute_key: 'nombre', attribute_display_name: 'Nombre propio' },
];

describe('recognizeVariable', () => {
  it('reconoce campos reservados y atributos; lo demás lo escribe el agente', () => {
    expect(recognizeVariable('primer_nombre')).toEqual({
      kind: 'field',
      key: 'primer_nombre',
    });
    expect(recognizeVariable('edad', atributos)).toEqual({
      kind: 'attribute',
      label: 'Edad',
    });
    expect(recognizeVariable('plan', atributos)).toEqual({ kind: 'manual' });
  });

  it('el campo reservado gana sobre un atributo con esa clave', () => {
    expect(recognizeVariable('nombre', atributos).kind).toBe('field');
  });

  it('las numeradas no se reconocen por nombre', () => {
    expect(recognizeVariable('1')).toBeNull();
  });
});

describe('attributeVariables', () => {
  it('quita repetidos, claves no válidas y las que chocan con un campo', () => {
    expect(attributeVariables(atributos).map(a => a.attribute_key)).toEqual([
      'edad',
    ]);
  });
});
