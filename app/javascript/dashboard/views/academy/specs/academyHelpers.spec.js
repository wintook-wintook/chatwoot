import {
  nextModuleKey,
  percent,
  stepBlockedKey,
  stepTypeKey,
  usesPractice,
} from '../academyHelpers';

describe('academyHelpers', () => {
  it('sigue con el primer módulo sin terminar', () => {
    const modules = [
      { key: 'conversaciones', status: 'done' },
      { key: 'contactos', status: 'in_progress' },
      { key: 'casos', status: 'pending' },
    ];
    expect(nextModuleKey(modules)).toBe('contactos');
    expect(nextModuleKey([{ key: 'a', status: 'done' }])).toBeNull();
    expect(nextModuleKey(undefined)).toBeNull();
  });

  it('porcentaje sin dividir entre cero', () => {
    expect(percent(1, 3)).toBe(33);
    expect(percent(0, 0)).toBe(0);
  });

  it('dice qué le falta a un paso bloqueado', () => {
    expect(stepBlockedKey({ blocked: true, needs: 'practice_contact' })).toBe(
      'BLOCKED'
    );
    expect(stepBlockedKey({ blocked: true, needs: 'practice_case' })).toBe(
      'BLOCKED_CASE'
    );
    expect(
      stepBlockedKey({ blocked: false, needs: 'practice_case' })
    ).toBeNull();
    expect(stepBlockedKey({ blocked: true, status: 'done' })).toBeNull();
  });

  it('la etiqueta del paso: lección, ejercicio o nivel de configuración', () => {
    expect(stepTypeKey({ kind: 'lesson' })).toBe('LESSON');
    expect(stepTypeKey({ kind: 'exercise' })).toBe('EXERCISE');
    expect(stepTypeKey({ kind: 'setup', level: 'required' })).toBe(
      'LEVEL.required'
    );
  });

  it('la tarjeta del Cliente de práctica solo si algún módulo lo usa', () => {
    const setupOnly = [{ steps: [{ key: 'foto', kind: 'setup' }] }];
    expect(usesPractice(setupOnly)).toBe(false);
    expect(
      usesPractice([{ steps: [{ key: 'nota', needs: 'practice_contact' }] }])
    ).toBe(true);
  });
});
