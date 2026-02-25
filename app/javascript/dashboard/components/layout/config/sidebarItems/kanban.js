
// KANBAN0725
import { FEATURE_FLAGS } from '../../../../featureFlags';
import { frontendURL } from '../../../../helper/URLHelper';

const kanban = accountId => ({
  parentNav: 'kanban',
  routes: [
    'kanban_dashboard',
    'kanban_board',
    'kanban_processes',
    'kanban_label',     // IMPORTANTE: Agregar esta
    'kanban_status',    // IMPORTANTE: Agregar esta  
    'kanban_type',      // IMPORTANTE: Agregar esta
  ],
  menuItems: [
    {
      icon: 'kanban-board',
      label: 'KANBAN_BOARD',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/kanban/board`),
      toStateName: 'kanban_board',
      //featureFlag: FEATURE_FLAGS.KANBAN,
    },
  ],
});

export default kanban;