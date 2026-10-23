import conversations from './sidebarItems/conversations';
import contacts from './sidebarItems/contacts';
import reports from './sidebarItems/reports';
import campaigns from './sidebarItems/campaigns';
import settings from './sidebarItems/settings';
import notifications from './sidebarItems/notifications';
import primaryMenu from './sidebarItems/primaryMenu';
// KANBAN0725
import kanban from './sidebarItems/kanban'; // Añade esta línea
// KANBAN0725
import gestorTickets from './sidebarItems/gestorTickets'; // @tickets_cases

import { getSidebarItemsV2 } from './sidebarItems/v2';
import { MENU_V2 } from './menuVersion';

export { MENU_V2 };

const getSidebarItemsV1 = accountId => ({
  primaryMenu: primaryMenu(accountId),
  secondaryMenu: [
    conversations(accountId),
    contacts(accountId),
    reports(accountId),
    campaigns(accountId),
    settings(accountId),
    notifications(accountId),
    // KANBAN0725
    kanban(accountId),
    // KANBAN0725
    gestorTickets(accountId), // @tickets_cases
  ],
});

export const getSidebarItems = (accountId, route) =>
  MENU_V2 ? getSidebarItemsV2(accountId, route) : getSidebarItemsV1(accountId);
