import {
  templateKinds,
  sendability,
  metaManagerUrl,
  statusSteps,
  rejectionKey,
  sortTemplates,
  templateInUse,
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

describe('sendability en seguimientos', () => {
  const base = { status: 'APPROVED', header_type: 'text', buttons: [] };

  it('no sirven las que piden un dato que seguimientos no llena', () => {
    const copiar = { ...base, buttons: [{ type: 'COPY_CODE' }] };
    const liga = {
      ...base,
      buttons: [{ type: 'URL', url: 'https://x.mx/{{1}}' }],
    };
    const encabezado = { ...base, header_content: 'Pedido {{1}}' };
    const conArchivo = {
      ...copiar,
      header_type: 'document',
      header_media_url: 'x',
    };

    [copiar, liga, encabezado, conArchivo].forEach(plantilla => {
      expect(sendability(plantilla, cloud)).toEqual({
        conversation: true,
        trackings: 'needs_data',
      });
    });
  });

  it('el encabezado con nombres sí lo llenan (F9.3); con un botón con dato, no', () => {
    const nombres = { ...base, header_content: 'Para {{primer_nombre}}' };

    expect(sendability(nombres, cloud).trackings).toBe('ok');
    expect(
      sendability({ ...nombres, buttons: [{ type: 'COPY_CODE' }] }, cloud)
        .trackings
    ).toBe('needs_data');
    expect(sendability(nombres, { provider: 'default' }).trackings).toBe('no');
  });

  it('la liga fija y las respuestas rápidas sí sirven', () => {
    const fijos = [
      { type: 'URL', url: 'https://x.mx' },
      { type: 'QUICK_REPLY' },
    ];

    expect(sendability({ ...base, buttons: fijos }, cloud).trackings).toBe(
      'ok'
    );
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

describe('sortTemplates', () => {
  const lista = [
    {
      name: 'b',
      status: 'APPROVED',
      updated_at: '2026-10-01T10:00:00Z',
      channel_whatsapp_id: 1,
    },
    {
      name: 'a',
      status: 'PENDING',
      updated_at: '2026-10-30T10:00:00Z',
      channel_whatsapp_id: 2,
    },
    { name: 'c', status: 'APPROVED', updated_at: null, channel_whatsapp_id: 1 },
  ];
  const nombres = (key, dir, canal) =>
    sortTemplates(lista, { key, dir }, canal).map(t => t.name);

  it('por omisión, la última actualización primero', () => {
    expect(nombres('updated_at', 'desc')).toEqual(['a', 'b', 'c']);
  });

  it('por texto, en los dos sentidos', () => {
    expect(nombres('name', 'asc')).toEqual(['a', 'b', 'c']);
    expect(nombres('name', 'desc')).toEqual(['c', 'b', 'a']);
    expect(nombres('status', 'asc')).toEqual(['b', 'c', 'a']);
  });

  it('por bandeja usa su nombre', () => {
    const canal = t => (t.channel_whatsapp_id === 1 ? 'Zeta' : 'Alfa');
    expect(nombres('channel', 'asc', canal)).toEqual(['a', 'b', 'c']);
  });
});

describe('templateInUse', () => {
  const vacio = {
    agents: [],
    trackings_count: 0,
    campaigns: [],
    scheduled_count: 0,
    portals: [],
  };

  it('avisa si algo depende de la plantilla', () => {
    expect(templateInUse(vacio)).toBe(false);
    expect(templateInUse(null)).toBe(false);
    expect(templateInUse({ ...vacio, trackings_count: 2 })).toBe(true);
    expect(templateInUse({ ...vacio, portals: [{ id: 1 }] })).toBe(true);
    expect(templateInUse({ ...vacio, scheduled_count: 1 })).toBe(true);
  });
});
