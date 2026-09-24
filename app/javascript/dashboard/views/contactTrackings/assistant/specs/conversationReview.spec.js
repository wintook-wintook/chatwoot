import {
  mentionsConversation,
  reviewMessage,
  hasTrainingFixes,
} from '../conversationReview';

// Devuelve la llave y sus argumentos: se prueba qué se arma, no las traducciones.
const t = (key, args) =>
  `${key.replace('TRACKING_ASSISTANT_VIEW.REVIEW_', '')}${
    args ? JSON.stringify(args) : ''
  }`;

const resultado = {
  conversation: {
    display_id: 173,
    reviewed: 17,
    messages: 17,
    truncated: false,
  },
  agent: { template_id: 8884, name: 'Consultorio', stale_copy: true },
  facts: [{ code: 'calendar_ok' }, { code: 'stale_copy', name: 'Consultorio' }],
  summary: 'Prometió algo que no hizo.',
  ok: [2, 17],
  findings: [
    {
      n: 4,
      verdict: 'mal',
      cause: 'configuracion',
      already_fixed: true,
      said: 'Te ayudo #humano',
      what: 'No ofreció horarios.',
      fix: 'Asignar calendario.',
      signals: [
        {
          code: 'wrong_tag',
          tags: ['#humano'],
          route: 'agendar_cita',
          expected: '#agendar',
          already_fixed: true,
        },
      ],
    },
    {
      n: 15,
      verdict: 'mal',
      cause: 'motor',
      said: 'Ya tenés',
      signals: [{ code: 'voseo', words: ['tenés'], cause: 'motor' }],
    },
  ],
  training_changes: ['Prohibir prometer.'],
};

describe('mentionsConversation', () => {
  it('reconoce el link y «conversación 173»', () => {
    expect(
      mentionsConversation('revisa /app/accounts/2/conversations/173')
    ).toBe(true);
    expect(mentionsConversation('mira la conversación #173')).toBe(true);
    expect(mentionsConversation('un agente para un gimnasio')).toBe(false);
  });
});

describe('reviewMessage', () => {
  const texto = reviewMessage(resultado, t);

  it('dice qué respuesta está mal, con su causa y lo que dijo', () => {
    expect(texto).toContain('FINDING_MAL{"n":4');
    expect(texto).toContain('ALREADY_FIXED');
    expect(texto).toContain('«Te ayudo #humano»');
    expect(texto).toContain('SIGNAL_TAG_FIXED');
    expect(texto).toContain('SIGNAL_VOSEO_MOTOR');
  });

  it('avisa la copia vieja, pero no el calendario que ya está bien', () => {
    expect(texto).toContain('FACT_STALE_COPY');
    expect(texto).not.toContain('CALENDAR_OK');
  });

  it('lista lo que estuvo bien y los cambios propuestos', () => {
    expect(texto).toContain('OK{"list":"#2, #17"}');
    expect(texto).toContain('- Prohibir prometer.');
  });

  it('sin hallazgos lo dice', () => {
    expect(reviewMessage({ ...resultado, findings: [] }, t)).toContain(
      'ALL_OK'
    );
  });
});

describe('hasTrainingFixes', () => {
  it('hay que corregir si propone cambios o una falla del Entrenamiento sigue abierta', () => {
    expect(hasTrainingFixes(resultado)).toBe(true);
    expect(hasTrainingFixes({ findings: [], training_changes: [] })).toBe(
      false
    );
    expect(
      hasTrainingFixes({
        training_changes: [],
        findings: [{ cause: 'entrenamiento', already_fixed: false }],
      })
    ).toBe(true);
  });
});
