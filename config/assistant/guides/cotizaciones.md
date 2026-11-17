---
key: cotizaciones
title: Cotizaciones
areas: [sales]
keywords: [cotizacion, cotizaciones, retomar cotizacion, cotizar, nueva cotizacion, partida, partidas, producto, descuento, iva, impuesto, vigencia, vigente hasta, enviar cotizacion, enlace, copiar enlace, ver como cliente, pdf, firma, aceptar, rechazar, nueva version, borrar borrador, reabrir cotizacion, enviada, vencida, ganada, perdida, pospuesta, cancelada, reemplazada, trabajo adicional, condiciones, notas internas, monto en juego, cotizar con dali, pedirle a dali una cotizacion]
pages: [quotes, opportunities, case, contact, catalog, commercial_settings]
sources:
  - app/javascript/dashboard/views/gestorTickets/quotes/*.vue
  - app/javascript/dashboard/views/gestorTickets/catalog/CatalogPicker.vue
  - app/javascript/dashboard/routes/dashboard/contacts/components/ContactQuotesTab.vue
  - app/views/public/quotes/show.html.erb
  - app/controllers/api/v1/accounts/quotes_controller.rb
  - app/services/quotes/*.rb
  - app/models/quote.rb
reviewed: 2026-11-14
---
## Para qué sirve
Una cotización es la propuesta con precios que le mandas al cliente. Puede ir sola o ligada a una oportunidad; el cliente la ve por un enlace, la acepta o la rechaza, y su resultado se refleja en la oportunidad.

## Dónde está
- Ventas › Cotizaciones: arriba, el resumen (Enviadas, Aceptación (90 días), Monto en juego, Vencidas, Respuesta del cliente) y las pestañas Abiertas, Borrador, Enviadas, Ganadas, Perdidas, Pospuestas, Canceladas, Vencidas y Todas. «Abiertas» junta Borrador, Enviadas y Pospuestas.
- Puedes buscar en «Buscar por folio o cliente». La lista muestra Folio, Cliente, Ligada a (la oportunidad o el caso), Estado, Total, Vigencia y Responsable; haz clic en una fila para abrirla.
- En la oportunidad o el caso: «Más ▾» › Cotizaciones.
- En la ficha del contacto: pestaña Cotizaciones.

## Cómo se hace
### Crear una cotización
1. En Ventas › Cotizaciones pulsa «Cotización». También sirve «+ Cotización» en la oportunidad o en la ficha del contacto (llega con el cliente puesto); en un caso de servicio el botón es «Cotizar trabajo adicional».
2. En Cliente elige la «Organización (opcional)» y el Contacto. Luego el Responsable, «Vigente hasta» y la Moneda (código de 3 letras, como MXN). Si no pones vigencia, queda a 15 días; si dejas el responsable en «—», quedas tú; si no pones moneda, toma la del primer producto o la de tu empresa.
3. En Oportunidad elige una abierta del cliente, «— Sin oportunidad —» o «+ Crear oportunidad nueva». Si tu empresa pide que toda cotización tenga oportunidad, no sale «— Sin oportunidad —».
4. Agrega partidas: escribe en «Buscar en el catálogo…» y elige el producto, o usa «Usar «…» sin catálogo» para un concepto libre.
5. En cada partida ajusta Concepto, Cant., Unidad, Precio, Desc. % e Imp. %. El Importe y los totales (Subtotal, Descuento, Impuestos, Total) se calculan solos. La ✕ quita una partida.
6. Si quieres, escribe Condiciones (las ve el cliente: forma de pago, tiempo de entrega, garantía…) y Notas internas (solo tu equipo).
7. Pulsa «Guardar». Nace como Borrador y recibe su folio (COT-0001). Sin cliente sale «Elige el cliente» y sin partidas «Agrega al menos una partida».

### Pedírsela a Dali
1. En la caja «Pregúntale a …» escribe qué y a quién, por ejemplo «cotízale a Mario 3 mantenimientos de minisplit y una instalación de 3500».
2. Dali busca al cliente y cada producto en el Catálogo y toma su precio sin IVA. Lo que no esté en el catálogo lo pone como partida libre; si no le dijiste el precio, te lo pregunta.
3. Te muestra la tarjeta «Nueva cotización»: cliente, oportunidad a la que se liga (la abierta más reciente del cliente, o una nueva si la empresa exige oportunidad), cada partida con Cantidad y Precio sin IVA que puedes cambiar o quitar, y Subtotal sin IVA, IVA y Total.
4. Pulsa «Confirmar»: se crea en Borrador con el impuesto, la vigencia y el folio de la empresa. «Ver» la abre.
5. Después te pregunta «¿Se la mando?». Si dices que sí, sale la tarjeta «Enviar cotización»; al confirmar se manda como con «Enviar al cliente».
También puedes preguntarle «¿qué cotizaciones tiene abiertas Mario?». Lo demás (editarla, nueva versión, marcar el resultado) se hace en la cotización.

### Enviarla al cliente
1. Abre la cotización (en Borrador o Enviada) y pulsa «Enviar al cliente»: se manda un mensaje con el enlace por la conversación abierta más reciente del cliente (o la última que tenga) y, si era borrador, pasa a Enviada.
2. Si el cliente no tiene conversaciones, usa «Copiar enlace» y mándaselo por otro medio; luego «Más» › «Marcar como enviada» (solo en Borrador).
3. «Más» › «Ver como cliente» abre lo que verá el cliente.

### Lo que hace el cliente con el enlace
1. Ve las partidas, los totales, las condiciones y quién lo atiende. La cotización se marca «Vista».
2. Puede aceptarla con «Aceptar cotización»: escribe su nombre (obligatorio) y, si quiere, firma con el dedo. O rechazarla con «Rechazar» y un comentario opcional.
3. Si la cotización ya venció, no puede aceptarla: ve «Esta cotización ya venció. Pide a tu asesor una versión actualizada.».
4. En esa página está el botón «Descargar PDF».

### Marcar el resultado
1. Pulsa «Ganada», «Perdida», «Pospuesta» o «Cancelada». Ganada, Perdida y Cancelada salen en Borrador, Enviada o Pospuesta; Pospuesta, solo en Borrador o Enviada.
2. Elige el Motivo (sale solo si el catálogo tiene motivos para ese resultado; puedes dejar «Sin motivo») y un Comentario; en Pospuesta, la fecha en «Retomar el» (propone dentro de 14 días).
3. Pulsa «Guardar». Una perdida o cancelada se puede «Reabrir»: vuelve a Enviada. Una pospuesta tiene «Retomar (vuelve a Enviada)»; si la oportunidad estaba pospuesta, también se retoma.

### Cambiar una cotización ya enviada
1. Solo se editan las cotizaciones en Borrador o Enviada. Las demás dicen «Esta cotización ya no se edita. Para cambiarla, haz una nueva versión.».
2. Para otra propuesta: «Más» › «Nueva versión». Se crea la v2 con las mismas partidas y 15 días de vigencia; si la anterior seguía abierta (borrador, enviada o pospuesta), queda cancelada como «Reemplazada por la versión 2».
3. La oportunidad se cambia en el mismo campo Oportunidad y se aplica al momento. Ya ganada, perdida o cancelada, la cotización ya no cambia de oportunidad.
4. Un borrador que no sirve se quita con «Más» › «Borrar borrador» (pide confirmar).

## Dudas frecuentes
- ¿Lleva IVA? La cotización sí suma impuestos para el cliente, pero lo vendido se cuenta sin IVA: subtotal menos descuento.
- ¿Qué pasa con la oportunidad? Si la cotización se gana, la oportunidad se gana con ese monto sin IVA y las demás cotizaciones abiertas se cancelan. Si es la única, la oportunidad también se pierde, cancela o pospone con ella. Si tiene varias y ya no queda ninguna abierta, sale «Ya no queda ninguna cotización abierta en la oportunidad …»: elige «Marcar oportunidad perdida» o «Dejarla abierta».
- ¿Qué es «Vencida»? Una enviada cuya vigencia ya pasó.
- ¿Qué cuenta «Monto en juego»? El total de los borradores y las enviadas, por moneda. «Aceptación (90 días)» y «Respuesta del cliente» se calculan con las ganadas y perdidas de los últimos 90 días.
- Si la cotización salió de una orden de trabajo, al ganarse sus partidas pasan a la orden; si salió de un proyecto, se crea una orden dentro del proyecto.
- El impuesto por defecto de las partidas y si toda cotización debe tener oportunidad se configuran en Ajustes › Casos y etapas › Parámetros de ventas (administrador).
- Los productos salen de Catálogos › Productos y servicios. Ver la guía Catálogo de productos y servicios.

## Quién puede
Con Ventas en «Todo» o «Ve todo (sin cambiar)» ves todas las cotizaciones; si no, las tuyas y las que salieron de casos que puedes ver. Para crear necesitas Ventas en «Todo» o «Solo lo suyo» (desde un caso de servicio basta con poder trabajar ese caso). Los precios de una cotización ajena solo se ven con el permiso «Ver montos»; sin él salen como «—».
