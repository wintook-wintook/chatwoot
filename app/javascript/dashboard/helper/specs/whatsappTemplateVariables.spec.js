import {
  RESERVED_FIELDS,
  resolveVariable,
  resolveVariables,
} from '../whatsappTemplateVariables';
import fixture from '../../../../../spec/fixtures/whatsapp_template_variables.json';

// feat/plantillas_variables_resolver F9.2 — los casos son los mismos que pasa el servidor
// (spec/services/whatsapp/template_variable_resolver_spec.rb). En el store la conversación
// trae su número en `id` y el asignado en `meta`.
const contextFrom = caso => {
  const { number, assignee, ...conversacion } = caso.conversation || {};
  return {
    contact: caso.contact,
    conversation: caso.conversation
      ? { ...conversacion, id: number, meta: { assignee } }
      : undefined,
    inbox: caso.inbox,
    agent: caso.agent,
    now: new Date(fixture.now),
  };
};

describe('resolveVariable', () => {
  it('los reservados son los mismos que los del servidor', () => {
    expect(RESERVED_FIELDS).toEqual(fixture.reserved);
  });

  it.each(fixture.cases.map(caso => [caso.title, caso]))('%s', (_, caso) => {
    const context = contextFrom(caso);

    Object.entries(caso.expected).forEach(([clave, esperado]) => {
      expect(resolveVariable(clave, context)).toBe(esperado || '');
    });
  });

  it('sin fecha dada usa la de hoy', () => {
    expect(resolveVariable('fecha_hoy')).toMatch(/^\d{2}\/\d{2}\/\d{4}$/);
  });
});

describe('resolveVariables', () => {
  it('separa lo que tiene dato de lo que falta, cada variable una vez', () => {
    const contact = { name: 'Juan', custom_attributes: { edad: 34 } };

    expect(
      resolveVariables(['nombre', 'edad', 'nombre', 'plan', '1'], { contact })
    ).toEqual({
      values: { nombre: 'Juan', edad: '34' },
      missing: ['plan', '1'],
    });
  });
});
