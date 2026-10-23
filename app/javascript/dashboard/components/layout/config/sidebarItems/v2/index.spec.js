import { getSidebarItemsV2, primaryMenuV2, caseClassOf } from './index';
import { rememberCaseClass } from '../../../../../helper/caseClasses';

const ACCOUNT = 1;
const route = (name, params = {}) => ({ name, params });

// Mismo criterio que Sidebar.vue#activeSecondaryMenu.
const menuFor = r =>
  getSidebarItemsV2(ACCOUNT, r).secondaryMenu.find(menu =>
    menu.matches ? menu.matches(r) : menu.routes.includes(r.name)
  ) || {};

describe('Menú v2', () => {
  beforeEach(() => localStorage.clear());

  it('ordena el menú principal por lo que hace la gente', () => {
    const primary = primaryMenuV2(ACCOUNT, route('home'));
    expect(primary.find(i => i.key === 'servicio').toState).toContain(
      'tickets/support/list'
    );
    expect(primary.map(item => item.key)).toEqual([
      'inicio',
      'conversations',
      'ventas',
      'servicio',
      'agenda',
      'contacts',
      'campaigns',
      'reports',
      'helpcenter',
      'settings',
    ]);
  });

  it('cada menú secundario tiene su entrada en el principal', () => {
    const keys = primaryMenuV2(ACCOUNT, route('home')).map(item => item.key);
    getSidebarItemsV2(ACCOUNT, route('home')).secondaryMenu.forEach(menu => {
      expect(keys).toContain(menu.parentNav);
    });
  });

  it('las pantallas Comerciales y el embudo de contactos son de Ventas', () => {
    expect(
      menuFor(route('gestorTickets_class_list', { caseClass: 'commercial' }))
        .parentNav
    ).toBe('ventas');
    expect(menuFor(route('kanban_type', { typeId: 3 })).parentNav).toBe(
      'ventas'
    );
    expect(menuFor(route('kanban_dashboard')).extraSections).toBe('kanban');
  });

  it('las demás clases son de Servicio y sus enlaces siguen la clase actual', () => {
    const r = route('gestorTickets_class_board', { caseClass: 'work_order' });
    const menu = menuFor(r);
    expect(menu.parentNav).toBe('servicio');
    expect(menu.menuItems[0].toState).toContain('tickets/work_order/list');
  });

  it('el detalle de un caso usa la última clase visitada', () => {
    rememberCaseClass(ACCOUNT, 'commercial');
    expect(menuFor(route('gestorTickets_detail', { id: 9 })).parentNav).toBe(
      'ventas'
    );
    rememberCaseClass(ACCOUNT, 'support');
    expect(menuFor(route('gestorTickets_detail', { id: 9 })).parentNav).toBe(
      'servicio'
    );
    expect(caseClassOf(route('home'), ACCOUNT)).toBeNull();
  });

  it('Servicio nunca enlaza a Comercial', () => {
    rememberCaseClass(ACCOUNT, 'commercial');
    const servicio = getSidebarItemsV2(
      ACCOUNT,
      route('home')
    ).secondaryMenu.find(m => m.parentNav === 'servicio');
    expect(servicio.menuItems[0].toState).toContain('tickets/support/list');
  });

  it('la configuración de casos y los embudos quedan en Ajustes', () => {
    expect(menuFor(route('gestorTickets_sla')).parentNav).toBe('settings');
    expect(menuFor(route('kanban_types_list')).parentNav).toBe('settings');
    const ajustes = menuFor(route('agent_list'));
    expect(ajustes.menuItems.map(i => i.label)).toEqual(
      expect.arrayContaining(['CONTACT_FUNNELS', 'CASES_AND_STAGES'])
    );
  });

  it('Inicio no tiene opción de avisos', () => {
    const inicio = menuFor(route('my_summary'));
    expect(inicio.menuItems.map(i => i.label)).toEqual([
      'MY_SUMMARY',
      'MY_BUSINESS',
    ]);
  });

  it('Inicio, Agenda, Agentes IA y Vista de bandeja', () => {
    expect(menuFor(route('notifications_index')).parentNav).toBe('inicio');
    expect(menuFor(route('gestorTickets_business_summary')).parentNav).toBe(
      'inicio'
    );
    expect(menuFor(route('gestorTickets_tasks')).parentNav).toBe('agenda');
    expect(menuFor(route('google_calendar')).parentNav).toBe('agenda');
    expect(menuFor(route('captain')).parentNav).toBe('campaigns');
    expect(menuFor(route('inbox_view')).parentNav).toBe('conversations');
  });
});
