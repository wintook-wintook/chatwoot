import { templateKinds, sendability, metaManagerUrl } from './templateScreen';

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
