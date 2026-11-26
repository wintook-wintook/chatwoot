import { parseMetaError, translateMetaError } from '../metaErrorTranslator';

// diag/waba F4 (D7) — el error de Meta del mensaje fallido en palabras del usuario.
const t = (key, vars) =>
  vars ? `${key}:${Object.values(vars).join('|')}` : key;

describe('metaErrorTranslator', () => {
  it('entiende «código: título» y el JSON del envío', () => {
    expect(parseMetaError('131047: Re-engagement message')).toEqual({
      code: 131047,
      title: 'Re-engagement message',
    });
    const raw = JSON.stringify({
      error: {
        message: 'x',
        code: 132001,
        error_data: { details: 'template promo does not exist' },
      },
    });
    expect(parseMetaError(raw)).toEqual({
      code: 132001,
      title: 'template promo does not exist',
    });
  });

  it('código conocido → texto claro y el código de Meta para soporte', () => {
    expect(translateMetaError('131047: Re-engagement message', t)).toBe(
      'WHATSAPP_HEALTH.ERRORS.WINDOW_24H:Re-engagement message WHATSAPP_HEALTH.ERRORS.META_CODE:131047'
    );
    const token = JSON.stringify({ error: { code: 190, message: 'expired' } });
    expect(translateMetaError(token, t)).toContain('ERRORS.TOKEN');
  });

  it('lo que no reconoce lo deja igual (correo, otros canales)', () => {
    expect(translateMetaError('SMTP 550 mailbox unavailable', t)).toBe(
      'SMTP 550 mailbox unavailable'
    );
    expect(translateMetaError('999999: raro', t)).toBe('999999: raro');
    expect(translateMetaError('', t)).toBe('');
  });
});
