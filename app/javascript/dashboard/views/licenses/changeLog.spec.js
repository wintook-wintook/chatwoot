import { changeText, featureLabel } from './changeLog';

// feat/licencias F6.4 — las frases del registro
const t = (clave, args) => (args ? `${clave} ${JSON.stringify(args)}` : clave);
const frase = (event, params) => changeText({ event, params }, t);

describe('changeText', () => {
  it('licencias: asignar, subir el tope y cambiar de estado', () => {
    expect(
      frase('license_created', {
        name: 'Pro',
        max_agents: 5,
        duration_days: 30,
      })
    ).toBe(
      'CHANGES.EVENTS.LICENSE_CREATED {"name":"Pro","days":30,"agents":5}'
    );
    expect(frase('license_agents', { name: 'Pro', from: 5, to: 7 })).toContain(
      '"from":5,"to":7'
    );
    expect(
      frase('license_status', { name: 'Pro', from: 'active', to: 'expired' })
    ).toContain('"from":"STATUS.ACTIVE","to":"STATUS.EXPIRED"');
  });

  it('agentes con su rol traducido; sin nombre, una raya', () => {
    expect(frase('agent_added', { name: 'Luis', role: 'agent' })).toContain(
      '"role":"DETAIL.ROLES.AGENT"'
    );
    expect(frase('agent_removed', {})).toContain('"name":"—"');
  });

  it('funciones encendidas y apagadas en una frase', () => {
    expect(
      frase('features_changed', { on: ['channel_whatsapp'], off: ['macros'] })
    ).toBe(
      'CHANGES.EVENTS.FEATURES_ON {"list":"whatsapp"} · CHANGES.EVENTS.FEATURES_OFF {"list":"macros"}'
    );
    expect(featureLabel('case_management')).toBe('case management');
  });

  it('la cuenta: suspender, renombrar y otros campos con su nombre', () => {
    expect(frase('account_status', { to: 'suspended' })).toBe(
      'CHANGES.EVENTS.ACCOUNT_SUSPENDED'
    );
    expect(
      frase('account_changed', { fields: ['name'], from: 'A', to: 'B' })
    ).toContain('ACCOUNT_RENAMED');
    expect(
      frase('account_changed', { fields: ['custom_attributes', 'raro'] })
    ).toContain('"fields":"CHANGES.FIELDS.CUSTOM_ATTRIBUTES, raro"');
  });

  it('un agente en una bandeja dice cuál', () => {
    expect(frase('inbox_member_added', { name: 'Luis', inbox: 'Ventas' })).toBe(
      'CHANGES.EVENTS.INBOX_MEMBER_ADDED {"name":"Luis","inbox":"Ventas"}'
    );
  });

  it('otros registros dicen qué son', () => {
    expect(frase('record_deleted', { type: 'Team', name: 'Soporte' })).toBe(
      'CHANGES.EVENTS.RECORD_DELETED {"type":"CHANGES.TYPES.TEAM","name":"Soporte"}'
    );
  });
});
