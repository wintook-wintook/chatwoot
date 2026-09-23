import { groupGaps, listSizes, listItemText, isBusy } from './briefDigest';

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
});
