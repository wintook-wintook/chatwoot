import { sortRows, nextOrder, NUMBER, DATE, TEXT } from './tableSort';

describe('tableSort', () => {
  const COLUMNS = {
    id: NUMBER,
    routes: NUMBER,
    title: TEXT,
    template_name: TEXT,
    updated_at: DATE,
  };

  const rows = [
    {
      id: 9,
      routes: 9,
      title: 'beta',
      template_name: null,
      updated_at: '2026-09-08T10:00:00Z',
    },
    {
      id: 10,
      routes: 10,
      title: 'Alfa',
      template_name: 'Soporte',
      updated_at: '2026-09-10T10:00:00Z',
    },
    {
      id: 3,
      routes: 0,
      title: 'gamma',
      template_name: 'Ventas',
      updated_at: '2026-09-08T10:00:00Z',
    },
  ];

  const ids = list => list.map(r => r.id);

  it('ordena los números como números y no como texto', () => {
    expect(ids(sortRows(rows, { key: 'id', order: 'asc' }, COLUMNS))).toEqual([
      3, 9, 10,
    ]);
    expect(
      sortRows(rows, { key: 'routes', order: 'desc' }, COLUMNS).map(
        r => r.routes
      )
    ).toEqual([10, 9, 0]);
  });

  it('ordena el texto sin que las mayúsculas manden', () => {
    expect(
      sortRows(rows, { key: 'title', order: 'asc' }, COLUMNS).map(r => r.title)
    ).toEqual(['Alfa', 'beta', 'gamma']);
  });

  it('ordena las fechas por su valor, no por su cadena', () => {
    expect(
      sortRows(rows, { key: 'updated_at', order: 'desc' }, COLUMNS)[0].id
    ).toBe(10);
  });

  // Dos filas con la misma fecha se intercambiaban entre repintados y la tabla
  // parpadeaba. El desempate por id la deja quieta.
  it('es estable ante empates', () => {
    const sort = { key: 'updated_at', order: 'desc' };
    const primero = ids(sortRows(rows, sort, COLUMNS));

    expect(primero).toEqual(ids(sortRows(rows, sort, COLUMNS)));
    expect(primero).toEqual([10, 3, 9]);
  });

  it('trata la celda vacía como el valor más bajo, en los dos sentidos', () => {
    const asc = sortRows(rows, { key: 'template_name', order: 'asc' }, COLUMNS);
    const desc = sortRows(
      rows,
      { key: 'template_name', order: 'desc' },
      COLUMNS
    );

    expect(asc.map(r => r.template_name)).toEqual([null, 'Soporte', 'Ventas']);
    expect(desc.map(r => r.template_name)).toEqual(['Ventas', 'Soporte', null]);
  });

  it('no muta el arreglo original', () => {
    const original = [...rows];
    sortRows(rows, { key: 'id', order: 'asc' }, COLUMNS);

    expect(rows).toEqual(original);
  });

  // Una columna sin declarar no se ordena. Es lo que impide que alguien agregue
  // un encabezado clicable y termine comparando números como texto.
  it('deja la lista intacta si la columna no está declarada', () => {
    expect(
      ids(sortRows(rows, { key: 'inventada', order: 'asc' }, COLUMNS))
    ).toEqual([9, 10, 3]);
    expect(ids(sortRows(rows, null, COLUMNS))).toEqual([9, 10, 3]);
  });

  describe('nextOrder', () => {
    it('arranca en desc al tocar una columna nueva', () => {
      expect(nextOrder({ key: 'id', order: 'asc' }, 'title')).toEqual({
        key: 'title',
        order: 'desc',
      });
    });

    it('alterna al volver a tocar la misma', () => {
      expect(nextOrder({ key: 'id', order: 'desc' }, 'id')).toEqual({
        key: 'id',
        order: 'asc',
      });
      expect(nextOrder({ key: 'id', order: 'asc' }, 'id')).toEqual({
        key: 'id',
        order: 'desc',
      });
    });
  });
});
