import {
  groupGaps,
  listSizes,
  listItemText,
  isBusy,
  briefQuestions,
  briefAnswers,
} from './briefDigest';

describe('briefDigest', () => {
  it('agrupa las faltas por tipo, en el orden de los pasos', () => {
    const gaps = [
      { paso: 4, que: 'etiqueta', tema: 'reclamo' },
      { paso: 2, que: 'frases_cliente', tema: 'reclamo' },
      { paso: 2, que: 'frases_cliente', tema: 'urgencia' },
      { paso: 1, que: 'modo' },
      { paso: 3, que: 'herramienta_no_disponible', tipo: 'hoja' },
    ];

    expect(groupGaps(gaps)).toEqual([
      { que: 'modo', items: [] },
      { que: 'frases_cliente', items: ['reclamo', 'urgencia'] },
      { que: 'herramienta_no_disponible', items: ['hoja'] },
      { que: 'etiquetas', items: ['reclamo'] },
    ]);
  });

  it('pone primero las contradicciones, con lo que dice cada parte', () => {
    const gaps = [
      { paso: 4, que: 'etiquetas' },
      {
        paso: 0,
        que: 'contradiccion',
        sobre: 'precio',
        a: 'preguntar',
        b: 'no preguntar',
      },
    ];

    expect(groupGaps(gaps)).toEqual([
      { que: 'contradiccion', items: ['precio: «preguntar» o «no preguntar»'] },
      { que: 'etiquetas', items: [] },
    ]);
  });

  it('cuenta solo las listas que tienen algo', () => {
    expect(listSizes({ reglas: [{}, {}], tono: [] })).toEqual([
      { campo: 'reglas', count: 2 },
    ]);
  });

  it('escribe en una línea los puntos que son objetos', () => {
    expect(
      listItemText('contradicciones', {
        sobre: 'precio',
        a: 'nunca',
        b: 'rango',
      })
    ).toBe('precio: «nunca» / «rango»');
    expect(
      listItemText('conocimiento', { tema: 'Branding', resumen: 'marca' })
    ).toBe('Branding: marca');
  });

  it('sabe cuándo todavía se está leyendo', () => {
    expect(isBusy('reading')).toBe(true);
    expect(isBusy('ready')).toBe(false);
  });

  it('arma una pregunta por contradicción, por tema sin frases y por tema sin etiqueta', () => {
    const ficha = {
      contradicciones: [{ sobre: 'precio', a: 'x', b: 'y' }],
      temas: [
        { nombre: 'Precios', etiqueta: 'precios' },
        { nombre: 'Horarios' },
      ],
    };
    const gaps = [{ que: 'frases_cliente', tema: 'Horarios' }];

    expect(briefQuestions(ficha, gaps).map(p => `${p.kind}:${p.key}`)).toEqual([
      'contradiccion:0',
      'frases:Horarios',
      'etiquetas:Horarios',
    ]);
  });

  it('manda solo lo contestado, agrupado como lo espera el backend', () => {
    expect(
      briefAnswers({
        'contradiccion:0': 'b',
        'frases:Horarios': '¿a qué hora?\n',
        'etiquetas:Horarios': '  ',
        modo: 'deriva',
      })
    ).toEqual({
      contradicciones: { 0: 'b' },
      frases: { Horarios: '¿a qué hora?' },
      modo: 'deriva',
    });
  });
});
