// Menú v2 — reacomodo por lo que hace la gente (Inicio, Conversaciones, Ventas,
// Servicio, Agenda, Clientes, Agentes IA, Informes, Ajustes). Ver
// docs/vault-tickets/implementacion/Plan-Reacomodo-Menu.md.
//
// No reemplaza los archivos del menú de antes: los reusa y los reparte. Se
// enciende con MENU_V2 en ../../default-sidebar.js; apagado, vuelve el menú
// anterior tal cual. Ninguna ruta cambia.
//
// Ventas y Servicio comparten las pantallas de casos (`tickets/:caseClass/...`):
// el menú se elige con `matches(route)` por la clase de la ruta (Comercial →
// Ventas, las demás → Servicio). El detalle de un caso no trae la clase en la
// ruta: usa la última clase visitada.
import { FEATURE_FLAGS } from '../../../../../featureFlags';
import { frontendURL } from '../../../../../helper/URLHelper';
import {
  CLASS_VIEW_ROUTES,
  DEFAULT_CASE_CLASS,
  lastCaseClass,
} from '../../../../../helper/caseClasses';
import conversations from '../conversations';
import contacts from '../contacts';
import reports from '../reports';
import campaigns from '../campaigns';
import settings from '../settings';
import gestorTickets from '../gestorTickets';

const COMMERCIAL = 'commercial';
const CLASS_ROUTES = Object.values(CLASS_VIEW_ROUTES);
const KANBAN_ROUTES = [
  'kanban_dashboard',
  'kanban_board',
  'kanban_processes',
  'kanban_label',
  'label_kanban',
  'kanban_through_label',
  'kanban_status',
  'kanban_through_status',
  'kanban_type',
];
const CASE_SETTINGS_ROUTES = [
  'gestorTickets_rules',
  'gestorTickets_types',
  'gestorTickets_type_detail',
  'gestorTickets_classification',
  'gestorTickets_sla',
  'gestorTickets_ai',
  'gestorTickets_portals',
  'gestorTickets_settings',
  'gestorTickets_commercial_settings',
  'gestorTickets_task_settings',
  'gestorTickets_config',
  'gestorTickets_business_summary_access',
];

const routeName = route => (route && route.name) || '';

// Clase de la pantalla de casos en la que se está (null fuera de ellas).
export const caseClassOf = (route, accountId) => {
  const name = routeName(route);
  if (CLASS_ROUTES.includes(name)) return route.params.caseClass;
  if (name === 'gestorTickets_detail') return lastCaseClass(accountId);
  return null;
};

// Clase a la que llevan los enlaces de Servicio: la de la pantalla actual, o la
// última usada que no sea Comercial.
const serviceClass = (route, accountId) => {
  const current = caseClassOf(route, accountId);
  if (current && current !== COMMERCIAL) return current;
  const last = lastCaseClass(accountId);
  return last !== COMMERCIAL ? last : DEFAULT_CASE_CLASS;
};

