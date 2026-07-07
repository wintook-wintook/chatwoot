---
titulo: Visión y convenciones
tipo: diseno
tags: [campanas-vendedor, vision]
---

# Visión y convenciones

## Qué es
Desplegar un **Agente Vendedor IA** sobre un **segmento de prospectos** y convertir las
conversaciones en **oportunidades de venta**. El módulo **no** es de envíos masivos: el
valor está en **medir y decidir**, no en mandar mensajes.

## Las 3 preguntas (objetivo de diseño)
El módulo debe responder, en menos de un minuto:
```
1. ¿Cómo va mi campaña?      → Dashboard Ejecutivo (KPIs + embudo)   [[Las-7-vistas]]
2. ¿Dónde está el dinero?    → Resultados comerciales (valor)        [[Las-7-vistas]]
3. ¿A quién llamar primero?  → Cola del vendedor (orden automático)  [[Las-7-vistas]]
```
Si el usuario las responde rápido, el módulo cumplió su objetivo.

## Flujo de 7 pasos
```
1 Crear campaña → 2 Elegir Entrenamiento (tracking_template)
→ 3 Seleccionar contactos (bulk) → 4 Iniciar (crea ContactTrackings)
→ 5 El Agente conversa (ContactTrackingJob) → 6 El sistema mide (KPIs/embudo)
→ 7 El usuario decide (dashboards + cola)
```
Detalle de reuso → [[Reuso-y-arquitectura]].

## Convenciones (heredadas del repo)
- Código/tablas/enums en **inglés**; **UI en español** (i18n `es`/`en`).
- Migraciones **siempre al final**. **Commit solo cuando se pida.**
- 1 tracking activo por **(contacto, inbox)** (constraint del módulo base).
- Marcador en código sugerido: `# @campanas_vendedor`.
