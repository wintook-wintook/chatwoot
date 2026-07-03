---
titulo: Vault — Google Calendar
tipo: indice
tags: [google-calendar, integracion, oauth, citas]
---

# Vault — Google Calendar

Bóveda del módulo de **Google Calendar** en Chatwoot: integración OAuth **por agente**,
vista de calendario en Ajustes (semana/mes), disponibilidad entre agentes, alertas de
eventos próximos y creación/edición de eventos. El **bot de Seguimientos** lo consume
para agendar/mover/cancelar citas (esa parte se documenta en `vault-contact-tracking`,
nota [[../vault-contact-tracking/implementacion/Agendar-calendar|Agendar-calendar]]).

Skill asociada: `proyecto@google_calendar`.

## Mapa
- [[00-Indice]] — índice navegable
- [[implementacion/Estado-actual]] — arquitectura, archivos reales y flujo OAuth
- [[implementacion/Gestion-cuentas-y-calendarios]] — cuentas conectadas, calendarios
  secundarios (colores, selección) y agendar en un secundario
- [[implementacion/Pendiente]] — tareas abiertas

## Regla de oro
Cada **agente** conecta **su propia** cuenta Google (una por `user + account`,
`UserCalendarIntegration`). La disponibilidad de la cuenta agrega la de todos los agentes.
Confirmar siempre contra el código antes de asumir que algo falta.
