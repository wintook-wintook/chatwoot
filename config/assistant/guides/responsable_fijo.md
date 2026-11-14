---
key: responsable_fijo
title: Responsable fijo del contacto
areas: [clients]
keywords: [responsable fijo, responsable, dueno, dueno del cliente, ejecutivo de cuenta, vendedor asignado, asignar contacto, siempre le llega, sus conversaciones, casos nuevos, reglas de asignacion, reasignar, responsable de la organizacion, heredar, sin responsable fijo, asignar a otra persona]
pages: [contact, organization, contacts, organizations]
sources:
  - app/javascript/dashboard/routes/dashboard/conversation/contact/ContactOwnerField.vue
  - app/controllers/api/v1/accounts/contacts/owners_controller.rb
  - app/models/concerns/contact_owner_assignment.rb
  - app/javascript/dashboard/views/organizations/OrganizationForm.vue
  - app/services/access/grant.rb
reviewed: 2026-11-14
---
## Para qué sirve
El responsable fijo es la persona que atiende siempre a un contacto. Sus conversaciones y sus casos nuevos le llegan a ella, por encima de la asignación por turnos, las automatizaciones, las reglas de asignación y los Agentes IA.

## Dónde está
- En la ficha del contacto, arriba, en «Responsable fijo» (al pasar el mouse explica: «Sus conversaciones y casos nuevos van siempre con esta persona, sin importar las reglas de asignación.»).
- En la organización, en su campo «Responsable» (al crearla o con «Editar»). También sale en la columna «Responsable» de Clientes › Organizaciones y en los «Datos» de su página.

## Cómo se hace
### Ponerle responsable fijo a un contacto
1. Abre la ficha del contacto (Clientes › Contactos y pulsa su nombre).
2. En «Responsable fijo» elige a la persona. Para quitarlo elige «Sin responsable fijo».
3. Se guarda solo («Responsable fijo actualizado»).
4. Si sale «No está en …», esa persona no es miembro de esas bandejas: ahí siguen las reglas normales. Pide al administrador que la agregue a la bandeja.

### Ponerlo para toda una organización
1. Abre la organización en Clientes › Organizaciones y pulsa «Editar».
2. Elige el «Responsable» (o «Sin responsable») y pulsa «Guardar».
3. Sus contactos que no tienen responsable fijo propio usan este. El propio del contacto gana sobre el de la organización.

## Qué pasa con las conversaciones
- Cuando una conversación del contacto se abre (nueva o reabierta) se le asigna al responsable fijo, y queda una nota: «Asignada a … (responsable fijo del contacto)».
- Si algo automático la cambia de persona, regresa al responsable fijo.
- Si la conversación está pendiente porque la atiende un bot, no se toca; se asigna cuando pasa a abierta.
- Una persona sí puede reasignarla a mano en esa conversación (desde la conversación o en lote). La siguiente vez que se abra vuelve al responsable fijo.

## Qué pasa con los casos
- Un caso nuevo del contacto que se crea sin responsable queda con el responsable fijo, y las reglas de asignación de casos no lo cambian.
- Al crear un caso a mano para el contacto, el campo «Responsable» ya sale con su responsable fijo (el suyo o el de su organización). Si lo cambias, gana lo que elijas.
- Los casos que ya existían no cambian de responsable.

## Dudas frecuentes
- En la ficha dice «Sin responsable fijo» y debajo «Aplica el de su organización …»: el contacto no tiene uno propio y usa el «Responsable» de su organización.
- No puedo cambiarlo, solo veo el nombre: tu rol no tiene «Asignar a otra persona». Si sale «No se pudo cambiar el responsable fijo», intenta de nuevo o revisa tu permiso.
- Al fusionar dos contactos, si el que se queda no tiene responsable fijo, toma el del que se elimina.
- ¿Ver solo lo mío incluye a estos contactos? Sí: con «Solo lo suyo» en Clientes ves los contactos de los que eres responsable fijo y los de las organizaciones a tu cargo.

## Quién puede
Lo ve cualquiera que vea al contacto. Lo cambia quien tiene el permiso «Asignar a otra persona» (por omisión Administrador y Supervisor) y puede cambiar contactos en Clientes; los demás lo ven sin poder cambiarlo. El «Responsable» de una organización lo cambia quien puede editar la organización (Clientes en «Todo» o «Solo lo suyo»).
