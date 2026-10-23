// @tickets_cases — Plan-Casos E1.2: lo que el agente deja elegido se recuerda por clase.
import {
  caseClassOfTicket,
  classHasSla,
  classI18nBase,
  lastCaseClass,
  lastCaseType,
  loadCaseState,
  rememberCaseClass,
  rememberCaseType,
  saveCaseState,
} from '../caseClasses';

describe('caseClasses — estado guardado', () => {
  beforeEach(() => window.localStorage.clear());

  it('Lista y Tablero comparten el estado de la clase y cada uno conserva lo suyo', () => {
    saveCaseState(1, 'commercial', {
      scope: 'all',
      fine: { priority: 'high' },
    });
    saveCaseState(1, 'commercial', { list: { status: 'closed' } });
    expect(loadCaseState(1, 'commercial')).toEqual({
      scope: 'all',
      fine: { priority: 'high' },
      list: { status: 'closed' },
    });
    expect(loadCaseState(1, 'support')).toEqual({});
  });

  it('recuerda la clase y el tipo por clase', () => {
    expect(lastCaseClass(1)).toBe('support');
    rememberCaseClass(1, 'commercial');
    rememberCaseType(1, 'commercial', 284);
    expect(lastCaseClass(1)).toBe('commercial');
    expect(lastCaseType(1, 'commercial')).toBe(284);
    expect(lastCaseType(1, 'support')).toBe('');
  });

  it('un valor corrupto no rompe la vista', () => {
    window.localStorage.setItem('cases.state.1.support', '{no-json');
    window.localStorage.setItem('cases.lastClass.1', 'otra');
    expect(loadCaseState(1, 'support')).toEqual({});
    expect(lastCaseClass(1)).toBe('support');
  });
});

// Plan-Clase-Orden-de-Trabajo F1 — la clase nueva y lo que solo es de Soporte.
describe('caseClasses — clases', () => {
  it('Orden de trabajo tiene sus textos; una clase desconocida cae a Soporte', () => {
    expect(classI18nBase('work_order')).toBe('CASE_TICKETS.CLASSES.WORK_ORDER');
    expect(classI18nBase('otra')).toBe('CASE_TICKETS.CLASSES.SUPPORT');
  });

  it('la clase del caso sale de su tipo; sin tipo es Soporte', () => {
    expect(caseClassOfTicket({ case_type: { case_class: 'work_order' } })).toBe(
      'work_order'
    );
    expect(caseClassOfTicket({})).toBe('support');
  });

  it('solo Soporte lleva SLA', () => {
    expect(classHasSla('support')).toBe(true);
    expect(classHasSla('commercial')).toBe(false);
    expect(classHasSla('work_order')).toBe(false);
  });
});