export const primaryMenuV2 = (accountId, route) => {
  const url = path => frontendURL(`accounts/${accountId}/${path}`);
  return [
    {
      icon: 'home',
      key: 'inicio',
      label: 'HOME_SUMMARY',
      featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
      toState: url('start'),
      toStateName: 'my_summary',
    },
    {
      icon: 'chat',
      key: 'conversations',
      label: 'CONVERSATIONS',
      toState: url('dashboard'),
      toStateName: 'home',
    },
    {
      icon: 'heart-handshake',
      key: 'ventas',
      label: 'SALES',
      toState: url('kanban'),
      toStateName: 'kanban_dashboard',
    },
    {
      icon: 'clipboard',
      key: 'servicio',
      label: 'SERVICE',
      featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
      // A la lista de su clase, no a `tickets`: el menú principal marca activo por
      // prefijo de la dirección y `tickets` también es prefijo de las de Ventas.
      toState: url(`tickets/${serviceClass(route, accountId)}/list`),
      toStateName: CLASS_VIEW_ROUTES.list,
    },
    // Sin casos, Agenda es el calendario; sin calendario, las tareas.
    {
      icon: 'calendar',
      key: 'agenda',
      label: 'AGENDA',
      featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
      toState: url('tickets/tasks'),
      toStateName: 'gestorTickets_tasks',
      alternatives: [
        {
          featureFlag: FEATURE_FLAGS.GOOGLE_CALENDAR,
          toState: url('google-calendar'),
          toStateName: 'google_calendar',
        },
      ],
    },
    {
      icon: 'book-contacts',
      key: 'contacts',
      label: 'CLIENTS',
      featureFlag: FEATURE_FLAGS.CRM,
      toState: url('contacts'),
      toStateName: 'contacts_dashboard',
    },
    {
      icon: 'bot',
      key: 'campaigns',
      label: 'AI_AGENTS',
      featureFlag: FEATURE_FLAGS.CAMPAIGNS,
      toState: url('tracking-dashboard'),
      toStateName: 'contact_trackings_dashboard',
      alternatives: [
        {
          featureFlag: FEATURE_FLAGS.CAPTAIN,
          toState: url('captain'),
          toStateName: 'captain',
        },
      ],
    },
    {
      icon: 'arrow-trending-lines',
      key: 'reports',
      label: 'REPORTS',
      featureFlag: FEATURE_FLAGS.REPORTS,
      toState: url('reports'),
      toStateName: 'account_overview_reports',
    },
    {
      icon: 'library',
      key: 'helpcenter',
      label: 'HELP_CENTER.TITLE',
      featureFlag: FEATURE_FLAGS.HELP_CENTER,
      alwaysVisibleOnChatwootInstances: true,
      toState: url('portals'),
      toStateName: 'default_portal_articles',
    },
    // feat/licencias: solo en cuentas de Wintook y para quien tenga «Ver licencias»
    // (Sidebar.vue lo filtra con `licensesOnly`).
    {
      icon: 'lock-shield',
      key: 'licenses',
      label: 'LICENSES',
      licensesOnly: true,
      toState: url('licenses'),
      toStateName: 'licenses_index',
    },
    {
      icon: 'settings',
      key: 'settings',
      label: 'SETTINGS_V2',
      toState: url('settings'),
      toStateName: 'settings_home',
    },
  ];
};

// Sin opción de avisos: ya están en la campanita y en «Tienes avisos importantes»
// de Mi resumen. Su página sigue marcando Inicio.
const inicio = accountId => ({
  parentNav: 'inicio',
  routes: [
    'my_summary',
    'notifications_index',
    'gestorTickets_business_summary',
  ],
  menuItems: [
    {
      icon: 'home',
      label: 'MY_SUMMARY',
      featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
      toState: frontendURL(`accounts/${accountId}/start`),
      toStateName: 'my_summary',
    },
    {
      icon: 'briefcase',
      label: 'MY_BUSINESS',
      featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
      toState: frontendURL(`accounts/${accountId}/tickets/summary`),
      toStateName: 'gestorTickets_business_summary',
      visibleGetter: 'caseTickets/getCanViewBusinessSummary',
    },
  ],
});

const conversationsV2 = accountId => {
  const base = conversations(accountId);
  return {
    ...base,
    routes: [...base.routes, 'inbox_view', 'inbox_view_conversation'],
    menuItems: [
      ...base.menuItems,
      {
        icon: 'mail-inbox',
        label: 'INBOX_VIEW_V2',
        featureFlag: FEATURE_FLAGS.INBOX_VIEW,
        toState: frontendURL(`accounts/${accountId}/inbox-view`),
        toStateName: 'inbox_view',
      },
    ],
  };
};

const ventas = accountId => {
  const tickets = path => frontendURL(`accounts/${accountId}/tickets/${path}`);
  return {
    parentNav: 'ventas',
    // La lista de embudos (y «Agregar embudo») es la misma sección dinámica del
    // menú del tablero de conversaciones.
    extraSections: 'kanban',
    routes: KANBAN_ROUTES,
    matches: route =>
      KANBAN_ROUTES.includes(routeName(route)) ||
      caseClassOf(route, accountId) === COMMERCIAL,
    menuItems: [
      {
        icon: 'kanban',
        label: 'CONTACT_FUNNEL',
        toState: frontendURL(`accounts/${accountId}/kanban`),
        toStateName: 'kanban_dashboard',
      },
      {
        icon: 'list',
        label: 'OPPORTUNITIES',
        featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
        toState: tickets(`${COMMERCIAL}/list`),
        toStateName: CLASS_VIEW_ROUTES.list,
      },
      {
        icon: 'table-switch',
        label: 'OPPORTUNITY_BOARD',
        featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
        toState: tickets(`${COMMERCIAL}/board`),
        toStateName: CLASS_VIEW_ROUTES.board,
      },
      {
        icon: 'document',
        label: 'SALES_METRICS',
        featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
        toState: tickets(`${COMMERCIAL}/metrics`),
        toStateName: CLASS_VIEW_ROUTES.metrics,
      },
    ],
  };
};

