import { logEntries, changeLogMarkdown } from './changeLog';

const versiones = [
  { n: 1, at: '2026-09-25T10:00:00Z', source: 'loaded' },
  {
    n: 2,
    at: '2026-09-25T10:05:00Z',
    source: 'manual',
    autosaved: true,
    changes: ['~ [ESTILO]'],
    lines: { added: 1, removed: 1 },
  },
  {
    n: 3,
    at: '2026-09-25T10:09:00Z',
    source: 'assistant',
    summary: 'Corregí las directivas',
    changes: ['~ [4. REGLA]'],
    notes: ['~ [4. REGLA]: usa la información consultada'],
    lines: { added: 2, removed: 2 },
  },
  { n: 4, at: '2026-09-25T10:12:00Z', source: 'saved', summary: 'Universidad' },
];
const t = (k, a) => (a ? `${k}${JSON.stringify(a)}` : k);

describe('changeLog', () => {
  it('ordena de la más nueva a la más vieja y distingue lo guardado solo', () => {
    const e = logEntries(versiones);

    expect(e.map(x => x.source)).toEqual([
      'saved',
      'assistant',
      'autosave',
      'loaded',
    ]);
    expect(e[1]).toMatchObject({
      added: 2,
      removed: 2,
      notes: ['~ [4. REGLA]: usa la información consultada'],
    });
  });

  it('arma el .md con cada versión, sus cambios y lo que declaró el Asistente', () => {
    const md = changeLogMarkdown(
      versiones,
      t,
      at => at.slice(11, 16),
      'Universidad'
    );

    expect(md).toContain('# LOG_MD_TITLE — Universidad');
    expect(md).toContain(
      '## LOG_VERSION{"n":3} · 10:09 · LOG_SOURCE_ASSISTANT'
    );
    expect(md).toContain(
      '- ~ [4. REGLA]\n  - ~ [4. REGLA]: usa la información consultada'
    );
  });
});
