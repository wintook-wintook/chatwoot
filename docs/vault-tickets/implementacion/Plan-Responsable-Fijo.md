# Plan — Responsable fijo del contacto

> Estado: ✅ **F1 + F2 hechas** (2026-10-24, rama `feat/nva_oportunidad`, sin commit). F3 opcional pendiente.

## Qué es
En la ficha del contacto se elige un **Responsable fijo**. Sus conversaciones van siempre con esa
persona, sin importar la asignación por turnos, las automatizaciones, las reglas de casos ni los
Agentes IA. Sus casos nuevos (sin responsable elegido a mano) también son suyos.

## Decisiones del usuario
1. A mano **sí** se puede cambiar en una conversación (solo esa; al reabrir vuelve al responsable
   fijo). Requiere «Asignar a otra persona» (lo revisa `AssignmentsController`).
2. También aplica a **casos y oportunidades nuevos** del contacto.
3. El responsable fijo lo pone **quien tiene «Asignar a otra persona»** (Administrador, Supervisor).

## Cómo está hecho
- `contacts.owner_id` (migración `20261029110000_add_owner_to_contacts`, FK a users con nullify);
  `Contact#owner`, valida que sea usuario de la cuenta.
- `ContactOwnerAssignment` (concern en `Conversation`, después de `AssignmentHandler`):
  - al abrir (nueva abierta o reabierta) asigna al responsable fijo;
  - si algo automático cambia el responsable de una abierta, lo regresa;
  - `manual_assignment` (lo marcan `Conversations::AssignmentsController` y `BulkActionsJob`) deja
    cambiarlo a mano;
  - solo en bandejas donde el responsable es miembro; en pendiente (bot) espera a que pase a abierta;
  - deja nota en la conversación (`conversations.activity.assignee.contact_owner` / `_kept`).
- Casos: `CaseTicket#assign_contact_owner` (al crear, si no hay responsable) y
  `Cases::RuleEngineService` no corre `assign_agent` si el contacto tiene responsable fijo.
- `Agents::DestroyJob` limpia `owner_id` si el usuario sale de la cuenta.
- Roles: con Clientes en «solo lo suyo», los contactos de los que es responsable fijo cuentan como suyos.
- API: `GET/PATCH /contacts/:id/owner` (`Contacts::OwnersController`): owner, `can_edit`,
  `missing_inboxes` (bandejas del contacto donde el responsable no está).
- Ficha: `conversation/contact/ContactOwnerField.vue` dentro de `ContactInfo.vue` (sale en la
  conversación y en la página del contacto).

## Pruebas
`spec/models/contact_owner_assignment_spec.rb` (11) y `spec/requests/api/v1/accounts/contact_owner_spec.rb`
(4). Probado en el navegador (poner responsable y aviso de bandeja).

## Pendiente (F3, opcional)
- Poner el responsable fijo a varios contactos a la vez desde la lista.
- Columna «Responsable fijo» al importar contactos.
