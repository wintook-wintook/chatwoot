import {
  describeTemplate,
  buildProcessedParams,
  validateValues,
  renderPreview,
  variablesIn,
} from './templateForm';

// feat/plantillas_whatsapp_mejoras F2 — docs/plantillas_whatsapp_mejoras_plan.md §4
const soloCuerpo = {
  name: 'saludo',
  components: [{ type: 'BODY', text: 'Hola {{1}}, tu pedido {{2}}' }],
};
const conFactura = {
  name: 'factura',
  components: [
    { type: 'HEADER', format: 'DOCUMENT' },
    { type: 'BODY', text: 'Tu factura {{1}}' },
    { type: 'FOOTER', text: 'Gracias' },
  ],
};
const conTodo = {
  name: 'pedido',
  components: [
    { type: 'HEADER', format: 'TEXT', text: 'Pedido {{1}}' },
    { type: 'BODY', text: 'Gracias {{1}}' },
    {
      type: 'BUTTONS',
      buttons: [
        { type: 'QUICK_REPLY', text: 'Sí' },
        { type: 'URL', text: 'Ver pedido', url: 'https://x.mx/p/{{1}}' },
        { type: 'COPY_CODE', text: 'Copiar' },
      ],
    },
  ],
};

describe('describeTemplate', () => {
  it('una plantilla de solo cuerpo no pide nada más', () => {
    const info = describeTemplate(soloCuerpo);

    expect(info).toMatchObject({
      bodyVars: ['1', '2'],
      media: null,
      headerVars: [],
      needsComponents: false,
    });
  });

  it('reconoce el documento del encabezado y el pie', () => {
    expect(describeTemplate(conFactura)).toMatchObject({
      media: 'document',
      footerText: 'Gracias',
      needsComponents: true,
    });
  });

  it('variables del encabezado y botones que llevan dato', () => {
    const info = describeTemplate(conTodo);

    expect(info.headerVars).toEqual(['1']);
    expect(info.buttons.map(b => [b.index, b.type, b.needsParam])).toEqual([
      [0, 'QUICK_REPLY', false],
      [1, 'URL', true],
      [2, 'COPY_CODE', true],
    ]);
  });

  // F4: los programados solo llenan el cuerpo y ocultan las que piden más.
  it('botones de respuesta rápida o teléfono no piden dato: basta el cuerpo', () => {
    const conBotonesFijos = {
      components: [
        { type: 'HEADER', format: 'TEXT', text: 'Aviso' },
        { type: 'BODY', text: 'Hola {{1}}' },
        {
          type: 'BUTTONS',
          buttons: [
            { type: 'QUICK_REPLY', text: 'Sí' },
            { type: 'PHONE_NUMBER', text: 'Llamar' },
            { type: 'URL', text: 'Sitio', url: 'https://x.mx' },
          ],
        },
      ],
    };

    expect(describeTemplate(conBotonesFijos).needsComponents).toBe(false);
  });

  it('variables con nombre', () => {
    expect(variablesIn('Hola {{nombre}} y {{ apellido }}')).toEqual([
      'nombre',
      'apellido',
    ]);
  });
});

describe('buildProcessedParams', () => {
  it('solo cuerpo: el formato de siempre, aun en WhatsApp Cloud', () => {
    expect(
      buildProcessedParams(
        soloCuerpo,
        { body: { 1: 'Ana', 2: 'A1' } },
        { components: true }
      )
    ).toEqual({ 1: 'Ana', 2: 'A1' });
  });

  it('fuera de WhatsApp Cloud siempre el formato de siempre', () => {
    expect(
      buildProcessedParams(conTodo, { body: { 1: 'Ana' }, header: { 1: 'A1' } })
    ).toEqual({ 1: 'Ana' });
  });

  it('documento con nombre', () => {
    expect(
      buildProcessedParams(
        conFactura,
        {
          body: { 1: 'A1' },
          mediaUrl: ' https://cdn.mx/f.pdf ',
          mediaName: 'Factura A1.pdf',
        },
        { components: true }
      )
    ).toEqual({
      body: { 1: 'A1' },
      header: {
        media_url: 'https://cdn.mx/f.pdf',
        media_type: 'document',
        media_name: 'Factura A1.pdf',
      },
    });
  });

  it('encabezado de texto y botones en su lugar (el índice es el que lee Meta)', () => {
    expect(
      buildProcessedParams(
        conTodo,
        {
          body: { 1: 'Ana' },
          header: { 1: 'A1' },
          buttons: { 1: 'A1', 2: ' PROMO10 ' },
        },
        { components: true }
      )
    ).toEqual({
      body: { 1: 'Ana' },
      header: { 1: 'A1' },
      buttons: [
        null,
        { type: 'url', parameter: 'A1' },
        { type: 'copy_code', parameter: 'PROMO10' },
      ],
    });
  });
});

