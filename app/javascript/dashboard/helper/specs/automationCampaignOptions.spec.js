import { campaignOptionLabel, getActionOptions } from '../automationHelper';

// proyecto@automatizacion_campanas — el desplegable de "Agregar a campaña"
// (docs/automatizacion_campanas_plan.md §4). Fechas a mediodía UTC para que el día no
// cambie con la zona horaria de quien corre la prueba.
describe('Agregar a campaña', () => {
  const october = {
    id: 7,
    name: 'Campaña Octubre',
    status: 'running',
    scheduled_for: '2026-10-01T12:00:00Z',
    ends_at: '2026-10-31T12:00:00Z',
  };

  it('muestra nombre, estado y ventana', () => {
    expect(campaignOptionLabel(october)).toBe(
      'Campaña Octubre · En curso · 01/10 → 31/10'
    );
  });

  it('sin fin dice "sin fin", y sin fecha solo nombre y estado', () => {
    expect(campaignOptionLabel({ ...october, ends_at: null })).toBe(
      'Campaña Octubre · En curso · 01/10 → sin fin'
    );
    expect(
      campaignOptionLabel({ name: 'X', status: 'draft', scheduled_for: null })
    ).toBe('X · Programada');
  });

  it('lista todas las campañas, también las terminadas, con su id', () => {
    const options = getActionOptions({
      labels: [],
      trackingCampaigns: [october, { ...october, id: 8, status: 'finished' }],
      type: 'add_to_tracking_campaign',
    });

    expect(options.map(o => o.id)).toEqual([7, 8]);
    expect(options[1].name).toContain('Terminada');
  });

  it('sin campañas cargadas, lista vacía', () => {
    expect(
      getActionOptions({ labels: [], type: 'add_to_tracking_campaign' })
    ).toEqual([]);
  });
});
