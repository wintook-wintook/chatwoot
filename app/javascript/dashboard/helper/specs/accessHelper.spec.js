import {
  allowedAssigneeTabs,
  areaForRoute,
  canDo,
  canSeeArea,
  getUserAccess,
} from '../accessHelper';
import { getSidebarItemsV2 } from 'dashboard/components/layout/config/sidebarItems/v2';

const seller = {
  role: 'seller',
  areas: {
    sales: 'own',
    service: 'none',
    reports: 'none',
    conversations: 'own',
  },
  actions: { take_unassigned: true, reassign: false },
};

describe('accessHelper (Plan-Roles-Permisos)', () => {
  it('sin datos de rol no esconde nada', () => {
    const access = getUserAccess({ accounts: [{ id: 1 }] }, 1);
    expect(canSeeArea(access, 'settings')).toBe(true);
    expect(canDo(access, 'reassign')).toBe(true);
  });

  it('lee el rol de la cuenta del perfil', () => {
    const user = { accounts: [{ id: 1, access: seller }] };
    const access = getUserAccess(user, 1);
    expect(canSeeArea(access, 'sales')).toBe(true);
    expect(canSeeArea(access, 'service')).toBe(false);
    expect(canDo(access, 'reassign')).toBe(false);
  });

  it('con «solo lo suyo» quita «Todas» y deja «No asignadas» si puede tomarlas', () => {
    const tabs = ['mine', 'unassigned', 'all'];
    expect(allowedAssigneeTabs(seller, 'sales', tabs)).toEqual([
      'mine',
      'unassigned',
    ]);
    const noTake = { ...seller, actions: { take_unassigned: false } };
    expect(allowedAssigneeTabs(noTake, 'sales', tabs)).toEqual(['mine']);
    expect(
      allowedAssigneeTabs({ role: 'administrator' }, 'sales', tabs)
    ).toEqual(tabs);
  });

  it('ubica el área de una ruta con el menú v2', () => {
    const { secondaryMenu } = getSidebarItemsV2(1, {
      name: 'contacts_dashboard',
      params: {},
    });
    expect(
      areaForRoute({ name: 'contacts_dashboard', params: {} }, secondaryMenu)
    ).toBe('clients');
    expect(
      areaForRoute(
        {
          name: 'gestorTickets_class_list',
          params: { caseClass: 'commercial' },
        },
        secondaryMenu
      )
    ).toBe('sales');
    expect(
      areaForRoute({ name: 'my_summary', params: {} }, secondaryMenu)
    ).toBe(null);
  });
});
