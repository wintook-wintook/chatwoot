import VueRouter from 'vue-router';

import { frontendURL } from '../helper/URLHelper';
import dashboard from './dashboard/dashboard.routes';
import store from '../store';
import { validateLoggedInRoutes } from '../helper/routeHelpers';
import AnalyticsHelper from '../helper/AnalyticsHelper';
import { buildPermissionsFromRouter } from '../helper/permissionsHelper';

const routes = [...dashboard.routes];

export const router = new VueRouter({ mode: 'history', routes });
export const routesWithPermissions = buildPermissionsFromRouter(routes);

// @tickets_cases — al ENTRAR a la app (iniciar sesión o abrirla, no al navegar
// dentro), cada usuario aterriza donde eligió en su perfil: «Inicio» (Mi resumen,
// por defecto), Conversaciones o Mi día. Hacer clic en Conversaciones sigue
// llevando a Conversaciones: solo cuenta la primera navegación.
const LANDING_PAGES = {
  summary: { name: 'my_summary' },
  my_day: { name: 'gestorTickets_tasks', query: { tab: 'my_day' } },
  conversations: null,
};

export const landingRoute = (to, from, user) => {
  if (to.name !== 'home' || (from && from.name)) return null;
  const choice =
    (user && user.ui_settings && user.ui_settings.landing_page) || 'summary';
  const page =
    LANDING_PAGES[choice] === undefined
      ? LANDING_PAGES.summary
      : LANDING_PAGES[choice];
  if (!page) return null;
  return { ...page, params: { accountId: to.params.accountId } };
};

export const validateAuthenticateRoutePermission = (
  to,
  next,
  { getters },
  from = null
) => {
  const { isLoggedIn, getCurrentUser: user } = getters;

  if (!isLoggedIn) {
    window.location = '/app/login';
    return '/app/login';
  }

  if (!to.name) {
    return next(frontendURL(`accounts/${user.account_id}/dashboard`));
  }

  const landing = landingRoute(to, from, user);
  if (landing) return next(landing);

  const nextRoute = validateLoggedInRoutes(to, getters.getCurrentUser);
  return nextRoute ? next(frontendURL(nextRoute)) : next();
};

export const initalizeRouter = () => {
  const userAuthentication = store.dispatch('setUser');

  router.beforeEach((to, from, next) => {
    AnalyticsHelper.page(to.name || '', {
      path: to.path,
      name: to.name,
    });

    userAuthentication.then(() => {
      return validateAuthenticateRoutePermission(to, next, store, from);
    });
  });
};

export default router;
