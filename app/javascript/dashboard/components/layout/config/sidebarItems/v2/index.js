// Menú v2 — reacomodo por lo que hace la gente (Inicio, Conversaciones, Ventas,
// Servicio, Agenda, Clientes, Agentes IA, Informes, Catálogos, Ajustes). Ver
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
  'gestorTickets_close_reasons',
  'gestorTickets_task_settings',
  'gestorTickets_config',
  'gestorTickets_business_summary_access',
];

// Catálogos: las listas que se dan de alta una vez y se usan en todo el sistema
// para clasificar o llenar datos. Salen de Ajustes y de las áreas (las mismas
// pantallas y direcciones; solo cambia el menú).
const CATALOG_SETTINGS = [
  'labels_list',
  'attributes_list',
  'canned_list',
  'whatsapp_templates_index',
];
const CATALOG_SETTINGS_ROUTES = [
  ...CATALOG_SETTINGS,
  'whatsapp_templates_wrapper',
];
// De Ajustes › Casos y etapas: los motivos de cierre (de Ventas) y los de Servicio.
const CLOSE_REASONS = 'gestorTickets_close_reasons';
const SERVICE_CATALOGS = [
  'gestorTickets_types',
  'gestorTickets_classification',
  'gestorTickets_sla',
];
const CATALOG_CASE_SETTINGS = [CLOSE_REASONS, ...SERVICE_CATALOGS];
// Plan-Catalogo-Cotizaciones — pantallas propias de Ventas.
const SALES_ROUTES = [
  'gestorTickets_quotes',
  'gestorTickets_quote_new',
  'gestorTickets_quote',
];
// Lo que define qué sabe y qué hace la IA, y las acciones que corren sin
// escribirlas a mano (automatizaciones y macros): pasa de Ajustes a Agentes IA.
const AI_TOOLS = [
  'knowledge_sources_list',
  'chatgpt_list',
  'website_sketch_list',
  'automation_list',
  'macros_wrapper',
];
const AI_TOOL_ROUTES = [...AI_TOOLS, 'macros_new', 'macros_edit'];
// En Ajustes «Agentes IA» (plantillas) solo redirigía a la lista de Agentes IA.
const DUPLICATED_SETTINGS = ['tracking_templates_list'];
// Todo lo que sale de Ajustes (opciones y rutas).
const MOVED_SETTINGS = [
  ...CATALOG_SETTINGS,
  ...AI_TOOLS,
  ...DUPLICATED_SETTINGS,
];
const MOVED_SETTINGS_ROUTES = [
  ...CATALOG_SETTINGS_ROUTES,
  ...AI_TOOL_ROUTES,
  ...DUPLICATED_SETTINGS,
];

// Lo que soporte ajusta mientras opera: pasa de Ajustes › Casos y etapas a Servicio.
const SERVICE_TOOLS = ['gestorTickets_portals'];
// Lo que sale de Ajustes › Casos y etapas hacia las áreas y Catálogos.
const MOVED_CASE_SETTINGS = [...SERVICE_TOOLS, ...CATALOG_CASE_SETTINGS];
// El puntaje de tareas («Mi día») es una regla, no una lista: se queda en
// Ajustes, como opción propia (ordena tareas, no es configuración de casos).
const TASK_SCORING = 'gestorTickets_task_settings';
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

// Las de Casos y etapas, con sus íconos (sus rutas ya son de administrador).
const caseSettingsItems = (accountId, names, labels = {}) =>
  caseSettingsChildren(accountId)
    .filter(child => names.includes(child.toStateName))
    .map(child => ({
      ...child,
      label: labels[child.toStateName] || child.label,
      featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
    }));

// Catálogos, agrupados por uso: generales, de Ventas, de Servicio y de Clientes.
// Cada quien ve solo los que su permiso deja abrir (Secondary filtra por ruta).
const catalogItems = accountId => {
  const url = path => frontendURL(`accounts/${accountId}/${path}`);
  return [
    ...settingsItems(accountId, CATALOG_SETTINGS),
    {
      icon: 'book',
      label: 'CATALOG_PRODUCTS',
      featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
      toState: url('tickets/catalog'),
      toStateName: 'gestorTickets_catalog',
    },
    ...caseSettingsItems(accountId, [CLOSE_REASONS]),
    {
      icon: 'kanban',
      label: 'CONTACT_FUNNELS',
      toState: url('settings/kanban'),
      toStateName: 'kanban_types_list',
      meta: { permissions: ['administrator'] },
    },
    ...caseSettingsItems(accountId, SERVICE_CATALOGS, {
      gestorTickets_classification: 'CATALOG_CLASSIFICATIONS',
      gestorTickets_sla: 'CATALOG_SLA_POLICIES',
    }),
    {
      icon: 'document',
      label: 'CONTRACT_TYPES',
      toState: url('contracts/types'),
      toStateName: 'contract_types',
    },
  ];
};

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
  const serviceView = lastCaseView(
    accountId,
    serviceClass(route, accountId),
    'list'
  );
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
      // A la vista de su clase, no a `tickets`: el menú principal marca activo por
      // prefijo de la dirección y `tickets` también es prefijo de las de Ventas.
      // La vista es la última usada (Lista, Tablero o Dashboard), como en el submenú.
      toState: url(`tickets/${serviceClass(route, accountId)}/${serviceView}`),
      toStateName: CLASS_VIEW_ROUTES[serviceView],
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
    // Abre el primer catálogo que la persona puede ver (Sidebar#resolveAlternative
    // revisa función y permiso); sin ninguno, no sale.
    (() => {
      const [first, ...rest] = catalogItems(accountId);
      const target = ({ featureFlag, toState, toStateName }) => ({
        featureFlag,
        toState,
        toStateName,
      });
      return {
        icon: 'folder',
        key: 'catalogos',
        label: 'CATALOGS',
        ...target(first),
        alternatives: rest.map(target),
      };
    })(),
    {
      icon: 'settings',
      key: 'settings',
      label: 'SETTINGS_V2',
      toState: url('settings'),
      toStateName: 'settings_home',
    },
  ];
};

