import {
  templateKinds,
  sendability,
  metaManagerUrl,
  statusSteps,
  rejectionKey,
} from './templateScreen';

// feat/plantillas_whatsapp_mejoras F6 — la pantalla de plantillas
const cloud = {
  provider: 'whatsapp_cloud',
  provider_config: { business_account_id: '123' },
};
const dialog360 = { provider: 'default', provider_config: {} };

describe('templateKinds', () => {
  it('distingue texto, archivo, botones y copiar código', () => {
    expect(templateKinds({ header_type: 'text', buttons: [] })).toEqual([
      'text',
    ]);
    expect(
      templateKinds({
        header_type: 'document',
        buttons: [{ type: 'URL' }, { type: 'COPY_CODE' }],
      })
    ).toEqual(['document', 'buttons', 'copy_code']);
    expect(templateKinds({ header_type: null })).toEqual(['text']);
  });
});

describe('sendability', () => {
  const aprobada = cambios => ({
    status: 'APPROVED',
    header_type: 'document',
    ...cambios,
  });

  it('si no está aprobada, todavía no se puede mandar por nada', () => {
    expect(sendability({ status: 'PENDING' }, cloud)).toEqual({
      conversation: null,
      trackings: null,
    });
  });

  it('una de solo texto se puede mandar en todos lados', () => {
    expect(sendability(aprobada({ header_type: 'text' }), dialog360)).toEqual({
      conversation: true,
      trackings: 'ok',
    });
  });

  it('una de archivo en WhatsApp Cloud: seguimientos necesitan el archivo guardado', () => {
    expect(sendability(aprobada(), cloud)).toEqual({
      conversation: true,
      trackings: 'missing_file',
    });
    expect(
      sendability(aprobada({ header_sample: { filename: 'f.pdf' } }), cloud)
        .trackings
    ).toBe('ok');
    expect(
      sendability(aprobada({ header_media_url: 'https://x/f.pdf' }), cloud)
        .trackings
    ).toBe('ok');
  });

  it('una de archivo fuera de WhatsApp Cloud no se puede mandar', () => {
    expect(sendability(aprobada(), dialog360)).toEqual({
      conversation: false,
      trackings: 'no',
    });
  });
});

describe('metaManagerUrl', () => {
  it('abre las plantillas de la cuenta de negocio, si se conoce', () => {
    expect(metaManagerUrl(cloud)).toBe(
      'https://business.facebook.com/wa/manage/message-templates/?waba_id=123'
    );
    expect(metaManagerUrl(dialog360)).toBeNull();
    expect(metaManagerUrl(null)).toBeNull();
  });
});

// F10.4 — la ficha
describe('sendability fuera de WhatsApp Cloud', () => {
  it('las que piden un dato en un botón o en el encabezado no se mandan', () => {
    const base = { status: 'APPROVED', header_type: 'text', buttons: [] };
    expect(sendability(base, dialog360).conversation).toBe(true);
    expect(
      sendability({ ...base, buttons: [{ type: 'COPY_CODE' }] }, dialog360)
        .conversation
    ).toBe(false);
    expect(
      sendability({ ...base, header_content: 'Pedido {{1}}' }, dialog360)
        .conversation
    ).toBe(false);
    expect(
      sendability({ ...base, buttons: [{ type: 'COPY_CODE' }] }, cloud)
        .conversation
    ).toBe(true);
  });
});

describe('statusSteps', () => {
  const estados = status => statusSteps(status).map(p => `${p.key}:${p.state}`);

  it('borrador, en revisión y aprobada', () => {
    expect(estados('DRAFT')).toEqual([
      'DRAFT:current',
      'PENDING:pending',
      'RESULT:pending',
    ]);
    expect(estados('PENDING')).toEqual([
      'SUBMITTED:done',
      'PENDING:current',
      'RESULT:pending',
    ]);
    expect(estados('APPROVED')[2]).toBe('APPROVED:done');
  });

  it('rechazada, pausada y deshabilitada', () => {
    expect(estados('REJECTED')[2]).toBe('REJECTED:failed');
    expect(estados('PAUSED')[2]).toBe('PAUSED:warning');
    expect(estados('DISABLED')[2]).toBe('DISABLED:failed');
  });
});

describe('rejectionKey', () => {
  it('explica los motivos conocidos de Meta; el resto se muestra tal cual', () => {
    expect(rejectionKey('incorrect_category')).toBe('INCORRECT_CATEGORY');
    expect(rejectionKey('ALGO_NUEVO')).toBeNull();
    expect(rejectionKey(null)).toBeNull();
  });
});