const servicio = (accountId, route) => {
  const klass = serviceClass(route, accountId);
  const tickets = path => frontendURL(`accounts/${accountId}/tickets/${path}`);
  return {
    parentNav: 'servicio',
    routes: [],
    matches: route_ => {
      const current = caseClassOf(route_, accountId);
      return !!current && current !== COMMERCIAL;
    },
    menuItems: [
      {
        icon: 'list',
        label: 'SERVICE_CASES',
        toState: tickets(`${klass}/list`),
        toStateName: CLASS_VIEW_ROUTES.list,
      },
      {
        icon: 'table-switch',
        label: 'SERVICE_BOARD',
        toState: tickets(`${klass}/board`),
        toStateName: CLASS_VIEW_ROUTES.board,
      },
      {
        icon: 'document',
        label: 'SERVICE_METRICS',
        toState: tickets(`${klass}/metrics`),
        toStateName: CLASS_VIEW_ROUTES.metrics,
      },
    ],
  };
};

const agenda = accountId => ({
  parentNav: 'agenda',
  routes: ['gestorTickets_tasks', 'google_calendar'],
  menuItems: [
    {
      icon: 'checkmark-circle',
      label: 'TASKS_V2',
      featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
      toState: frontendURL(`accounts/${accountId}/tickets/tasks`),
      toStateName: 'gestorTickets_tasks',
    },
    {
      icon: 'calendar',
      label: 'CALENDAR',
      featureFlag: FEATURE_FLAGS.GOOGLE_CALENDAR,
      toState: frontendURL(`accounts/${accountId}/google-calendar`),
      toStateName: 'google_calendar',
    },
  ],
});

const agentesIa = accountId => {
  const base = campaigns(accountId);
  return {
    ...base,
    routes: [...base.routes, 'captain'],
    menuItems: [
      ...base.menuItems,
      {
        icon: 'captain',
        label: 'ASSISTANT',
        featureFlag: FEATURE_FLAGS.CAPTAIN,
        toState: frontendURL(`accounts/${accountId}/captain`),
        toStateName: 'captain',
      },
    ],
  };
};

// Ajustes = la configuración de antes + la de casos (el mismo grupo colapsable
// que tenía el menú de Casos) + los embudos de contactos.
const ajustes = accountId => {
  const base = settings(accountId);
  const caseGroup = gestorTickets(accountId).menuItems.find(
    item => item.collapsible
  );
  return {
    ...base,
    routes: [...base.routes, ...CASE_SETTINGS_ROUTES, 'kanban_types_list'],
    menuItems: [
      ...base.menuItems,
      {
        icon: 'kanban',
        label: 'CONTACT_FUNNELS',
        toState: frontendURL(`accounts/${accountId}/settings/kanban`),
        toStateName: 'kanban_types_list',
        meta: { permissions: ['administrator'] },
      },
      ...(caseGroup
        ? [
            {
              ...caseGroup,
              label: 'CASES_AND_STAGES',
              featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
            },
          ]
        : []),
    ],
  };
};

// feat/licencias
const licencias = accountId => ({
  parentNav: 'licenses',
  routes: ['licenses_index'],
  menuItems: [
    {
      icon: 'lock-shield',
      label: 'LICENSES',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/licenses`),
      toStateName: 'licenses_index',
    },
  ],
});

// El orden importa: gana el primer menú cuya ruta coincide (los de `matches`
// van antes que los de lista de rutas).
export const getSidebarItemsV2 = (accountId, route) => ({
  primaryMenu: primaryMenuV2(accountId, route),
  secondaryMenu: [
    ventas(accountId),
    servicio(accountId, route),
    inicio(accountId),
    conversationsV2(accountId),
    contacts(accountId),
    reports(accountId),
    agentesIa(accountId),
    agenda(accountId),
    ajustes(accountId),
    licencias(accountId),
  ],
});
