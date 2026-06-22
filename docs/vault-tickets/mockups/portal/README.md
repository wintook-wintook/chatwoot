---
titulo: Boceto navegable — User Portal
tipo: mockup
tags: [tickets, user-portal, mockup, osticket]
fecha: 2026-06-22
---

# Boceto navegable — User Portal

Prototipo **estático** (HTML + Tailwind vía CDN) para validar la UX del portal del
cliente antes de implementar. **No toca la app de Chatwoot.** Plan: [[Plan-User-Portal]].

## Cómo verlo
Abre `index.html` en el navegador y navega entre pantallas. O vía code-server.

## Pantallas
| Archivo | Pantalla | Captura |
|---------|----------|---------|
| `index.html` | Landing (3 acciones + buscador KB) | `shot-1-landing.png` |
| `new.html` | Abrir solicitud (contacto, tipo público, campos 2K, adjuntos) | `shot-2-new.png` |
| `status.html` | Consultar estado (read-only, timeline, SLA) | `shot-3-status.png` |
| (modal en `new.html`) | Acuse con folio | `shot-4-folio.png` |

## Interacciones simuladas (JS de juguete)
- En **new**: al elegir el tipo aparecen sus campos personalizados; "Enviar" abre el acuse con folio.
- En **status**: "Consultar" revela la vista del ticket de ejemplo.
- Botón 🌓 alterna modo oscuro en todas.

## Notas para la implementación real
- Los **iconos emoji** son solo del boceto → en la app usar **iconos Fluent** (convención del módulo).
- Marca/título/colores son de ejemplo → vendrán del **branding por cuenta** (fase P3).
- Tailwind por CDN es solo para el boceto → la app usa el build de Chatwoot.
- El timeline público muestra solo eventos visibles al cliente (sin notas internas).
