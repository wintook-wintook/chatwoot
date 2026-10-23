import AddAutomationRule from '../AddAutomationRule.vue';

// proyecto@automatizacion_campanas — desde una campaña continua recién creada, el modal
// de nueva automatización abre con la acción "Agregar a campaña" ya puesta.
describe('AddAutomationRule con preset', () => {
  const initialData = preset => AddAutomationRule.data.call({ preset });

  it('sin preset arranca como siempre', () => {
    const { automation } = initialData(null);

    expect(automation.name).toBeNull();
    expect(automation.actions).toEqual([
      { action_name: 'assign_agent', action_params: [] },
    ]);
  });

  it('con preset trae el nombre y la acción de la campaña', () => {
    const { automation } = initialData({
      name: 'Inscribir en "Octubre"',
      action: {
        action_name: 'add_to_tracking_campaign',
        action_params: { id: 256, name: 'Octubre' },
      },
    });

    expect(automation.name).toBe('Inscribir en "Octubre"');
    expect(automation.actions).toEqual([
      {
        action_name: 'add_to_tracking_campaign',
        action_params: { id: 256, name: 'Octubre' },
      },
    ]);
  });
});
