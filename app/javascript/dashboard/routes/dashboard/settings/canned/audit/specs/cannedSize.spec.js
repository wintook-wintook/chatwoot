import {
  MAX_CHARS,
  WARN_CHARS,
  PROMPT_MAX_CHARS,
  PROMPT_WARN_CHARS,
  agentChars,
  sizeLevel,
  blocksOf,
} from '../cannedSize';

// proyecto@auditoria_predefinidas — lo mismo que mide el servidor.
describe('cannedSize', () => {
  it('cuenta nombre + «: » + contenido, como lo recibe el agente', () => {
    expect(agentChars('Horario', 'De 9 a 6')).toBe('Horario: De 9 a 6'.length);
    expect(agentChars('', '')).toBe(2);
  });

  it('pone el nivel por el tope de 3,500 y el aviso', () => {
    expect(MAX_CHARS).toBe(3500);
    expect(sizeLevel(WARN_CHARS)).toBe('ok');
    expect(sizeLevel(WARN_CHARS + 1)).toBe('near');
    expect(sizeLevel(MAX_CHARS)).toBe('near');
    expect(sizeLevel(MAX_CHARS + 1)).toBe('over');
  });

  it('el Prompt tiene su propio tope de 2,000', () => {
    expect(PROMPT_MAX_CHARS).toBe(2000);
    expect(
      sizeLevel(PROMPT_WARN_CHARS, PROMPT_MAX_CHARS, PROMPT_WARN_CHARS)
    ).toBe('ok');
    expect(
      sizeLevel(PROMPT_MAX_CHARS + 1, PROMPT_MAX_CHARS, PROMPT_WARN_CHARS)
    ).toBe('over');
  });

  it('parte en bloques como SectionFit: un encabezado suelto va con lo que sigue', () => {
    expect(
      blocksOf('Intro\n\nTITULACIÓN\n\nTesis y examen\n\n  \n\nFinal')
    ).toEqual(['Intro', 'TITULACIÓN\n\nTesis y examen', 'Final']);
  });
});
