// Plan-Organizaciones O1 — lo que comparten la lista, la página y los formularios.
import { areaLevel, canDo, getUserAccess } from 'dashboard/helper/accessHelper';

export const STAGES = ['prospect', 'customer'];
export const KINDS = ['company', 'general_public'];

const STAGE_CHIP = {
  prospect:
    'bg-amber-50 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300',
  customer:
    'bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-300',
};

export const stageChipClass = stage => STAGE_CHIP[stage] || STAGE_CHIP.prospect;

// Lo mismo que decide el servidor: área Clientes; se cambian con «Todo» o «Solo lo suyo».
// Eliminar pide además el permiso «Borrar».
export const organizationAccess = (user, accountId) => {
  const access = getUserAccess(user, accountId);
  const canEdit = ['own', 'all'].includes(areaLevel(access, 'clients'));
  return { canEdit, canDelete: canEdit && canDo(access, 'delete') };
};

export const formatDate = value =>
  value
    ? new Date(value).toLocaleDateString(undefined, {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
      })
    : '';