describe('validateValues', () => {
  const opciones = { components: true };

  it('pide todas las variables del cuerpo', () => {
    expect(validateValues(soloCuerpo, { body: { 1: 'Ana', 2: ' ' } })).toEqual([
      'BODY',
    ]);
  });

  it('pide una liga pública válida para el archivo', () => {
    const base = { body: { 1: 'A1' } };

    expect(validateValues(conFactura, base, opciones)).toEqual(['MEDIA_URL']);
    expect(
      validateValues(
        conFactura,
        { ...base, mediaUrl: 'cdn.mx/f.pdf' },
        opciones
      )
    ).toEqual(['MEDIA_URL']);
    expect(
      validateValues(
        conFactura,
        { ...base, mediaUrl: 'https://cdn.mx/f.pdf' },
        opciones
      )
    ).toEqual([]);
  });

  it('el código de copiar no pasa de 15', () => {
    expect(
      validateValues(
        conTodo,
        {
          body: { 1: 'Ana' },
          header: { 1: 'A1' },
          buttons: { 1: 'A1', 2: 'CODIGO_DEMASIADO_LARGO' },
        },
        opciones
      )
    ).toEqual(['COPY_CODE_LENGTH']);
  });

  it('sin WhatsApp Cloud solo revisa el cuerpo', () => {
    expect(validateValues(conTodo, { body: { 1: 'Ana' } })).toEqual([]);
  });
});

describe('renderPreview', () => {
  it('arma encabezado, cuerpo, pie y botones como los verá el cliente', () => {
    expect(
      renderPreview(conTodo, { header: { 1: 'A1' }, body: { 1: 'Ana' } })
    ).toEqual({
      header: 'Pedido A1',
      media: null,
      mediaName: '',
      body: 'Gracias Ana',
      footer: '',
      buttons: ['Sí', 'Ver pedido', 'Copiar'],
    });
  });

  it('las variables vacías se quedan visibles para notar que faltan', () => {
    expect(renderPreview(soloCuerpo, { body: { 1: 'Ana' } }).body).toBe(
      'Hola Ana, tu pedido {{2}}'
    );
  });
});

// El archivo guardado de la plantilla: el servidor saca la liga para Meta al mandar.
describe('con el archivo de la plantilla', () => {
  const templateFile = {
    media_name: 'Factura A1.pdf',
    preview_url:
      'https://app.mx/rails/active_storage/blobs/redirect/x/Factura%20A1.pdf',
  };
  const valores = { body: { 1: 'A1' }, templateFile };

  it('manda source: template sin liga', () => {
    expect(
      buildProcessedParams(conFactura, valores, { components: true })
    ).toEqual({
      body: { 1: 'A1' },
      header: { source: 'template', media_type: 'document' },
    });
  });

  it('no pide la liga del archivo', () => {
    expect(validateValues(conFactura, valores, { components: true })).toEqual(
      []
    );
  });

  it('la vista previa muestra el nombre del archivo de la plantilla', () => {
    expect(
      renderPreview(conFactura, { ...valores, mediaName: 'otro.pdf' }).mediaName
    ).toBe('Factura A1.pdf');
  });

  it('si el agente cambia a otra liga, se manda esa', () => {
    const otra = {
      body: { 1: 'A1' },
      templateFile: null,
      mediaUrl: 'https://cdn.mx/otra.pdf',
    };
    expect(
      buildProcessedParams(conFactura, otra, { components: true }).header
    ).toEqual({ media_url: 'https://cdn.mx/otra.pdf', media_type: 'document' });
  });
});

// Otro archivo, subido de la máquina del agente para este envío.
describe('con un archivo subido', () => {
  const subido = {
    signed_id: 'abc',
    filename: 'Cotizacion 77.pdf',
    preview_url:
      'https://app.mx/rails/active_storage/blobs/redirect/abc/Cotizacion%2077.pdf',
  };

  it('manda source: upload con su signed_id y el nombre', () => {
    const valores = {
      body: { 1: 'A1' },
      mediaSource: 'upload',
      uploadedFile: subido,
      mediaName: 'Cotizacion 77.pdf',
    };
    expect(
      buildProcessedParams(conFactura, valores, { components: true }).header
    ).toEqual({
      source: 'upload',
      signed_id: 'abc',
      media_type: 'document',
      media_name: 'Cotizacion 77.pdf',
    });
  });

  it('pide elegir el archivo antes de mandar', () => {
    expect(
      validateValues(
        conFactura,
        { body: { 1: 'A1' }, mediaSource: 'upload', uploadedFile: null },
        { components: true }
      )
    ).toEqual(['MEDIA_FILE']);
  });
});
