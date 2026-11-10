import {
  substituteVariables,
  validateTemplate,
  variableKeys,
} from '../whatsappTemplateValidator';

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
      'Mensaje: no puede empezar con una variable'
    );
    expect(validar({ body_text: 'Hola {{1}}, tu saldo es {{2}}' })).toContain(
      'Mensaje: no puede terminar con una variable (agrega un punto o texto después)'
    );
  });

  it('la liga con {{1}} pide su ejemplo', () => {
    const boton = { type: 'URL', text: 'Ver', url: 'https://x.mx/{{1}}' };
    expect(validar({ buttons: [boton] })).toContain(
      'Botón #1 (liga): falta el ejemplo de la liga completa'
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

// feat/plantillas_variables_chatwoot F9.1 — mismas reglas que Whatsapp::TemplateVariables
describe('variables con nombre', () => {
  it('acepta nombres, con un ejemplo por cada nombre distinto', () => {
    expect(
      validar({
        body_text: 'Hola {{nombre}}, tu edad es {{edad}} y {{nombre}} sigue.',
        sample_values: { body: ['Juan', '34'] },
      })
    ).toEqual([]);
  });

  it('no deja mezclar números con nombres, ni entre encabezado y cuerpo', () => {
    const mezcla =
      'Variables: no mezcles números con nombres (usa solo {{1}} o solo {{nombre}})';
    expect(
      validar({
        body_text: 'Hola {{1}} y {{edad}}.',
        sample_values: { body: ['a', 'b'] },
      })
    ).toContain(mezcla);
    expect(
      validar({
        header_type: 'text',
        header_content: 'Pedido {{pedido}}',
        body_text: 'Hola {{1}}.',
        sample_values: { body: ['a'], header: ['b'] },
      })
    ).toContain(mezcla);
  });

  it('rechaza nombres que Meta no acepta', () => {
    ['{{Edad}}', '{{contact.name}}', '{{mi dato}}', '{{1a}}'].forEach(
      variable => {
        expect(
          validar({
            body_text: `Hola ${variable}.`,
            sample_values: { body: ['a'] },
          })
        ).toContainEqual(expect.stringMatching(/no es válida/));
      }
    );
  });

  it('aplica las reglas de orilla y de pie a los nombres', () => {
    expect(
      validar({
        body_text: '{{nombre}}, hola.',
        sample_values: { body: ['a'] },
      })
    ).toContain('Mensaje: no puede empezar con una variable');
    expect(validar({ footer_text: 'Hola {{nombre}}' })).toContain(
      'Pie: no puede contener variables'
    );
  });

  it('ordena los números y deja los nombres como aparecen', () => {
    expect(variableKeys('{{2}} y {{1}} y {{2}}')).toEqual(['1', '2']);
    expect(variableKeys('{{b}} y {{a}} y {{b}}')).toEqual(['b', 'a']);
  });

  it('la vista previa llena nombres y números', () => {
    expect(substituteVariables('Hola {{a}}, {{b}} y {{a}}', ['x', 'y'])).toBe(
      'Hola x, y y x'
    );
    expect(substituteVariables('Hola {{2}} {{1}}', ['x', 'y'])).toBe(
      'Hola y x'
    );
    expect(substituteVariables('Hola {{a}}', [])).toBe('Hola {{a}}');
  });
});