// Las notificaciones van aquí (antes, la campanita de la barra principal): con
// los avisos sin leer al lado, que también salen en el ícono de Inicio.
const inicio = accountId => ({
  parentNav: 'inicio',
  routes: [
    'my_summary',
    'notifications_index',
    'gestorTickets_business_summary',
  ],
  menuItems: [
    {
      icon: 'alert',
      label: 'NOTIFICATIONS',
      toState: frontendURL(`accounts/${accountId}/notifications`),
      toStateName: 'notifications_index',
      showUnreadNotifications: true,
    },
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
    routes: [...KANBAN_ROUTES, ...SALES_ROUTES],
    matches: route =>
      KANBAN_ROUTES.includes(routeName(route)) ||
      SALES_ROUTES.includes(routeName(route)) ||
      caseClassOf(route, accountId) === COMMERCIAL,
    // Las oportunidades (Lista | Tablero | Dashboard adentro), los prospectos (qué
    // embudo ver se elige DENTRO del tablero; crearlos y configurarlos, en
    // Catálogos › Embudos de contactos) y las cotizaciones.
    menuItems: [
      casesItem(accountId, COMMERCIAL, 'OPPORTUNITIES', 'board'),
      {
        icon: 'kanban',
        label: 'CONTACT_FUNNEL',
        toState: frontendURL(`accounts/${accountId}/kanban`),
        toStateName: 'kanban_dashboard',
      },
      {
        icon: 'document',
        label: 'QUOTES',
        featureFlag: FEATURE_FLAGS.CASE_MANAGEMENT,
        toState: frontendURL(`accounts/${accountId}/tickets/quotes`),
        toStateName: 'gestorTickets_quotes',
        activeRoutes: ['gestorTickets_quote_new', 'gestorTickets_quote'],
      },
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
      ...caseSettingsItems(accountId, SERVICE_TOOLS),
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
    routes: [...base.routes, 'organizations_dashboard'],
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
      // Plan-Organizaciones O5 — prospectos y clientes.
      {
        ...dashboard(
          'organizations-dashboard',
          'organizations_dashboard',
          'CLIENTS_DASHBOARD'
        ),
        featureFlag: undefined,
      },
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

// Clientes = lo de Contactos + las organizaciones (prospectos y clientes) + los
// contratos (sus tipos y los atributos personalizados están en Catálogos).
const clientes = accountId => {
  const base = contacts(accountId);
  return {
    ...base,
    routes: [
      ...base.routes,
      'organizations_list',
      'organization_detail',
      'contracts_list',
    ],
    menuItems: [
      ...base.menuItems,
      // Plan-Organizaciones O1 — prospectos y clientes con sus contactos
      {
        icon: 'building-bank',
        label: 'ORGANIZATIONS',
        toState: frontendURL(`accounts/${accountId}/organizations`),
        toStateName: 'organizations_list',
        activeRoutes: ['organization_detail'],
      },
      // Plan-Contratos R1 — servicios recurrentes de los clientes
      {
        icon: 'signature',
        label: 'CONTRACTS',
        toState: frontendURL(`accounts/${accountId}/contracts`),
        toStateName: 'contracts_list',
      },
    ],
  };
};

const catalogos = accountId => ({
  parentNav: 'catalogos',
  routes: [
    ...CATALOG_SETTINGS_ROUTES,
    ...CATALOG_CASE_SETTINGS,
    'gestorTickets_type_detail',
    'gestorTickets_catalog',
    'kanban_types_list',
    'contract_types',
  ],
  menuItems: catalogItems(accountId),
});

// Una sola opción de Tareas (Mi día | Mías | No asignadas | Todas van adentro) que
// abre en Mi día; la ruta de campo; y el calendario.
const agenda = accountId => ({
  parentNav: 'agenda',
  routes: ['gestorTickets_tasks', 'google_calendar'],
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
    ...AI_TOOL_ROUTES,
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

// Ajustes = la configuración de antes + el puntaje de tareas de «Mi día» + la de
// casos (el mismo grupo colapsable que tenía el menú de Casos).
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
    ],
    menuItems: [
      ...base.menuItems.filter(
        item => !MOVED_SETTINGS.includes(item.toStateName)
      ),
      ...caseSettingsItems(accountId, [TASK_SCORING], {
        [TASK_SCORING]: 'TASK_SCORING',
      }),
      ...(caseGroup
        ? [
            {
              ...caseGroup,
              children: caseGroup.children.filter(
                child =>
                  !MOVED_CASE_SETTINGS.includes(child.toStateName) &&
                  child.toStateName !== TASK_SCORING
              ),
              // Tipos de caso (su ruta de antes) pasó a Catálogos; Reglas también
              // es de administrador y mantiene el grupo gateado.
              toStateName: 'gestorTickets_rules',
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
    catalogos(accountId),
    ajustes(accountId),
  ],
});
