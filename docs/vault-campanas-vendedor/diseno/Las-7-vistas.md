---
titulo: Las 7 vistas
tipo: diseno
tags: [campanas-vendedor, frontend, vistas]
---

# Las 7 vistas

### Vista 1 · Listado de campañas → *"¿qué campañas tengo y cuál va mejor?"*
Tabla: nombre · entrenamiento · objetivo · estado · prospectos · respondieron ·
objetivos cumplidos · valor generado · inicio · fin.
Acciones: crear · duplicar · pausar · reanudar · finalizar · ver detalle.

### Vista 2 · Dashboard Ejecutivo → *"¿cómo va mi campaña?"* (< 10 s)
Tarjetas: asignados · respondieron · **tasa de respuesta** · objetivos cumplidos ·
**autonomía** · escalados · **valor generado** · pendientes. Embudo:
```
1000 Prospectos → 640 Respondieron → 390 Conversaciones útiles
   → 180 Cotizaciones → 95 Oportunidades → 42 Ventas
```
Top resultados: cotizaciones · pedidos · demos · oportunidades. KPIs → [[KPIs]].

### Vista 3 · Prospectos de la campaña → la más usada por ventas
Tabla: nombre · empresa · teléfono · estado · interés · **score** · prioridad · resultado
· siguiente acción · valor · última interacción · vendedor.
Filtros: alta prioridad / objetivo cumplido / escalados / sin respuesta / conversando /
cotizaciones / pedidos / no interesados / buscar. Orden: score · valor · última interacción.
Acciones: abrir conversación · abrir CRM · asignar vendedor · cambiar prioridad · marcar atendido.

### Vista 4 · Cola de trabajo del vendedor → *"¿a quién llamo primero?"*
Lista priorizada automática: **1) score · 2) valor · 3) tiempo sin atención.**
El sistema decide por el vendedor.

### Vista 5 · Resultados comerciales → *"¿dónde está el dinero?"*
Cotizaciones · pedidos · valor cotizado · valor vendido · ticket promedio · conversión ·
objetivos. Gráfica: valor generado por día.

### Vista 6 · Rendimiento del entrenamiento → comparar campañas
Compara `tracking_template`s por % respuesta y % conversión (descubrir qué entrenamiento vende mejor).

### Vista 7 · Detalle del prospecto
Info CRM → Resumen IA → Resultado → Score → Prioridad → Siguiente acción.
Botones: abrir conversación · abrir oportunidad (Kanban) · abrir cotización · asignar vendedor.

> Patrón base de UI: `views/contactTrackings/Dashboard.vue` (KPIs/donut/funnel/filtros) ya
> existe y sirve de molde para las Vistas 2/5/6; `TrackingsTable.vue` para la Vista 3.
