// @tickets_cases — Plan-Casos E1 (F6): rutas por clase y redirecciones neutras.
import VueRouter from 'vue-router';
import { routes } from './routes';
import { rememberCaseClass } from '../../../helper/caseClasses';

const router = new VueRouter({ mode: 'abstract', routes });
const resolve = path => router.resolve(path).route;

describe('gestorTickets routes', () => {
  beforeEach(() => window.localStorage.clear());

  it('resuelve las vistas por clase', () => {
    const list = resolve('/app/accounts/1/tickets/commercial/list');
    expect(list.name).toBe('gestorTickets_class_list');
    expect(list.params.caseClass).toBe('commercial');
    expect(resolve('/app/accounts/1/tickets/support/board').name).toBe(
      'gestorTickets_class_board'
    );
    expect(resolve('/app/accounts/1/tickets/support/metrics').name).toBe(
      'gestorTickets_class_metrics'
    );
  });

  it('no choca con el detalle de tipo ni con el detalle del caso', () => {
    expect(resolve('/app/accounts/1/tickets/types/5').name).toBe(
      'gestorTickets_type_detail'
    );
    expect(resolve('/app/accounts/1/tickets/123').name).toBe(
      'gestorTickets_detail'
    );
    expect(
      resolve('/app/accounts/1/tickets/work_order/list').params.caseClass
    ).toBe('work_order');
    expect(resolve('/app/accounts/1/tickets/otra/list').name).toBeNull();
  });

  it('las rutas de siempre redirigen a la última clase usada (Soporte si no hay)', () => {
    expect(resolve('/app/accounts/1/tickets').fullPath).toBe(
      '/app/accounts/1/tickets/support/list'
    );
    rememberCaseClass('1', 'commercial');
    expect(resolve('/app/accounts/1/tickets/kanban').fullPath).toBe(
      '/app/accounts/1/tickets/commercial/board'
    );
    expect(
      router.resolve({
        name: 'gestorTickets_metrics',
        params: { accountId: 1 },
      }).route.fullPath
    ).toBe('/app/accounts/1/tickets/commercial/metrics');
  });
});
