// @tickets_cases
import { frontendURL } from '../../../../helper/URLHelper';

const gestorTickets = accountId => ({
  parentNav: 'gestorTickets',
  routes: [
    'gestorTickets_index',
    'gestorTickets_kanban',
    'gestorTickets_detail',
    'gestorTickets_rules',
    'gestorTickets_metrics',
    'gestorTickets_types',
    'gestorTickets_classification',
    'gestorTickets_sla',
    'gestorTickets_config',
  ],
  menuItems: [
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
      toState: frontendURL(`accounts/${accountId}/tickets/kanban`),
      toStateName: 'gestorTickets_kanban',
    },
    {
      icon: 'document',
      label: 'TICKET_METRICS',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/tickets/metrics`),
      toStateName: 'gestorTickets_metrics',
    },
    {
      icon: 'tag',
      label: 'TICKET_TYPES',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/tickets/types`),
      toStateName: 'gestorTickets_types',
    },
    {
      icon: 'settings',
      label: 'TICKET_RULES',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/tickets/rules`),
      toStateName: 'gestorTickets_rules',
    },
    {
      icon: 'folder',
      label: 'TICKET_CLASSIFICATION',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/tickets/classification`),
      toStateName: 'gestorTickets_classification',
    },
    {
      icon: 'clock',
      label: 'TICKET_SLA',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/tickets/sla`),
      toStateName: 'gestorTickets_sla',
    },
    {
      icon: 'number-symbol',
      label: 'TICKET_CONFIG',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/tickets/config`),
      toStateName: 'gestorTickets_config',
    },
  ],
});

export default gestorTickets;
