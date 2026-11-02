import { validateTemplate } from 'dashboard/helper/whatsappTemplateValidator';
import { PRESET_KEYS, applyPreset } from './templatePresets';
import { emptyForm } from './templateEditor';

// feat/plantillas_whatsapp_mejoras F10.5 — empezar desde un ejemplo
const base = { ...emptyForm(), inbox_id: 3, language: 'es_MX' };

describe('applyPreset', () => {
  it('conserva la bandeja y el idioma elegidos', () => {
    expect(applyPreset(base, 'PAYMENT')).toMatchObject({
      inbox_id: 3,
      language: 'es_MX',
      name: 'recordatorio_pago',
    });
  });

  it('sin ejemplo (en blanco) vuelve al formulario vacío', () => {
    expect(applyPreset(base, null)).toMatchObject({
      inbox_id: 3,
      language: 'es_MX',
      name: '',
      body_text: '',
    });
  });

  it('cada uso arranca con objetos nuevos', () => {
    const uno = applyPreset(base, 'PROMO');
    uno.buttons[0].example[0] = 'OTRO';

    expect(applyPreset(base, 'PROMO').buttons[0].example[0]).toBe('PROMO10');
  });

  // Solo debe faltar lo que le toca poner al usuario: el archivo o la liga.
  it.each(PRESET_KEYS)('%s no trae errores propios', clave => {
    const errores = validateTemplate(applyPreset(base, clave));

    expect(
      errores.filter(e => !/falta el archivo|falta la liga/.test(e))
    ).toEqual([]);
  });
});
