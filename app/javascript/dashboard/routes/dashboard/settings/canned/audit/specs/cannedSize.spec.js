import { MAX_CHARS, agentChars, sizeLevel, blocksOf } from '../cannedSize';

// proyecto@auditoria_predefinidas — lo mismo que mide el servidor.
describe('cannedSize', () => {
  it('cuenta nombre + «: » + contenido, como lo recibe el agente', () => {
    expect(agentChars('Horario', 'De 9 a 6')).toBe('Horario: De 9 a 6'.length);
    expect(agentChars('', '')).toBe(2);
  });

  it('pone el nivel por el tope y el 80 %', () => {
    expect(sizeLevel(1600)).toBe('ok');
    expect(sizeLevel(1601)).toBe('near');
    expect(sizeLevel(MAX_CHARS)).toBe('near');
    expect(sizeLevel(MAX_CHARS + 1)).toBe('over');
  });

  it('parte en bloques como SectionFit: un encabezado suelto va con lo que sigue', () => {
    expect(
      blocksOf('Intro\n\nTITULACIÓN\n\nTesis y examen\n\n  \n\nFinal')
    ).toEqual(['Intro', 'TITULACIÓN\n\nTesis y examen', 'Final']);
  });
});
