// @query_databases — sección "Cobranza / ERP" en la barra lateral
import { frontendURL } from '../../../../helper/URLHelper';

const erp = accountId => ({
  parentNav: 'erp',
  routes: ['erp_connections', 'erp_console'],
  menuItems: [
    {
      icon: 'search',
      label: 'ERP_CONSOLE',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/erp/console`),
      toStateName: 'erp_console',
    },
    {
      icon: 'link',
      label: 'ERP_CONNECTIONS',
      hasSubMenu: false,
      toState: frontendURL(`accounts/${accountId}/erp/connections`),
      toStateName: 'erp_connections',
    },
  ],
});

export default erp;
