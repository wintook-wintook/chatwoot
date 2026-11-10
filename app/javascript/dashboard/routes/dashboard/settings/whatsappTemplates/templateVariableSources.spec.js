import {
  attributeVariables,
  recognizeVariable,
  variableHint,
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

// F9.3 — el aviso bajo cada variable
describe('variableHint', () => {
  const context = {
    contact: { name: 'Juan', custom_attributes: { edad: 34 } },
  };

  it('dice de dónde salió el dato', () => {
    expect(variableHint('nombre', 'Juan', context)).toEqual({
      kind: 'field',
      key: 'nombre',
      missing: false,
    });
    expect(variableHint('edad', '34', context, atributos)).toEqual({
      kind: 'attribute',
      label: 'Edad',
      missing: false,
    });
  });

  it('avisa si el contacto no tiene un dato que el sistema conoce', () => {
    expect(variableHint('correo', '', context)).toMatchObject({
      key: 'correo',
      missing: true,
    });
    expect(variableHint('edad', '  ', context, atributos)).toMatchObject({
      label: 'Edad',
      missing: true,
    });
  });

  it('sin aviso: lo cambió a mano, lo escribe el agente, o es numerada', () => {
    expect(variableHint('nombre', 'Don Juan', context)).toBeNull();
    expect(variableHint('plan', '', context, atributos)).toBeNull();
    expect(variableHint('1', '', context)).toBeNull();
  });

  it('sin contacto no hay de dónde llenar: sin aviso', () => {
    expect(variableHint('nombre', '', {})).toBeNull();
  });
});
