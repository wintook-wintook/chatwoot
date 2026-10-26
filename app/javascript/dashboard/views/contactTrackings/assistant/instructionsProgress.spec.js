import {
  instructionsProgress,
  instructionsFilename,
} from './instructionsProgress';

describe('instructionsProgress', () => {
  const md = [
    '# Instrucciones iniciales: Ana',
    '',
    '## Quién es',
    '- Se llama Ana.',
    '',
    '## Qué tiene que lograr',
    '<!-- una nota -->',
    '',
    '## Lo que la gente viene a pedir',
    '### Agendar cita',
    '',
    '## Nunca',
    '- Nunca diagnosticar.',
  ].join('\n');

  it('cuenta como llenas solo las secciones con texto propio', () => {
    expect(instructionsProgress(md)).toEqual({
      sections: [
        { title: 'Quién es', filled: true },
        { title: 'Qué tiene que lograr', filled: false },
        { title: 'Lo que la gente viene a pedir', filled: false },
        { title: 'Nunca', filled: true },
      ],
      filled: 2,
      total: 4,
    });
  });

  it('sin instrucciones, no hay secciones', () => {
    expect(instructionsProgress('')).toEqual({
      sections: [],
      filled: 0,
      total: 0,
    });
  });

  it('arma el nombre del archivo con el nombre del agente', () => {
    expect(instructionsFilename(md)).toBe('instrucciones_ana.md');
    expect(
      instructionsFilename('# Instrucciones iniciales: Psicóloga Pérez')
    ).toBe('instrucciones_psicologa_perez.md');
    expect(instructionsFilename('## Quién es')).toBe(
      'instrucciones_iniciales.md'
    );
  });
});
