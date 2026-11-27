import { insertConstant, percentTriggerAt } from './constantPicker';

describe('constantPicker', () => {
  it('abre con «%» al empezar una palabra', () => {
    expect(percentTriggerAt('Presenta a %', 12)).toBe(true);
    expect(percentTriggerAt('%', 1)).toBe(true);
  });

  it('no abre con un porcentaje ni a media palabra', () => {
    expect(percentTriggerAt('ofrece 30%', 10)).toBe(false);
    expect(percentTriggerAt('abc%', 4)).toBe(false);
    expect(percentTriggerAt('%%', 2)).toBe(false);
    expect(percentTriggerAt('hola', 4)).toBe(false);
  });

  it('cambia el «%» por la cita y deja el cursor después', () => {
    expect(insertConstant('Presenta a % hoy', 12, 'EMPRESA')).toEqual({
      text: 'Presenta a %EMPRESA% hoy',
      caret: 20,
    });
  });
});
