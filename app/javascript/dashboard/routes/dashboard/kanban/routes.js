// ARCHIVO: app/javascript/dashboard/routes/dashboard/kanban/routes.js
// ACCIÓN: MODIFICAR ARCHIVO EXISTENTE - AGREGAR NUEVAS RUTAS
// KANBAN0725

import { frontendURL } from '../../../helper/URLHelper';

// Exportar directamente el array de rutas
export const routes = [
  {
    path: frontendURL('accounts/:accountId/kanban'),
    name: 'kanban_dashboard',
    meta: {
      permissions: ['administrator', 'agent'],
    },
    component: () => import('../../../views/kanbanBoard.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/kanban/label/:label'),
    name: 'label_kanban',
    meta: {
      permissions: ['administrator', 'agent'],
    },
    component: () => import('../../../views/kanbanBoard.vue'),
    props: route => ({
      label: route.params.label
    }),
  },
  {
    path: frontendURL('accounts/:accountId/kanban/label/:label/board'),
    name: 'kanban_through_label',
    meta: {
      permissions: ['administrator', 'agent'],
    },
    component: () => import('../../../views/kanbanBoard.vue'),
    props: route => ({
      label: route.params.label
    }),
  },
  // NUEVAS RUTAS PARA FILTRO POR ESTADO:
  {
    path: frontendURL('accounts/:accountId/kanban/status/:status'),
    name: 'kanban_status',
    meta: {
      permissions: ['administrator', 'agent'],
    },
    component: () => import('../../../views/kanbanBoard.vue'),
    props: route => ({
      statusFilter: route.params.status
    }),
  },
  {
    path: frontendURL('accounts/:accountId/kanban/status/:status/board'),
    name: 'kanban_through_status',
    meta: {
      permissions: ['administrator', 'agent'],
    },
    component: () => import('../../../views/kanbanBoard.vue'),
    props: route => ({
      statusFilter: route.params.status
    }),
  },
  // 🆕 AGREGAR ESTA RUTA AQUÍ:
  {
    path: frontendURL('accounts/:accountId/kanban/processes'),
    name: 'kanban_processes',
    meta: {
      permissions: ['administrator'],
    },
    component: () => import('../../../views/kanbanBoard.vue'),
  },
  {
    path: frontendURL('accounts/:accountId/kanban/type/:typeId'),
    //name: 'kanban_type_view',
    name: 'kanban_type',
    meta: {
      permissions: ['administrator', 'agent'],
      parentNav: 'kanban'  // ← IMPORTANTE: Agregado para que funcione el sidebar
    },
    component: () => import('../../../views/kanbanBoard.vue'), // ← CORREGIDO: Ruta real
    props: route => ({
      typeId: parseInt(route.params.typeId),
      label: route.query.label,
      statusFilter: route.query.status,
    }),
  },

];

// También mantener la exportación por defecto para compatibilidad
const KanbanRoutes = {
  routes,
};

export default KanbanRoutes;