import { getSidebarItemsV2, primaryMenuV2, caseClassOf } from './index';
import {
  rememberCaseClass,
  rememberCaseView,
} from '../../../../../helper/caseClasses';

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
      'agenda',
      'ventas',
      'servicio',
      'contacts',
      'campaigns',
      'agentes',
      'reports',
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
    const ventas = menuFor(route('kanban_dashboard'));
    expect(ventas.extraSections).toBeUndefined();
    expect(ventas.menuItems.map(i => i.label)).toEqual([
      'CONTACT_FUNNEL',
      'OPPORTUNITIES',
      'WHATSAPP_TEMPLATES',
      'LABELS',
      'CANNED_RESPONSES',
    ]);
    // Oportunidades abre el tablero la primera vez y se marca en las tres vistas.
    const opportunities = ventas.menuItems[1];
    expect(opportunities.toState).toContain('tickets/commercial/board');
    expect(opportunities.activeRoutes).toEqual(
      expect.arrayContaining([
        'gestorTickets_class_list',
        'gestorTickets_class_board',
        'gestorTickets_class_metrics',
      ])
    );
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

  it('cada área vuelve a la última forma de ver que usó', () => {
    rememberCaseView(ACCOUNT, 'commercial', 'metrics');
    rememberCaseView(ACCOUNT, 'support', 'board');
    const menus = getSidebarItemsV2(ACCOUNT, route('home')).secondaryMenu;
    const item = key => menus.find(m => m.parentNav === key).menuItems;
    expect(item('ventas')[1].toState).toContain('tickets/commercial/metrics');
    expect(item('servicio')).toHaveLength(5);
    expect(item('servicio')[0].toState).toContain('tickets/support/board');
  });

  it('Informes: negocio, dashboards por área y conversaciones plegadas', () => {
    const informes = menuFor(route('account_overview_reports'));
    expect(informes.parentNav).toBe('reports');
    expect(informes.menuItems.map(i => i.label)).toEqual([
      'BUSINESS_SUMMARY',
      'SALES_DASHBOARD',
      'SERVICE_DASHBOARD',
      'CAMPAIGNS_DASHBOARD_REPORT',
      'REPORTS_GROUP_CONVERSATIONS',
    ]);
    expect(informes.menuItems[1].toState).toContain(
      'tickets/commercial/metrics'
    );
    expect(informes.menuItems[2].toState).toContain('tickets/support/metrics');
    const grupo = informes.menuItems[4];
    expect(grupo.collapsible).toBe(true);
    expect(grupo.children.map(c => c.label)).toEqual([
      'REPORTS_LIVE',
      'REPORTS_CONVERSATION',
      'REPORTS_BY_AGENT',
      'REPORTS_BY_TEAM',
      'REPORTS_BY_INBOX',
      'REPORTS_BY_LABEL',
      'REPORTS_CSAT_V2',
      'REPORTS_BOT',
    ]);
    // El SLA de Chatwoot sale del menú, pero su pantalla sigue en Informes.
    expect(grupo.children.map(c => c.toStateName)).not.toContain('sla_reports');
    expect(menuFor(route('sla_reports')).parentNav).toBe('reports');
    // «Resumen del negocio» sigue también en Inicio › Mi negocio.
    expect(menuFor(route('my_summary')).menuItems.map(i => i.label)).toContain(
      'MY_BUSINESS'
    );
  });

  it('plantillas, etiquetas y respuestas predefinidas pasan de Ajustes a Ventas', () => {
    [
      'labels_list',
      'canned_list',
      'whatsapp_templates_index',
      'whatsapp_templates_wrapper',
    ].forEach(name => expect(menuFor(route(name)).parentNav).toBe('ventas'));
    const ajustes = menuFor(route('agent_list'));
    const labels = ajustes.menuItems.map(i => i.label);
    ['LABELS', 'CANNED_RESPONSES', 'WHATSAPP_TEMPLATES'].forEach(label =>
      expect(labels).not.toContain(label)
    );
  });

  it('Servicio: casos, clasificación, SLA, portales y Centro de ayuda', () => {
    const servicio = menuFor(
      route('gestorTickets_class_list', { caseClass: 'support' })
    );
    expect(servicio.menuItems.map(i => i.toStateName)).toEqual([
      'gestorTickets_class_list',
      'gestorTickets_classification',
      'gestorTickets_sla',
      'gestorTickets_portals',
      'default_portal_articles',
    ]);
    [
      'gestorTickets_classification',
      'gestorTickets_sla',
      'gestorTickets_portals',
    ].forEach(name => expect(menuFor(route(name)).parentNav).toBe('servicio'));
    // Dentro del Centro de ayuda solo se marca Servicio (su menú es el suyo).
    const ayuda = menuFor({
      name: 'list_all_locale_articles',
      path: '/app/accounts/1/portals/x/es/articles',
      params: {},
    });
    expect(ayuda.parentNav).toBe('servicio');
    expect(ayuda.menuItems).toEqual([]);
    // Y salen de Ajustes › Casos y etapas.
    const grupo = menuFor(route('agent_list')).menuItems.find(
      i => i.label === 'CASES_AND_STAGES'
    );
    expect(grupo.children.map(c => c.toStateName)).not.toEqual(
      expect.arrayContaining(['gestorTickets_sla'])
    );
    expect(grupo.children.map(c => c.toStateName)).toContain(
      'gestorTickets_types'
    );
  });

  it('Agenda: Tareas (abre en Mi día), Calendario y Prioridad de Mi día', () => {
    const agenda = menuFor(route('gestorTickets_tasks'));
    expect(agenda.menuItems.map(i => i.label)).toEqual([
      'TASKS_V2',
      'CALENDAR',
      'MY_DAY_PRIORITY',
    ]);
    expect(agenda.menuItems[0].toState).toContain('tickets/tasks?tab=my_day');
    expect(menuFor(route('gestorTickets_task_settings')).parentNav).toBe(
      'agenda'
    );
    const grupo = menuFor(route('agent_list')).menuItems.find(
      i => i.label === 'CASES_AND_STAGES'
    );
    expect(grupo.children.map(c => c.toStateName)).not.toContain(
      'gestorTickets_task_settings'
    );
    const primary = primaryMenuV2(ACCOUNT, route('home'));
    expect(primary.find(i => i.key === 'agenda').toState).toContain(
      'tab=my_day'
    );
  });

  it('Clientes: contactos y atributos personalizados (salen de Ajustes)', () => {
    const clientes = menuFor(route('attributes_list'));
    expect(clientes.parentNav).toBe('contacts');
    expect(clientes.menuItems.map(i => i.label)).toEqual([
      'ALL_CONTACTS',
      'CUSTOM_ATTRIBUTES',
    ]);
    const ajustes = menuFor(route('agent_list'));
    expect(ajustes.menuItems.map(i => i.label)).not.toContain(
      'CUSTOM_ATTRIBUTES'
    );
  });

  it('Agentes IA y Campañas son dos áreas; lo de IA sale de Ajustes', () => {
    const agentes = menuFor(route('contact_trackings_agents'));
    expect(agentes.parentNav).toBe('agentes');
    expect(agentes.menuItems.map(i => i.label)).toEqual([
      'AI_AGENT_LIST',
      'TRACKINGS',
      'KNOWLEDGE_SOURCES',
      'CHATGPT',
      'SITE_ANALYSIS',
      'AUTOMATION',
    ]);
    [
      'automation_list',
      'knowledge_sources_list',
      'tracking_templates_list',
    ].forEach(name => expect(menuFor(route(name)).parentNav).toBe('agentes'));
    const campanas = menuFor(route('contact_trackings_campaign_detail'));
    expect(campanas.parentNav).toBe('campaigns');
    expect(campanas.menuItems.map(i => i.label)).toEqual([
      'CAMPAIGNS_AI',
      'CAMPAIGNS_WEB',
      'CAMPAIGNS_SMS',
      'CAMPAIGNS_DASHBOARD',
    ]);
    expect(menuFor(route('contact_trackings_metrics')).parentNav).toBe(
      'campaigns'
    );
    expect(menuFor(route('captain')).parentNav).toBeUndefined();
    const ajustes = menuFor(route('agent_list')).menuItems.map(i => i.label);
    [
      'AUTOMATION',
      'KNOWLEDGE_SOURCES',
      'CHATGPT',
      'TRACKING_TEMPLATES',
      'SITE_ANALYSIS',
    ].forEach(label => expect(ajustes).not.toContain(label));
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
    expect(menuFor(route('gestorTickets_rules')).parentNav).toBe('settings');
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
    expect(menuFor(route('inbox_view')).parentNav).toBe('conversations');
  });
});
