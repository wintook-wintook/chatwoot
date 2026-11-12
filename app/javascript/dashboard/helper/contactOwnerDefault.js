// Responsable fijo que aplica a un contacto: el suyo o, si no tiene, el de su
// organización (Contact#effective_owner_id). Los formularios de caso nuevo lo
// proponen como responsable en vez de quien crea el caso.
import ContactOwnerAPI from 'dashboard/api/contactOwner';

export const fetchEffectiveOwnerId = async contactId => {
  if (!contactId) return null;
  try {
    const { data } = await ContactOwnerAPI.show(contactId);
    const owner = data.owner || data.inherited;
    return owner ? owner.id : null;
  } catch {
    return null;
  }
};

export default fetchEffectiveOwnerId;
