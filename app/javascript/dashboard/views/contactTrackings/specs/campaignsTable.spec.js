import { progressPct, sortCampaigns, sortFromParams } from '../campaignsTable';

const campaigns = [
  {
    name: 'beta',
    status: 'running',
    scheduled_for: '2026-10-02T10:00:00Z',
    stats: { total: 4, completed: 1 },
  },
  {
    name: 'Alfa',
    status: 'saved',
    scheduled_for: '2026-10-03T10:00:00Z',
    stats: { total: 0, completed: 0 },
  },
  {
    name: 'gama',
    status: 'finished',
    scheduled_for: '2026-10-01T10:00:00Z',
    stats: { total: 2, completed: 2 },
  },
];
const names = list => list.map(c => c.name);

describe('campaignsTable', () => {
  it('toma la columna que trae orden de lo que manda VeTable', () => {
    expect(sortFromParams({ name: '', progress: 'desc' })).toEqual({
      progress: 'desc',
    });
    expect(sortFromParams({ name: '', status: '' })).toEqual({});
  });

  it('ordena por texto sin distinguir mayúsculas, por fecha y por avance', () => {
    expect(names(sortCampaigns(campaigns, { name: 'asc' }))).toEqual([
      'Alfa',
      'beta',
      'gama',
    ]);
    expect(names(sortCampaigns(campaigns, { scheduled_for: 'desc' }))).toEqual([
      'Alfa',
      'beta',
      'gama',
    ]);
    expect(names(sortCampaigns(campaigns, { progress: 'desc' }))).toEqual([
      'gama',
      'beta',
      'Alfa',
    ]);
  });

  it('sin orden deja el listado como viene y no lo muta', () => {
    const copy = [...campaigns];
    expect(sortCampaigns(campaigns, {})).toBe(campaigns);
    sortCampaigns(campaigns, { name: 'asc' });
    expect(campaigns).toEqual(copy);
    expect(progressPct({ total: 4, completed: 1 })).toBe(25);
  });
});
