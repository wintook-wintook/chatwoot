import {
  RESERVED_FIELDS,
  chatVariableContext,
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

describe('chatVariableContext', () => {
  const sender = { id: 1, name: 'Juan', custom_attributes: { plan: 'Plus' } };
  const yo = { available_name: 'Yo' };

  it('quien manda es el agente solo si no hay asignado', () => {
    const asignado = { available_name: 'Ana' };

    expect(
      resolveVariable(
        'agente',
        chatVariableContext({
          conversation: { meta: { sender } },
          currentUser: yo,
        })
      )
    ).toBe('Yo');
    expect(
      resolveVariable(
        'agente',
        chatVariableContext({
          conversation: { meta: { sender, assignee: asignado } },
          currentUser: yo,
        })
      )
    ).toBe('Ana');
  });

  it('el contacto del store gana sobre meta.sender', () => {
    const context = chatVariableContext({
      conversation: { meta: { sender } },
      contact: { custom_attributes: { plan: 'Oro' } },
    });

    expect(resolveVariable('plan', context)).toBe('Oro');
    expect(resolveVariable('nombre', context)).toBe('Juan');
  });

  it('sirve sin conversación, y sin contacto no hay de dónde llenar', () => {
    expect(
      resolveVariable('nombre', chatVariableContext({ contact: sender }))
    ).toBe('Juan');
    expect(chatVariableContext({ conversation: {} })).toEqual({});
  });
});
