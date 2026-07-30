// @tickets_cases
import { frontendURL } from '../../../../helper/URLHelper';

// Menú secundario del módulo de tickets. Se separa la OPERACIÓN (trabajo diario,
// plano arriba) de la CONFIGURACIÓN (agrupada en secciones colapsables). Los
// grupos usan `children`; para que el filtro de permisos no los descarte, el
// padre lleva un `toStateName` de una ruta admin (así el grupo queda gateado a
// administrador, que es donde vive la configuración).
const gestorTickets = accountId => {
  const url = path => frontendURL(`accounts/${accountId}/tickets/${path}`);

  return {
    parentNav: 'gestorTickets',
    routes: [
      'gestorTickets_index',
      'gestorTickets_kanban',
      'gestorTickets_tasks',
      'gestorTickets_detail',
      'gestorTickets_rules',
      'gestorTickets_metrics',
      'gestorTickets_types',
      'gestorTickets_classification',
      'gestorTickets_sla',
      'gestorTickets_ai',
      'gestorTickets_portals',
      'gestorTickets_settings',
      'gestorTickets_config',
    ],
    menuItems: [
      // ── Operación (trabajo diario) ──
      {
        icon: 'list',
        label: 'ALL_TICKETS',
        hasSubMenu: false,
        toState: frontendURL(`accounts/${accountId}/tickets`),
        toStateName: 'gestorTickets_index',
      },
      {
        icon: 'table-switch',
        label: 'TICKET_KANBAN',
        hasSubMenu: false,
        toState: url('kanban'),
        toStateName: 'gestorTickets_kanban',
      },
      {
        icon: 'checkmark-circle',
        label: 'TICKET_TASKS',
        hasSubMenu: false,
        toState: url('tasks'),
        toStateName: 'gestorTickets_tasks',
      },
      {
        icon: 'document',
        label: 'TICKET_METRICS',
        hasSubMenu: false,
        toState: url('metrics'),
        toStateName: 'gestorTickets_metrics',
      },
      // ── Definiciones (lo que modela el caso) ──
      {
        icon: 'folder',
        label: 'TICKET_GROUP_DEFINITIONS',
        hasSubMenu: true,
        toState: 'gestorTickets_group_definitions',
        toStateName: 'gestorTickets_types',
        children: [
          {
            id: 'ticket-types',
            label: 'TICKET_TYPES',
            translate: true,
            toState: url('types'),
            toStateName: 'gestorTickets_types',
          },
          {
            id: 'ticket-classification',
            label: 'TICKET_CLASSIFICATION',
            translate: true,
            toState: url('classification'),
            toStateName: 'gestorTickets_classification',
          },
          {
            id: 'ticket-sla',
            label: 'TICKET_SLA',
            translate: true,
            toState: url('sla'),
            toStateName: 'gestorTickets_sla',
          },
          {
            id: 'ticket-portals',
            label: 'TICKET_PORTALS',
            translate: true,
            toState: url('portals'),
            toStateName: 'gestorTickets_portals',
          },
        ],
      },
      // ── Automatización e IA ──
      {
        icon: 'wand',
        label: 'TICKET_GROUP_AUTOMATION',
        hasSubMenu: true,
        toState: 'gestorTickets_group_automation',
        toStateName: 'gestorTickets_rules',
        children: [
          {
            id: 'ticket-rules',
            label: 'TICKET_RULES',
            translate: true,
            toState: url('rules'),
            toStateName: 'gestorTickets_rules',
          },
          {
            id: 'ticket-ai',
            label: 'TICKET_AI',
            translate: true,
            toState: url('ai'),
            toStateName: 'gestorTickets_ai',
          },
        ],
      },
      // ── Ajustes del módulo ──
      {
        icon: 'settings',
        label: 'TICKET_GROUP_SETTINGS',
        hasSubMenu: true,
        toState: 'gestorTickets_group_settings',
        toStateName: 'gestorTickets_settings',
        children: [
          {
            id: 'ticket-settings',
            label: 'TICKET_SETTINGS',
            translate: true,
            toState: url('settings'),
            toStateName: 'gestorTickets_settings',
          },
          {
            id: 'ticket-config',
            label: 'TICKET_CONFIG',
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
