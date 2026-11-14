import { nextModuleKey, percent, stepBlockedKey } from '../academyHelpers';

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
});
