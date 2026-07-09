---
titulo: Borrado y cascadas — Contact Tracking
tipo: implementacion
tags: [contact-tracking, borrado, cascada, foreign-keys, tickets]
---

# Borrado y cascadas

Qué pasa con **trackings** y **tickets** (`case_tickets`) al borrar un contacto, una
conversación o un tracking. Verificado en BD (cuenta 2) el 2026-06-12.

## Asociaciones / FKs relevantes

- `Contact has_many :contact_trackings, dependent: :destroy` (app-level).
- `Inbox has_many :contact_trackings, dependent: :destroy`.
- **`Conversation` NO declara** `has_many :contact_trackings` ni `:case_tickets`.
- **`Contact` / `Conversation` / `ContactTracking` NO declaran** `has_many :case_tickets`.
- FKs en BD de `contact_trackings`: `contact_id`, `conversation_id`, `inbox_id` →
  todas **ON DELETE NO ACTION**.
- `case_tickets`: **sin FK** a `contact_id` / `conversation_id` / `contact_tracking_id`
  (la única FK es `requester_id -> users`). Los `belongs_to` son `optional: true`.

## 🗑️ Borrar el CONTACTO

| Referencia | Resultado | Motivo |
|---|---|---|
| ContactTrackings | ✅ **se borran** (cascada) | `dependent: :destroy` |
| Conversaciones | se borran async | `dependent: :destroy_async` (trackings se borran sync antes → sin conflicto FK) |
| Tickets (`case_tickets`) | ⚠️ **quedan huérfanos** | Contact no declara `has_many :case_tickets` ni hay FK; `contact_id` queda colgando |

## 🗑️ Borrar la CONVERSACIÓN

| Referencia | Resultado | Motivo |
|---|---|---|
| ContactTracking | ❌ **BLOQUEA el borrado** (`PG::ForeignKeyViolation`) | FK `conversation_id` NO ACTION + Conversation sin asociación |
| Tickets | ⚠️ **quedan huérfanos** (no se borran, no bloquean) | sin FK ni `dependent` |

> **Confirmado:** no se puede borrar la conversación #20 porque el tracking #21 la
> referencia. Para borrarla hay que primero borrar (o nulificar `conversation_id` de)
> el tracking.

## 🗑️ Borrar un TRACKING

- `case_tickets.contact_tracking_id` quedaría huérfano (sin FK ni `dependent`).

## ⚠️ Problemas detectados (ver [[Pendiente]])

1. **Conversación con tracking no se puede borrar** — el borrado falla con FK violation.
   Falta `dependent: :nullify`/`:destroy` en `Conversation → contact_trackings`, o
   FK `on_delete: :nullify`.
2. **Tickets huérfanos** — al borrar contacto/conversación/tracking, los `case_tickets`
   conservan IDs colgando; `ticket.contact.name` puede dar nil/errores. Falta definir
   política (`dependent: :nullify` vs conservar con histórico).
