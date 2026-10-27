# Plan — Catálogo de productos y servicios, y Cotizaciones

> Estado: ✅ **C1 y V1 hechos** (2026-10-26, rama `feat/nva_oportunidad`, **sin commit**: lo revisa
> el programador). Siguió [[Plan-Trabajo-Campo]] (R1 → R5, también hecho).

## Decisiones del usuario
- **Un solo catálogo** para Ventas (cotizaciones) y Servicio (materiales de la orden, trabajo
  adicional del técnico). Vive en **Ventas › Catálogo**.
- **La cotización es su propio documento** (lista en **Ventas › Cotizaciones**, folio propio) y se
  puede hacer desde cualquier parte. **Puede vivir sola, sin oportunidad**: hay vendedores que no
  usan oportunidades pero sí controlan el estado de la cotización.
- Se puede **ligar** a una oportunidad, un proyecto, una orden de trabajo o un caso de soporte, y
  ligarla a una oportunidad después («Ligar a oportunidad»).
- **Mismos estados que la oportunidad** (con sus mismos motivos de Ajustes › Motivos).

## C1 — Catálogo de productos y servicios
- Campos: nombre, clave, **tipo** (Producto / Servicio / Refacción), categoría, unidad, **precio
  de venta** y moneda, **costo** (opcional; solo con «Ver montos»), activo/inactivo.
- **Roles**: lo edita quien tiene Ventas (o el Administrador); se **consulta** desde cualquier
  orden o cotización (el Técnico busca refacciones sin tener Ventas).
- Uso: materiales de la orden (R1), partidas de la cotización (V1), cotizar en sitio (R2).
- Después: llenarlo desde el ERP del cliente (conexiones a bases externas ya existen).

## V1 — Cotizaciones
- **Documento**: folio (COT-0001) y versión; cliente; **responsable** (vendedor); ligas opcionales
  (oportunidad, proyecto, orden, caso); partidas del catálogo o libres (cantidad, precio,
  descuento, impuesto); subtotal, impuestos, total y moneda; vigencia, condiciones y notas.
- **Estados**: Borrador → Enviada (marca «Vista» al abrirla) → **Ganada / Perdida / Pospuesta /
  Cancelada**. «Vencida» no es estado: marca roja en una Enviada con vigencia pasada (renovar =
  nueva versión, o marcar Perdida).
- **Enlace para el cliente**: ver, **Aceptar** (nombre; firma en celular) o **Rechazar**,
  «Descargar PDF» (impresión del navegador).
- **Sola (sin oportunidad)**: su estado se maneja desde ella; no se crea oportunidad.
- **Ligada a una oportunidad** — sincronización:
  - Una sola cotización: **espejo** en los dos sentidos (Ganada, Perdida con motivo, Pospuesta,
    Cancelada, reanudar).
  - Varias: el cliente acepta una → oportunidad **Ganada** y las demás abiertas **Cancelada**
    («Se aceptó COT-x»); rechaza una con otras abiertas → la oportunidad sigue; se rechazan
    todas → Wintook **pregunta** si marca la oportunidad Perdida (pide motivo); oportunidad
    pospuesta → abiertas Pospuesta (al reanudar vuelven a Enviada); oportunidad cancelada o
    perdida → abiertas igual con el mismo motivo; oportunidad Ganada a mano con varias abiertas →
    pregunta cuál se aceptó; nueva versión → la anterior Cancelada («Reemplazada por v2»).
  - Regla: la oportunidad manda sobre el resultado final y una cotización ganada siempre la gana.
- **Ligada a proyecto/orden/caso**: al aceptar, las partidas pasan a la orden (o a una orden nueva
  dentro del proyecto); en el caso se ve «Cotización COT-x · Enviada».
- **Venta nueva aceptada**: ofrece «Crear orden de trabajo» o «Crear proyecto».
- **Números**: Dashboard de ventas suma oportunidades ganadas + cotizaciones sueltas ganadas (sin
  doble conteo de las ligadas); métricas de cotizaciones (enviadas, % de aceptación, tiempo de
  respuesta, monto en juego, vencidas, por vendedor).
- **Roles**: con «solo lo suyo» el vendedor ve solo sus cotizaciones; sin «Ver montos», sin importes.
- **Opción por empresa**: «Las cotizaciones requieren oportunidad» (apagada por defecto).
- Desde dónde se cotiza: Ventas › Cotizaciones, una oportunidad, un proyecto/orden/caso
  («Cotizar trabajo adicional»), el técnico en sitio (R2), una conversación de WhatsApp.

## Menú Ventas (queda así)
Embudo de contactos · Oportunidades · **Cotizaciones** · **Catálogo** · Plantillas de WhatsApp ·
Etiquetas · Respuestas predefinidas.

## Implementado (2026-10-26)
- **C1**: tabla `catalog_items` (producto / servicio / refacción, SKU, categoría, unidad, precio,
  costo solo con «ver montos», impuesto). API `catalog_items` (+ categorías, exportar/importar CSV).
  Ventas › Catálogo (`Catalog.vue`, `CatalogItemForm.vue`) y `CatalogPicker.vue` (reutilizable: en
  la cotización, en los materiales de la orden y en el celular del técnico).
- **V1**: `quotes` + `quote_items`, folio `COT-0001 vN`, `case_settings.quotes_require_opportunity`
  y `default_tax_percent`. Servicios `Quotes::{OpportunitySync,ApplyToOrigin,StatusService,Builder,
  Serializer,Summary,Delivery}`. Con una sola cotización, el monto y el estado se reflejan en la
  oportunidad; al cerrar la oportunidad se elige cuál se ganó. Enlace público `/cotizacion/:token`
  (aceptar con nombre y firma, rechazar con comentario). Ventas › Cotizaciones, pestaña en el caso,
  «Nueva cotización» desde el contacto, ajustes y métricas comerciales (pestaña Cotizaciones).
- Specs: `catalog_items_spec`, `quotes_spec`.
