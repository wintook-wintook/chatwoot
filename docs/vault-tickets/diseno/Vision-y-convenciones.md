---
titulo: Visión y convenciones
tipo: diseño
tags: [tickets, vision, convenciones]
---

## Nombre del Proyecto
**Gestor de Tickets** — Motor de Gestión de Casos Inteligente (MGCI) para Kontrolya/Wintook.

**Convención:** tablas, columnas, enums y código en **inglés** (igual que Chatwoot). Las etiquetas de UI se muestran en español.

---

## Propósito
Módulo nuevo que separa claramente tres conceptos que hoy están mezclados:

| Capa | Responsabilidad | Modelo |
|------|----------------|--------|
| **Comunicación** | Canal con el cliente (WhatsApp, web, email) | `Conversation` (sin cambios) |
| **Ticket** | Problema o necesidad concreta del cliente | `CaseTicket` (nuevo) |
| **Seguimiento** | Acción automática sobre el ticket | `ContactTracking` (extendido) |
| **Eventos** | Historial auditable de todo lo que ocurre | `CaseEvent` (nuevo) |
| **Reglas** | Automatización de asignaciones y escalados | `CaseRule` (nuevo) |

**Regla de oro:** Un cliente puede tener 1 conversación activa · múltiples tickets · múltiples seguimientos por ticket.

---

## Estado actual

- **Nombre oficial del proyecto:** Gestor de Tickets
- **Rama de trabajo:** `feat/tickets` (mergeada con `develop`)
- **Fecha de diseño:** 2026-05-27
- **Fecha de implementación:** 2026-06-04
- **Fase:** ✅ **TODAS LAS 5 FASES IMPLEMENTADAS Y VERIFICADAS EN BROWSER**
- **Dependencia clave:** `ContactTracking` + `RouterService` + `KnowledgeBaseResponseService` ya existen y NO deben modificarse estructuralmente

### Estado por fase

| Fase | Contenido | Estado |
|------|-----------|--------|
| **0** | Migraciones + modelos (`CaseTicket`, `CaseEvent`, `CaseRule`) | ✅ Implementada |
| **1** | Servicios + `CaseSlaMonitorJob` + hook en el bot | ✅ Implementada |
| **2** | API REST (3 controladores + rutas) | ✅ Implementada |
| **3** | Panel derecho conversación (`CaseTicketPanel`, modal, timeline) | ✅ Implementada |
| **4** | Vista sidebar dedicada (lista, detalle, reglas) | ✅ Implementada |
| **5** | Métricas y reportes (endpoint + vista `Metrics.vue`) | ✅ Implementada |

**Documentación detallada de cada fase:** subida al proyecto 2 de `proyectos.wintook.com` (docs ID 22-27) y en `docs/gestor_tickets_fase{0-5}.md`.

> ⚠️ **Importante para retomar el trabajo:** Todo lo que sigue marcado como "a crear" YA EXISTE. Antes de crear cualquier archivo, verificar con `git status` / `ls`. Las rutas reales y decisiones técnicas tomadas están al final de este documento en la sección **"ESTADO REAL DE IMPLEMENTACIÓN"**.

---

## Lo que NO se toca (código existente seguro)

| Componente | Estado con el Gestor de Tickets |
|-----------|--------------------------------|
| `ContactTracking` (modelo) | Sin cambios |
| `RouterService` | Sin cambios |
| `KnowledgeBaseResponseService` | Sin cambios |
| `BotSeller::Dispatcher` | Sin cambios |
| `Conversation` (modelo Chatwoot) | Sin cambios |
| `ContactTrackingResponseAnalyzerJob` — flujo principal | Sin cambios (solo se agrega un hook al inicio) |
| Todas las migraciones existentes | Sin cambios |

**El único punto de contacto con código existente** es un bloque nuevo al inicio de `process_message_for_tracking`, protegido con `rescue` para que si el Gestor de Tickets falla, el bot siga funcionando igual.

---



## 🔗 Relacionado
- [[Modelo-de-datos]] · [[Archivos-y-fases]] · [[00-Indice]]
