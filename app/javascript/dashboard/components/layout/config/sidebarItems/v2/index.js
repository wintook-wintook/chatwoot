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
  lastCaseView,
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

// Lo que se usa todo el día y no es configuración técnica: pasa de Ajustes a
// Ventas (las mismas pantallas y direcciones; solo cambia el menú).
const SALES_TOOLS = ['whatsapp_templates_index', 'labels_list', 'canned_list'];
const SALES_TOOL_ROUTES = [...SALES_TOOLS, 'whatsapp_templates_wrapper'];
// Plan-Catalogo-Cotizaciones — pantallas propias de Ventas.
const SALES_ROUTES = [
  'gestorTickets_quotes',
  'gestorTickets_quote_new',
  'gestorTickets_quote',
  'gestorTickets_catalog',
];
// Los campos extra del contacto: pasan de Ajustes a Clientes.
const CLIENT_TOOLS = ['attributes_list'];
// Lo que define qué sabe y qué hace la IA: pasa de Ajustes a Agentes IA.
const AI_TOOLS = [
  'knowledge_sources_list',
  'chatgpt_list',
  'website_sketch_list',
  'automation_list',
];
// En Ajustes «Agentes IA» (plantillas) solo redirigía a la lista de Agentes IA.
const DUPLICATED_SETTINGS = ['tracking_templates_list'];
// Todo lo que sale de Ajustes (opciones y rutas).
const MOVED_SETTINGS = [
  ...SALES_TOOLS,
  ...CLIENT_TOOLS,
  ...AI_TOOLS,
  ...DUPLICATED_SETTINGS,
];
const MOVED_SETTINGS_ROUTES = [
  ...SALES_TOOL_ROUTES,
  ...CLIENT_TOOLS,
  ...AI_TOOLS,
  ...DUPLICATED_SETTINGS,
];

// Lo que soporte ajusta mientras opera: pasa de Ajustes › Casos y etapas a Servicio.
const SERVICE_TOOLS = [
  'gestorTickets_classification',
  'gestorTickets_sla',
  'gestorTickets_portals',
];
// «Prioridad de Mi día» se ajusta según cómo trabaja el equipo: pasa a Agenda.
const AGENDA_TOOLS = ['gestorTickets_task_settings'];
// Lo que sale de Ajustes › Casos y etapas hacia las áreas.
const MOVED_CASE_SETTINGS = [...SERVICE_TOOLS, ...AGENDA_TOOLS];
// El Centro de ayuda (`accounts/:id/portals...`) trae su propio menú interno.
const HELP_CENTER_PATH = /\/accounts\/\d+\/portals(\/|$)/;

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

// Las opciones tal como estaban en Ajustes (íconos, permisos y flags).
const settingsItems = (accountId, names) =>
  names
    .map(name =>
      settings(accountId).menuItems.find(item => item.toStateName === name)
    )
    .filter(Boolean);

const caseSettingsGroup = accountId =>
  gestorTickets(accountId).menuItems.find(item => item.collapsible);
const caseSettingsChildren = accountId =>
  (caseSettingsGroup(accountId) || {}).children || [];

