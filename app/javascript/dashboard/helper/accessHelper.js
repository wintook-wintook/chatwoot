// Plan-Roles-Permisos P2 — lo que el rol del usuario deja ver en pantalla. El
// candado de verdad está en el servidor (Access::Grant); esto solo esconde lo
// que de todos modos contestaría «sin permiso».
//
// El perfil trae, por cuenta: { role, areas: { sales: 'own', … }, actions: { … } }.
// Niveles: none (no entra) · own (solo lo suyo) · view (ve todo, no cambia) · all.
import { getCurrentAccount } from './permissionsHelper';

// Entrada del menú principal (key) → área del rol. Inicio no tiene área: siempre se ve.
export const PRIMARY_AREAS = {
  conversations: 'conversations',
  agenda: 'agenda',
  ventas: 'sales',
  servicio: 'service',
  contacts: 'clients',
  campaigns: 'campaigns',
  agentes: 'ai_agents',
  reports: 'reports',
  settings: 'settings',
};

// Sin datos de rol (perfil viejo en caché, bot…): no se esconde nada.
const FULL_ACCESS = { role: 'administrator', areas: {}, actions: {} };

export const getUserAccess = (user, accountId) => {
  const account =
    (user && user.accounts && getCurrentAccount(user, accountId)) || {};
  return account.access || FULL_ACCESS;
};

export const areaLevel = (access, area) => {
  if (!area || access.role === 'administrator') return 'all';
  return access.areas[area] || 'all';
};

export const canSeeArea = (access, area) => areaLevel(access, area) !== 'none';

export const seesOnlyOwn = (access, area) => areaLevel(access, area) === 'own';

export const canDo = (access, action) =>
  access.role === 'administrator' || access.actions[action] !== false;

// Pestañas de «de quién» (Mías / No asignadas / Todas) que el rol deja ver en un
// área: con «solo lo suyo» no hay «Todas», y «No asignadas» solo si puede tomarlas.
export const allowedAssigneeTabs = (access, area, tabs) => {
  if (!seesOnlyOwn(access, area)) return tabs;
  return tabs.filter(tab => {
    if (tab === 'all') return false;
    if (tab === 'unassigned') return canDo(access, 'take_unassigned');
    return true;
  });
};

// Área de una ruta según el menú v2: el menú secundario que la contiene y la
// entrada principal de la que cuelga. null = la ruta no es de ningún área.
export const areaForRoute = (route, secondaryMenu) => {
  const menu = secondaryMenu.find(item =>
    item.matches ? item.matches(route) : item.routes.includes(route.name)
  );
  return (menu && PRIMARY_AREAS[menu.parentNav]) || null;
};
