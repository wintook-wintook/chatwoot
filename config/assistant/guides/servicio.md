---
key: servicio
title: Servicio, soporte y SLA
areas: [service]
keywords: [servicio, soporte, ticket, tickets, sla, sla vencido, en riesgo, politicas sla, primera respuesta, resolucion, tipo de caso, clase de caso, ordenes, proyectos, clasificacion, categoria, subcategoria, servicio afectado, itil, impacto, urgencia, escalar, centro de ayuda, dashboard de servicio, metricas de soporte]
pages: [cases, case, reports, case_types, classifications, sla_policies, help_center]
---
## Para qué sirve
Servicio › Casos junta lo que se atiende a los clientes después de la venta. Cada caso pertenece a una clase:
- Soporte: tickets de clientes, con SLA (tiempos de respuesta y resolución).
- Órdenes: trabajo planeado, con técnico, visitas y horas (ver la guía de órdenes de trabajo).
- Proyectos: trabajo por fases, con fecha objetivo, presupuesto y avance.
Órdenes y Proyectos salen solo si tu cuenta las tiene activas. Lo común a todos los casos (crear, pestañas, cerrar, reabrir) está en la guía de casos.

## Dónde está
- Servicio › Casos: arriba eliges la clase (Soporte, Órdenes, Proyectos) y la forma de ver: Lista, Tablero o Dashboard.
- Catálogos › Tipos de caso, Catálogos › Clasificaciones y Catálogos › Políticas SLA (administrador).
- Servicio › Centro de Ayuda: los artículos de ayuda para tus clientes.
- Informes › Dashboard de servicio: el mismo Dashboard de Servicio › Casos.

## Cómo se hace
### Dar de alta un tipo de caso
1. Entra a Catálogos › Tipos de caso y pulsa «+ Nuevo tipo».
2. Escribe nombre, color y prefijo del folio (si lo dejas vacío se genera solo; queda fijo desde el primer caso).
3. Elige la clase: Soporte, Ventas, Orden de trabajo o Proyecto. No se puede cambiar después.
4. Marca «Maneja ITIL» si quieres naturaleza, impacto y urgencia, y «Visible en el portal del cliente» si los clientes lo pueden abrir desde un portal (solo Soporte).
5. Guarda. Con «Abrir» ves sus pestañas Campos, Columnas (las etapas del tablero) y, en órdenes, Trabajo en campo.

### Clasificar los casos
1. Entra a Catálogos › Clasificaciones.
2. En la pestaña «Servicios afectados» pulsa «+ Nuevo servicio»; en «Categorías», «+ Nueva categoría» y «Añadir subcategoría».
3. En «Aplica a» elige un tipo de caso o «Todos los tipos».
4. Al crear un caso eliges «Servicio afectado» y «Categoría». Si el tipo maneja ITIL, también «Naturaleza del caso (ITIL)», «Impacto» y «Urgencia»; la prioridad se calcula con impacto × urgencia.

### Configurar el SLA
1. Entra a Catálogos › Políticas SLA y pulsa «+ Nueva política».
2. Elige la prioridad y, si quieres, el tipo de caso y la naturaleza ITIL (o «Cualquiera»).
3. Escribe los minutos de «1ª respuesta» y de «Resolución».
4. Marca si cuenta solo el horario laboral y si está «Activa». Guarda. Si varias aplican, gana la más específica.

### Escalar un caso de soporte
1. En el caso pulsa «Escalar».
2. Escribe el motivo y, si quieres, elige otro equipo en «Reasignar a equipo». El caso sube de nivel (N1 → N2 → N3).

## Dudas frecuentes
- ¿Qué significa el punto de color junto al folio? Verde: a tiempo; ámbar: en riesgo (ya pasó el 80% del tiempo); rojo: vencido. Solo los casos de Soporte llevan SLA.
- ¿Se detiene el reloj? Sí, mientras el caso está en «En espera del cliente», «En espera de tercero» o «En espera interna». Al reabrir, el SLA empieza de cero.
- ¿Cómo veo los vencidos? Con el aviso «SLA vencido (N)» de la lista, o en Inicio › Mi resumen, en «Con SLA en riesgo o vencido».
- Si no le pones fecha en «Vence», el caso usa la que calcula el SLA.
- Un caso de Soporte en «Resuelto» se cierra solo a las 72 horas.
- Si ya tiene casos, un tipo no cambia de clase en su lugar: «Cambiar de clase» crea uno nuevo en la otra clase y el anterior se queda con sus casos.
- El Dashboard de Soporte muestra casos del período, SLA vencidos y en riesgo, cumplimiento, tiempos promedio, reabiertos y gráficas por estado, tipo, prioridad, categoría y responsable. En Órdenes y Proyectos muestra sus propias métricas.

## Quién puede
- Ver y trabajar casos de Servicio: según tu rol, todo, solo lo tuyo, ver sin cambiar o nada (el Técnico, por omisión, solo lo suyo).
- Tipos de caso, Clasificaciones y Políticas SLA: solo el Administrador.