// Una sola opción por área para sus casos: adentro se elige la forma de ver
// (Lista | Tablero | Dashboard, ver CaseClassSwitcher) y la opción vuelve a
// la última usada. Se marca activa en las tres vistas y en el detalle.
const casesItem = (accountId, caseClass, label, fallbackView) => {
  const view = lastCaseView(accountId, caseClass, fallbackView);
  return {
    icon: 'list',
    label,
    featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
    toState: frontendURL(`accounts/${accountId}/tickets/${caseClass}/${view}`),
    toStateName: CLASS_VIEW_ROUTES[view],
    activeRoutes: [...CLASS_ROUTES, 'gestorTickets_detail'],
  };
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
    // Sin casos, Agenda es el calendario; sin calendario, las tareas.
    {
      icon: 'calendar',
      key: 'agenda',
      label: 'AGENDA',
      featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
      toState: url('tickets/tasks?tab=my_day'),
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
    {
      icon: 'book-contacts',
      key: 'contacts',
      label: 'CLIENTS',
      featureFlag: FEATURE_FLAGS.CRM,
      toState: url('contacts'),
      toStateName: 'contacts_dashboard',
    },
    {
      icon: 'megaphone',
      key: 'campaigns',
      label: 'CAMPAIGNS_V2',
      featureFlag: FEATURE_FLAGS.CAMPAIGNS,
      toState: url('tracking-dashboard/campaigns'),
      toStateName: 'contact_trackings_campaigns',
    },
    {
      icon: 'bot',
      key: 'agentes',
      label: 'AI_AGENTS',
      featureFlag: FEATURE_FLAGS.CAMPAIGNS,
      toState: url('tracking-dashboard/agents'),
      toStateName: 'contact_trackings_agents',
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
  return {
    parentNav: 'ventas',
    routes: [...KANBAN_ROUTES, ...SALES_ROUTES, ...SALES_TOOL_ROUTES],
    matches: route =>
      KANBAN_ROUTES.includes(routeName(route)) ||
      SALES_ROUTES.includes(routeName(route)) ||
      SALES_TOOL_ROUTES.includes(routeName(route)) ||
      caseClassOf(route, accountId) === COMMERCIAL,
    // Dos opciones: los prospectos (qué embudo ver se elige DENTRO del tablero;
    // crearlos y configurarlos, en Ajustes › Embudos de contactos) y las
    // oportunidades (Lista | Tablero | Dashboard adentro).
    menuItems: [
      {
        icon: 'kanban',
        label: 'CONTACT_FUNNEL',
        toState: frontendURL(`accounts/${accountId}/kanban`),
        toStateName: 'kanban_dashboard',
      },
      casesItem(accountId, COMMERCIAL, 'OPPORTUNITIES', 'board'),
      {
        icon: 'document',
        label: 'QUOTES',
        featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
        toState: frontendURL(`accounts/${accountId}/tickets/quotes`),
        toStateName: 'gestorTickets_quotes',
        activeRoutes: ['gestorTickets_quote_new', 'gestorTickets_quote'],
      },
      {
        icon: 'book',
        label: 'CATALOG',
        featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
        toState: frontendURL(`accounts/${accountId}/tickets/catalog`),
        toStateName: 'gestorTickets_catalog',
      },
      // Mismos ítems (íconos, permisos y flags) que tenían en Ajustes.
      ...settingsItems(accountId, SALES_TOOLS),
    ],
  };
};

const FIELD_SERVICE_ROUTES = [
  'gestorTickets_dispatch',
  'gestorTickets_maintenance',
];

const servicio = (accountId, route) => {
  const klass = serviceClass(route, accountId);
  return {
    parentNav: 'servicio',
    routes: [],
    matches: route_ => {
      if (SERVICE_TOOLS.includes(routeName(route_))) return true;
      // Plan-Trabajo-Campo R3/R4
      if (FIELD_SERVICE_ROUTES.includes(routeName(route_))) return true;
      const current = caseClassOf(route_, accountId);
      return !!current && current !== COMMERCIAL;
    },
    menuItems: [
      casesItem(accountId, klass, 'SERVICE_CASES', 'list'),
      // Plan-Trabajo-Campo R3 — el día de los técnicos.
      {
        icon: 'calendar-clock',
        label: 'DISPATCH',
        featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
        toState: frontendURL(`accounts/${accountId}/tickets/dispatch`),
        toStateName: 'gestorTickets_dispatch',
      },
      // Plan-Trabajo-Campo R4 — mantenimientos recurrentes de todos los clientes.
      {
        icon: 'arrow-clockwise',
        label: 'MAINTENANCE',
        featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
        toState: frontendURL(`accounts/${accountId}/tickets/maintenance`),
        toStateName: 'gestorTickets_maintenance',
      },
      // Mismos ítems (íconos y permisos de administrador) que en Casos y etapas.
      ...caseSettingsChildren(accountId)
        .filter(child => SERVICE_TOOLS.includes(child.toStateName))
        .map(child => ({
          ...child,
          featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
        })),
      {
        icon: 'library',
        label: 'HELP_CENTER.TITLE',
        featureFlag: FEATURE_FLAGS.HELP_CENTER,
        toState: frontendURL(`accounts/${accountId}/portals`),
        toStateName: 'default_portal_articles',
      },
    ],
  };
};

// Dentro del Centro de ayuda manda su propio menú: este registro, sin opciones,
// solo marca Servicio en el menú principal (Secondary no pinta un menú vacío).
const centroDeAyuda = () => ({
  parentNav: 'servicio',
  routes: [],
  matches: route => HELP_CENTER_PATH.test((route && route.path) || ''),
  menuItems: [],
});

// Informes: primero la foto del negocio y los dashboards de cada área (en el
// orden del menú; llevan a la misma pantalla que su botón «Dashboard»), luego,
// plegado, el detalle de conversaciones de Chatwoot con nombres claros. El SLA
// de Chatwoot sale del menú (se confunde con el SLA de Servicio).
const REPORTS_GROUP = [
  ['account_overview_reports', 'REPORTS_LIVE'],
  ['conversation_reports', 'REPORTS_CONVERSATION'],
  ['agent_reports', 'REPORTS_BY_AGENT'],
  ['team_reports', 'REPORTS_BY_TEAM'],
  ['inbox_reports', 'REPORTS_BY_INBOX'],
  ['label_reports', 'REPORTS_BY_LABEL'],
  ['csat_reports', 'REPORTS_CSAT_V2'],
  ['bot_reports', 'REPORTS_BOT'],
];

const informes = (accountId, route) => {
  const base = reports(accountId);
  const byName = name => base.menuItems.find(item => item.toStateName === name);
  const dashboard = (toState, toStateName, label) => ({
    icon: 'arrow-trending-lines',
    label,
    featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
    toState: frontendURL(`accounts/${accountId}/${toState}`),
    toStateName,
  });
  return {
    ...base,
    menuItems: [
      byName('business_summary_reports'),
      dashboard(
        `tickets/${COMMERCIAL}/metrics`,
        CLASS_VIEW_ROUTES.metrics,
        'SALES_DASHBOARD'
      ),
      dashboard(
        `tickets/${serviceClass(route, accountId)}/metrics`,
        CLASS_VIEW_ROUTES.metrics,
        'SERVICE_DASHBOARD'
      ),
      {
        ...dashboard(
          'tracking-dashboard/metrics',
          'contact_trackings_metrics',
          'CAMPAIGNS_DASHBOARD_REPORT'
        ),
        featureFlag: FEATURE_FLAGS.CAMPAIGNS,
      },
      {
        icon: 'chat',
        label: 'REPORTS_GROUP_CONVERSATIONS',
        hasSubMenu: true,
        collapsible: true,
        toState: 'reports_group_conversations',
        toStateName: 'account_overview_reports',
        children: REPORTS_GROUP.filter(([name]) => byName(name)).map(
          ([name, label]) => {
            const item = byName(name);
            return {
              id: `report-${name}`,
              label,
              icon: item.icon,
              translate: true,
              featureFlag: item.featureFlag,
              toState: item.toState,
              toStateName: name,
            };
          }
        ),
      },
    ].filter(Boolean),
  };
};

// Una sola opción de Tareas (Mi día | Mías | No asignadas | Todas van adentro) que
// abre en Mi día; el calendario; y la prioridad de Mi día (solo administrador).
// Clientes = lo de Contactos + los contratos (y sus tipos) + los atributos personalizados.
const clientes = accountId => {
  const base = contacts(accountId);
  const url = path => frontendURL(`accounts/${accountId}/${path}`);
  return {
    ...base,
    routes: [
      ...base.routes,
      ...CLIENT_TOOLS,
      'contracts_list',
      'contract_types',
    ],
    menuItems: [
      ...base.menuItems,
      // Plan-Contratos R1 — servicios recurrentes de los clientes
      {
        icon: 'signature',
        label: 'CONTRACTS',
        toState: url('contracts'),
        toStateName: 'contracts_list',
      },
      ...settingsItems(accountId, CLIENT_TOOLS),
      {
        icon: 'document',
        label: 'CONTRACT_TYPES',
        toState: url('contracts/types'),
        toStateName: 'contract_types',
      },
    ],
  };
};

const agenda = accountId => ({
  parentNav: 'agenda',
  routes: ['gestorTickets_tasks', 'google_calendar', ...AGENDA_TOOLS],
  menuItems: [
    {
      icon: 'checkmark-circle',
      label: 'TASKS_V2',
      featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
      toState: frontendURL(`accounts/${accountId}/tickets/tasks?tab=my_day`),
      toStateName: 'gestorTickets_tasks',
    },
    // Plan-Trabajo-Campo R2 — portal del técnico (abre la pantalla para celular).
    {
      icon: 'location',
      label: 'FIELD_ROUTE',
      featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
      toState: frontendURL(`accounts/${accountId}/campo`),
      toStateName: 'field_route',
    },
    {
      icon: 'calendar',
      label: 'CALENDAR',
      featureFlag: FEATURE_FLAGS.GOOGLE_CALENDAR,
      toState: frontendURL(`accounts/${accountId}/google-calendar`),
      toStateName: 'google_calendar',
    },
    ...caseSettingsChildren(accountId)
      .filter(child => AGENDA_TOOLS.includes(child.toStateName))
      .map(child => ({
        ...child,
        label: 'MY_DAY_PRIORITY',
        featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
      })),
  ],
});

// Los dos menús salen del de Campañas de antes (mismos ítems, íconos y rutas) más
// lo de IA que estaba en Ajustes. Capitán (Captain, el producto externo de
// Chatwoot) ya no tiene acceso desde el menú: nuestros Agentes IA hacen lo mismo.
const campaignItem = (accountId, name, label) => ({
  ...campaigns(accountId).menuItems.find(item => item.toStateName === name),
  label,
});

const agentesIa = accountId => ({
  parentNav: 'agentes',
  routes: [
    'contact_trackings_agents',
    'contact_trackings_agent',
    'contact_trackings_assistant',
    'contact_trackings_dashboard',
    ...AI_TOOLS,
    ...DUPLICATED_SETTINGS,
  ],
  menuItems: [
    campaignItem(accountId, 'contact_trackings_agents', 'AI_AGENT_LIST'),
    campaignItem(accountId, 'contact_trackings_dashboard', 'TRACKINGS'),
    ...settingsItems(accountId, AI_TOOLS),
  ],
});

const campanas = accountId => ({
  parentNav: 'campaigns',
  routes: [
    'contact_trackings_campaigns',
    'contact_trackings_campaign_detail',
    'ongoing_campaigns',
    'one_off',
    'contact_trackings_metrics',
  ],
  menuItems: [
    campaignItem(accountId, 'contact_trackings_campaigns', 'CAMPAIGNS_AI'),
    campaignItem(accountId, 'ongoing_campaigns', 'CAMPAIGNS_WEB'),
    campaignItem(accountId, 'one_off', 'CAMPAIGNS_SMS'),
    campaignItem(accountId, 'contact_trackings_metrics', 'CAMPAIGNS_DASHBOARD'),
  ],
});

// Ajustes = la configuración de antes + la de casos (el mismo grupo colapsable
// que tenía el menú de Casos) + los embudos de contactos.
const ajustes = accountId => {
  const base = settings(accountId);
  const caseGroup = caseSettingsGroup(accountId);
  return {
    ...base,
    routes: [
      ...base.routes.filter(name => !MOVED_SETTINGS_ROUTES.includes(name)),
      ...CASE_SETTINGS_ROUTES.filter(
        name => !MOVED_CASE_SETTINGS.includes(name)
      ),
      'kanban_types_list',
    ],
    menuItems: [
      ...base.menuItems.filter(
        item => !MOVED_SETTINGS.includes(item.toStateName)
      ),
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
              children: caseGroup.children.filter(
                child => !MOVED_CASE_SETTINGS.includes(child.toStateName)
              ),
              label: 'CASES_AND_STAGES',
              featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
            },
          ]
        : []),
    ],
  };
};

// El orden importa: gana el primer menú cuya ruta coincide (los de `matches`
// van antes que los de lista de rutas).
export const getSidebarItemsV2 = (accountId, route) => ({
  primaryMenu: primaryMenuV2(accountId, route),
  secondaryMenu: [
    ventas(accountId),
    servicio(accountId, route),
    centroDeAyuda(),
    inicio(accountId),
    conversationsV2(accountId),
    clientes(accountId),
    informes(accountId, route),
    agentesIa(accountId),
    campanas(accountId),
    agenda(accountId),
    ajustes(accountId),
  ],
});
