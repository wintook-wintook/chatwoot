import {
  constantsBody,
  constantsOf,
  fieldsOf,
  filledCount,
  variablesBody,
  variablesOf,
} from './draftingFields';

describe('draftingFields', () => {
  it('manda solo las cuatro llaves, en texto', () => {
    expect(
      fieldsOf({ name: 'Leo', objective: ' Demos ', boceto: '@ruta(x)' })
    ).toEqual({
      objective: 'Demos',
      ai_context: '',
      variables: '',
      datos_fijos: '',
    });
    expect(fieldsOf(null).objective).toBe('');
  });

  it('cuenta las pestañas llenas', () => {
    expect(filledCount(null)).toBe(0);
    expect(filledCount({ ai_context: 'x', datos_fijos: 'EMPRESA = K' })).toBe(
      2
    );
  });

  // El texto que escribe Ruby (DraftingFields) se lee y se vuelve a escribir igual.
  it('ida y vuelta con los modales sin cambiar el texto', () => {
    const variables =
      'SISTEMA = CONTPAQi | Aspel | valor\nInicial: SISTEMA=Aspel';
    const leidas = variablesOf(variables);
    expect(leidas.variables[0]).toMatchObject({
      name: 'SISTEMA',
      options: ['CONTPAQi', 'Aspel'],
      free: true,
      initial: 'Aspel',
    });
    expect(variablesBody(leidas)).toBe(variables);

    const datos =
      'EMPRESA = Kontrolya\nQ1 (pregunta) = ¿Qué usas? → guarda en SISTEMA';
    const constantes = constantsOf(datos);
    expect(constantes.constants[1]).toMatchObject({
      name: 'Q1',
      type: 'pregunta',
      savesTo: 'SISTEMA',
    });
    expect(constantsBody(constantes)).toBe(datos);
  });
});
