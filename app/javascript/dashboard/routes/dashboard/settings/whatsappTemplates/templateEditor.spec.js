import {
  emptyForm,
  formFromTemplate,
  templatePayload,
  sanitizeName,
  syncSamples,
  formCategories,
  languageOptions,
  needsButtonExample,
  buttonExample,
  isLocalDraft,
} from './templateEditor';

// feat/plantillas_whatsapp_mejoras F10 — el formulario del editor a página completa
const guardada = {
  id: 7,
  name: 'recordatorio_pago',
  language: 'es_MX',
  category: 'UTILITY',
  status: 'APPROVED',
  header_type: 'document',
  header_content: null,
  header_media_url: null,
  header_sample: { filename: 'Factura A1.pdf' },
  header_media_link: 'https://app.mx/rails/active_storage/x/Factura.pdf',
  body_text: 'Hola {{1}}, tu pago vence el {{2}}.',
  footer_text: null,
  buttons: [{ type: 'URL', text: 'Ver', url: 'https://x.mx/{{1}}' }],
  sample_values: { body: ['Juan', '5/11'] },
  editable: true,
  local_only: false,
};

describe('formFromTemplate', () => {
  it('trae la plantilla guardada sin mandar de nuevo su archivo', () => {
    const form = formFromTemplate(guardada);

    expect(form).toMatchObject({
      name: 'recordatorio_pago',
      header_type: 'document',
      header_content: '',
      footer_text: '',
      header_sample: null,
      header_sample_name: 'Factura A1.pdf',
      header_preview_url: 'https://app.mx/rails/active_storage/x/Factura.pdf',
      sample_values: { body: ['Juan', '5/11'], header: [] },
    });
    expect(form.buttons[0]).toMatchObject({
      type: 'URL',
      url: 'https://x.mx/{{1}}',
      example: [],
    });
  });

  it('sin encabezado queda en «Ninguno»', () => {
    expect(
      formFromTemplate({ ...guardada, header_type: null }).header_type
    ).toBe('');
  });
});

describe('templatePayload', () => {
  it('solo manda los campos del servidor', () => {
    const payload = templatePayload({
      ...emptyForm(),
      name: 'x',
      inbox_id: 3,
      header_sample_name: 'a.pdf',
      header_preview_url: 'https://…',
    });

    expect(payload).not.toHaveProperty('inbox_id');
    expect(payload).not.toHaveProperty('header_sample_name');
    expect(payload).not.toHaveProperty('header_preview_url');
    expect(payload).not.toHaveProperty('header_sample');
    expect(payload.name).toBe('x');
  });

  it('manda el archivo solo si se subió uno nuevo', () => {
    expect(
      templatePayload({ ...emptyForm(), header_sample: 'signed-1' })
        .header_sample
    ).toBe('signed-1');
  });
});

describe('ayudas del formulario', () => {
  it('el nombre sigue la regla de Meta', () => {
    expect(sanitizeName('Recordatorio de Pagó 2')).toBe(
      'recordatorio_de_pago_2'
    );
  });

  it('un ejemplo por variable, conservando los escritos', () => {
    expect(syncSamples(['Juan'], 'Hola {{1}}, vence {{2}}.')).toEqual([
      'Juan',
      '',
    ]);
    expect(syncSamples(['Juan', '5/11'], 'Hola {{1}}.')).toEqual(['Juan']);
  });

  it('autenticación solo aparece si la plantilla ya la tiene', () => {
    expect(formCategories('UTILITY')).toEqual(['UTILITY', 'MARKETING']);
    expect(formCategories('AUTHENTICATION')).toContain('AUTHENTICATION');
  });

  it('agrega el idioma de la plantilla si no está en la lista', () => {
    expect(languageOptions('fr')[0]).toBe('fr');
    expect(languageOptions('es')).not.toContain('fr');
  });

  it('el ejemplo lo piden copiar código y la liga con variable', () => {
    expect(needsButtonExample({ type: 'COPY_CODE' })).toBe(true);
    expect(needsButtonExample({ type: 'URL', url: 'https://x.mx/{{1}}' })).toBe(
      true
    );
    expect(needsButtonExample({ type: 'URL', url: 'https://x.mx' })).toBe(
      false
    );
    expect(buttonExample({ example: ['PROMO10'] })).toBe('PROMO10');
    expect(buttonExample({})).toBe('');
  });

  it('un borrador local es el que nunca llegó a Meta', () => {
    expect(isLocalDraft({ status: 'DRAFT', local_only: true })).toBe(true);
    expect(isLocalDraft({ status: 'DRAFT', local_only: false })).toBe(false);
    expect(isLocalDraft({ status: 'APPROVED', local_only: false })).toBe(false);
  });
});
