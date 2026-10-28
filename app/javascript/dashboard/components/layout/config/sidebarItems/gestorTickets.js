// @tickets_cases
import { frontendURL } from '../../../../helper/URLHelper';

// Menú secundario de «Casos». Plan-Casos E1 (F6): la OPERACIÓN es plana y neutra
// a la clase — Lista, Tablero y Métricas apuntan a rutas que redirigen a la
// última clase usada, y la clase (Comercial | Soporte) se elige con el selector
// del encabezado de cada vista. Así el menú no crece con cada clase nueva.
// Se marcan activos por `toStateName` (el nombre de la ruta por clase).
// La CONFIGURACIÓN va en un solo grupo colapsable; el padre lleva un
// `toStateName` de ruta admin para que el grupo quede gateado a administrador.
const gestorTickets = accountId => {
  const url = path => frontendURL(`accounts/${accountId}/tickets/${path}`);

  return {
    parentNav: 'gestorTickets',
    routes: [
      'gestorTickets_index',
      'gestorTickets_kanban',
      'gestorTickets_metrics',
      'gestorTickets_class_list',
      'gestorTickets_class_board',
      'gestorTickets_class_metrics',
      'gestorTickets_tasks',
      'gestorTickets_detail',
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
      'gestorTickets_business_summary',
      'gestorTickets_business_summary_access',
    ],
    menuItems: [
      // ── Operación (de la clase elegida en el selector) ──
      {
        icon: 'list',
        label: 'CASES_LIST',
        hasSubMenu: false,
        toState: frontendURL(`accounts/${accountId}/tickets`),
        toStateName: 'gestorTickets_class_list',
      },
      {
        icon: 'table-switch',
        label: 'CASES_BOARD',
        hasSubMenu: false,
        toState: url('kanban'),
        toStateName: 'gestorTickets_class_board',
      },
      // Tareas: de todas las clases (bandeja personal).
      {
        icon: 'checkmark-circle',
        label: 'TICKET_TASKS',
        hasSubMenu: false,
        toState: url('tasks'),
        toStateName: 'gestorTickets_tasks',
      },
      {
        icon: 'document',
        label: 'CASES_METRICS',
        hasSubMenu: false,
        toState: url('metrics'),
        toStateName: 'gestorTickets_class_metrics',
      },
      // «Resumen del negocio» — todas las clases en una pantalla, para el dueño.
      // Solo administradores y los agentes que ellos autoricen (visibleGetter).
      {
        icon: 'briefcase',
        label: 'BUSINESS_SUMMARY',
        hasSubMenu: false,
        toState: url('summary'),
        toStateName: 'gestorTickets_business_summary',
        visibleGetter: 'caseTickets/getCanViewBusinessSummary',
      },
      // ── Configuración (solo administrador) ──
      {
        icon: 'settings',
        label: 'CASES_GROUP_CONFIG',
        hasSubMenu: true,
        collapsible: true,
        toState: 'gestorTickets_group_config',
        toStateName: 'gestorTickets_types',
        children: [
          {
            id: 'ticket-types',
            label: 'TICKET_TYPES',
            icon: 'tag',
            translate: true,
            toState: url('types'),
            toStateName: 'gestorTickets_types',
          },
          {
            id: 'ticket-classification',
            label: 'TICKET_CLASSIFICATION',
            icon: 'list',
            translate: true,
            toState: url('classification'),
            toStateName: 'gestorTickets_classification',
          },
          {
            id: 'ticket-sla',
            label: 'TICKET_SLA',
            icon: 'clock',
            translate: true,
            toState: url('sla'),
            toStateName: 'gestorTickets_sla',
          },
          {
            id: 'ticket-rules',
            label: 'TICKET_RULES',
            icon: 'automation',
            translate: true,
            toState: url('rules'),
            toStateName: 'gestorTickets_rules',
          },
          {
            id: 'ticket-ai',
            label: 'TICKET_AI',
            icon: 'bot',
            translate: true,
            toState: url('ai'),
            toStateName: 'gestorTickets_ai',
          },
          {
            id: 'ticket-portals',
            label: 'TICKET_PORTALS',
            icon: 'globe',
            translate: true,
            toState: url('portals'),
            toStateName: 'gestorTickets_portals',
          },
          {
            id: 'ticket-commercial-settings',
            label: 'TICKET_COMMERCIAL_SETTINGS',
            icon: 'building-bank',
            translate: true,
            toState: url('commercial-settings'),
            toStateName: 'gestorTickets_commercial_settings',
          },
          {
            id: 'ticket-close-reasons',
            label: 'TICKET_CLOSE_REASONS',
            icon: 'list',
            translate: true,
            toState: url('close-reasons'),
            toStateName: 'gestorTickets_close_reasons',
          },
          {
            id: 'ticket-task-settings',
            label: 'TICKET_TASK_SETTINGS',
            icon: 'clipboard',
            translate: true,
            toState: url('task-settings'),
            toStateName: 'gestorTickets_task_settings',
          },
          {
            id: 'ticket-business-summary-access',
            label: 'BUSINESS_SUMMARY_ACCESS',
            icon: 'lock-shield',
            translate: true,
            toState: url('summary-access'),
            toStateName: 'gestorTickets_business_summary_access',
          },
          {
            id: 'ticket-settings',
            label: 'TICKET_SETTINGS',
            icon: 'settings',
            translate: true,
            toState: url('settings'),
            toStateName: 'gestorTickets_settings',
          },
          {
            id: 'ticket-config',
            label: 'TICKET_CONFIG',
            icon: 'number-symbol',
            translate: true,
            toState: url('config'),
            toStateName: 'gestorTickets_config',
          },
        ],
      },
    ],
  };
};

export default gestorTickets;
