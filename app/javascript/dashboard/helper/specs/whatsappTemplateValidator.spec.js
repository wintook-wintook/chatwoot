import { validateTemplate } from '../whatsappTemplateValidator';

// feat/plantillas_whatsapp_mejoras — reglas nuevas, en sync con Whatsapp::TemplateValidator.
const base = {
  name: 'cobro_vencido',
  category: 'UTILITY',
  body_text: 'Hola {{1}}, tu saldo es {{2}}.',
  sample_values: { body: ['Juan', '$100'] },
};
const validar = cambios => validateTemplate({ ...base, ...cambios });

describe('validateTemplate', () => {
  it('acepta una plantilla válida', () => {
    expect(validar({})).toEqual([]);
  });

  it('autenticación se crea en WhatsApp Manager', () => {
    expect(validar({ category: 'AUTHENTICATION' })).toContainEqual(
      expect.stringMatching(/autenticación.*WhatsApp Manager/)
    );
  });

  it('el cuerpo no empieza ni termina con variable', () => {
    expect(validar({ body_text: '{{1}}, tu saldo es {{2}} pesos' })).toContain(
      'Body: no puede empezar con una variable'
    );
    expect(validar({ body_text: 'Hola {{1}}, tu saldo es {{2}}' })).toContain(
      'Body: no puede terminar con una variable (agrega un punto o texto después)'
    );
  });

  it('la liga con {{1}} pide su ejemplo', () => {
    const boton = { type: 'URL', text: 'Ver', url: 'https://x.mx/{{1}}' };
    expect(validar({ buttons: [boton] })).toContain(
      'Botón #1 (URL): falta el ejemplo de la liga completa'
    );
    expect(
      validar({ buttons: [{ ...boton, example: ['https://x.mx/123'] }] })
    ).toEqual([]);
  });

  it('el código de copiar pide su ejemplo, de hasta 15', () => {
    expect(
      validar({ buttons: [{ type: 'COPY_CODE', example: [] }] })
    ).toContain('Botón #1 (código): falta el código de ejemplo');
    expect(
      validar({ buttons: [{ type: 'COPY_CODE', example: ['A'.repeat(16)] }] })
    ).toContain('Botón #1 (código): el ejemplo admite hasta 15 caracteres');
    expect(
      validar({ buttons: [{ type: 'COPY_CODE', example: ['DESCUENTO2026'] }] })
    ).toEqual([]);
  });
});
