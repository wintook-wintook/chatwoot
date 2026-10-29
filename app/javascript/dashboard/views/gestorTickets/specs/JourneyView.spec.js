// Avance: mover entre columnas con el mismo estado (Propuesta → Negociación) también es avance.
import { shallowMount } from '@vue/test-utils';
import JourneyView from '../JourneyView.vue';

const COLUMNS = [
  { id: 1, label: 'Prospección', position: 1, statuses: ['open'] },
  { id: 2, label: 'Propuesta', position: 2, statuses: ['in_progress'] },
  { id: 3, label: 'Negociación', position: 3, statuses: ['in_progress'] },
];

const mountJourney = (columnId, events) =>
  shallowMount(JourneyView, {
    propsData: {
      ticket: {
        status: 'in_progress',
        case_type_column_id: columnId,
        created_at: '2026-10-01T10:00:00Z',
        case_type: { columns: COLUMNS },
      },
      events,
    },
    mocks: { $t: key => key, $te: () => false },
    stubs: { FluentIcon: true },
  });

const toProposal = {
  event_type: 'status_changed',
  payload: { from: 'open', to: 'in_progress' },
  created_at: '2026-10-02T10:00:00Z',
  actor: { name: 'Ana' },
};
const toNegotiation = {
  event_type: 'column_changed',
  payload: { from: 2, to: 3, status: 'in_progress' },
  created_at: '2026-10-03T10:00:00Z',
  actor: { name: 'Luis' },
};

describe('JourneyView › Avance', () => {
  it('Negociación queda alcanzada, actual y con quién la movió', () => {
    const phases = mountJourney(3, [toProposal, toNegotiation]).vm.phaseJourney;
    expect(phases.map(p => p.reached)).toEqual([true, true, true]);
    expect(phases[2]).toMatchObject({ current: true, subState: 'in_progress' });
    expect(phases[2].meta.actor).toBe('Luis');
    expect(phases[1].current).toBe(false);
  });

  it('la etapa actual se ve alcanzada aunque falte su evento (casos viejos)', () => {
    const phases = mountJourney(3, [toProposal]).vm.phaseJourney;
    expect(phases[2]).toMatchObject({ current: true, reached: true });
  });
});
