---
key: catalogo_productos
title: Catálogo de productos y servicios
areas: [sales, service]
keywords: [catalogo, productos, producto, servicios, servicio, refaccion, refacciones, precio, precio de venta, costo, margen, clave, sku, categoria, subcategoria, categorias, unidad, unidades de medida, impuesto, impuestos, iva, iva 16, iva 8, frontera, iva 0, exento, impuesto por omision, precio con iva, precio incluye iva, duracion, duracion del servicio, minutos, retencion, retenciones, retencion de iva, retencion de isr, isr, resico, fletes, persona moral, clave sat, parametros, moneda, importar, exportar, csv, lista de precios, desactivar, inactivo, alta de producto, borrar producto, eliminar producto]
pages: [catalog, quotes, contracts]
sources: [app/javascript/dashboard/views/gestorTickets/catalog/*.vue, app/javascript/dashboard/api/catalogItems.js, app/controllers/api/v1/accounts/catalog_items_controller.rb, app/controllers/api/v1/accounts/catalog_parameters_controller.rb, app/models/catalog_item.rb, app/models/concerns/catalog_item_parameters.rb, app/models/catalog_category.rb, app/models/catalog_unit.rb, app/models/tax_rate.rb, app/services/catalog_parameters.rb, app/services/quotes/withholdings.rb]
reviewed: 2026-11-27
---
## Para qué sirve
El catálogo es la lista de lo que vende tu empresa (productos y servicios) y de las refacciones que usa el técnico, con su precio. Se da de alta una vez y se usa en las cotizaciones, las órdenes de trabajo y los contratos.

## Dónde está
- Catálogos › Productos y servicios (la pantalla se llama «Catálogo de productos y servicios»). Tiene dos pestañas: «Productos» (la lista) y «Parámetros» (las categorías, los impuestos, las retenciones y las unidades de medida que se eligen en cada producto).
- Arriba hay una búsqueda («Buscar por nombre o clave») y tres filtros: tipo («Todos los tipos», «Servicio», «Producto», «Refacción»), categoría («Todas las categorías» o una de la lista; una categoría incluye sus subcategorías) y estado («Activos», «Inactivos» o «Todos»). Por omisión se ven solo los activos.
- La lista tiene las columnas «Clave», «Nombre», «Tipo», «Categoría», «Unidad», «Precio», «Costo» y «Activo», ordenada por nombre y de 50 en 50 (flechas abajo para cambiar de página). Los inactivos se ven más tenues.

## Cómo se hace
### Dar de alta un producto o servicio
1. Entra a Catálogos › Productos y servicios.
2. Pulsa «Producto o servicio».
3. Escribe el «Nombre» (obligatorio). La «Clave» es opcional, sirve para buscar e importar y no se puede repetir.
4. Elige el «Tipo»: «Servicio» (viene marcado), «Producto» o «Refacción». Si quieres, elige la «Categoría» y la «Unidad» de sus listas (se dan de alta en la pestaña «Parámetros»).
5. Pon el «Precio de venta» y la «Moneda» (3 letras, por ejemplo MXN; si la dejas vacía toma la de tu cuenta). El «Costo» es opcional y sirve para ver el margen.
6. En un servicio sale «Duración (minutos)» (opcional): si «Atención a clientes» agenda citas de servicio, la cita ocupa ese tiempo en la agenda (con varios servicios, la suma).
6. En «Impuesto» deja «Por omisión (…)» o elige otro (por ejemplo IVA 0 % para alimentos o Exento). Marca «El precio ya incluye el impuesto» si tu precio de venta es con IVA: al cotizar se separa el impuesto para que el total sea ese precio. En «Retenciones» marca las que lleva (por ejemplo Ret. IVA 10.67 % y Ret. ISR 10 % en un servicio profesional): en la cotización se restan solo si el cliente es persona moral. La «Clave SAT de producto o servicio» es opcional.
7. Agrega una «Descripción» si hace falta y deja marcado «Activo (se puede usar en cotizaciones y órdenes)».
8. Pulsa «Guardar».

### Cambiar un precio o un dato
1. Haz clic en el renglón del producto: se abre «Editar producto o servicio».
2. Cambia el «Precio de venta» (o lo que necesites) y pulsa «Guardar».
3. Los contratos que tienen marcado «Usar el precio del producto» se actualizan solos. Las cotizaciones ya hechas no cambian: guardan el precio con el que se cotizó.

### Categorías, impuestos y unidades (pestaña «Parámetros»)
1. Entra a Catálogos › Productos y servicios y abre la pestaña «Parámetros». Tiene cuatro bloques: «Categorías», «Impuestos», «Retenciones» y «Unidades de medida»; cada renglón dice cuántos productos lo usan.
2. «Agregar» da de alta uno nuevo en el mismo bloque. En una categoría, «+ Subcategoría» agrega una debajo (solo un nivel: Refacciones › Frenos).
3. El lápiz lo cambia en el mismo renglón; «Guardar» o «Cancelar». Si cambias el nombre de una categoría o la abreviatura de una unidad, los productos que la usan se actualizan solos.
4. El bote lo borra, y solo aparece si nadie lo usa. Lo que está en uso tiene «Desactivar»: ya no se ofrece al elegir, pero los productos que lo tienen lo conservan. «Activar» lo regresa.
5. En «Impuestos», el círculo marca el de por omisión (solo hay uno): lo usan los productos sin impuesto propio y las partidas que no son del catálogo. Al principio vienen IVA 16 %, IVA 8 % (frontera), IVA 0 % y Exento; el marcado es el que tu cuenta ya usaba. El de por omisión no se puede desactivar ni borrar: primero marca otro.
6. En «Retenciones» vienen Ret. IVA 10.67 % (dos terceras partes del IVA, para servicios profesionales y arrendamiento), Ret. ISR 10 %, Ret. ISR RESICO 1.25 % y Ret. IVA fletes 4 %. Se agregan otras con «Agregar» (nombre y porcentaje, hasta 4 decimales). Una retención no puede ser el impuesto por omisión.
7. En «Unidades de medida» cada una tiene nombre, abreviatura (la que sale en cotizaciones y órdenes) y clave SAT opcional. Vienen Pieza, Servicio, Hora, Día, Kilogramo, Metro, Litro, Caja, Juego y Paquete.
8. Las categorías y unidades que ya estaban escritas en tus productos pasaron solas a estas listas la primera vez que se abrió el catálogo.

### Importar o exportar la lista
1. «Exportar» descarga el catálogo completo (activos e inactivos) en un archivo CSV.
2. «Importar» sube un CSV. La primera fila debe traer los nombres de las columnas, sin acentos: clave, nombre, tipo, categoria, unidad, precio, moneda, costo, descripcion, activo, impuesto, precio_con_impuesto, clave_sat, retenciones, duracion_min (las cinco últimas son opcionales; duracion_min son los minutos del servicio).
3. Si el renglón ya existe (por clave o, si no tiene clave, por nombre) se actualiza; si no, se crea. Al terminar dice «Importado: … nuevos, … actualizados» y, si hubo, cuántas filas tuvieron error y cuál fue el primero.
4. En «tipo» escribe producto, servicio o refaccion (lo que no se reconozca queda como Producto). En «activo», «no», «0» o «inactivo» lo desactivan; cualquier otra cosa lo deja activo.
5. En «categoria» escribe «Categoría › Subcategoría» (o con >). La categoría o unidad que no exista en «Parámetros» se crea. En «impuesto» va el nombre o el porcentaje (IVA 16 %, 16, exento); si no se reconoce, usa el de por omisión. En «precio_con_impuesto» escribe si o no. En «retenciones» van sus nombres o porcentajes separados por punto y coma (Ret. IVA 10.67 %; Ret. ISR 10 %); las que no existan se ignoran.

### Dejar de usar un producto
1. Abre el producto y desmarca «Activo».
2. Pulsa «Guardar». Los productos no se borran (no hay botón de borrar): se desactivan, para conservar la historia. Para volver a verlos usa el filtro «Inactivos».

## Límites
- No se pueden borrar productos, solo desactivar.
- Al importar, una columna vacía en el CSV deja vacío ese dato en el producto (por ejemplo la descripción o la categoría). Exporta primero, cambia el archivo y vuelve a importarlo completo.
- Si en el CSV pones una clave nueva con un nombre que ya existe, se crea otro producto con el mismo nombre.

## Dudas frecuentes
- ¿Cómo lo uso en una cotización? En las partidas escribe en «Buscar en el catálogo…» y elige el producto: llega con su nombre, unidad, precio e impuesto, que puedes ajustar en esa cotización. Ver la guía Cotizaciones.
- ¿Dónde cambio el IVA de las cotizaciones? En la pestaña «Parámetros» › «Impuestos»: el marcado es el de por omisión. Ya no está en Parámetros de ventas.
- ¿Cuándo se aplican las retenciones? Solo cuando el cliente es persona moral (el RFC de su organización tiene 12 caracteres). En la cotización se puede cambiar con «Aplicar retenciones».
- Las cotizaciones y contratos que ya existen no cambian al mover una lista: guardan su propio impuesto y unidad.
- ¿Y en un contrato? En el contrato elige el producto en «Del catálogo (opcional)» y marca «Usar el precio del producto». Desmárcala para darle a ese cliente un precio especial.
- ¿Puedo cotizar algo que no está en el catálogo? Sí, con «Usar «…» sin catálogo» en las partidas.
- ¿Por qué no veo la columna Costo? Solo la ve quien tiene el permiso «Ver montos» (tampoco sale en el formulario ni en el archivo exportado).
- Solo los productos activos se pueden usar en cotizaciones y órdenes.
- No hay productos: sale «Todavía no hay productos ni servicios. Agrega el primero o importa tu lista.»

## Quién puede
Lo consulta y lo exporta cualquiera con acceso a Ventas o a Servicio (el técnico busca refacciones). Dar de alta, editar e importar solo lo hace quien tiene Ventas en «Todo» (por ejemplo el Administrador y el Supervisor); los demás no ven los botones «Producto o servicio» ni «Importar» y al hacer clic en un renglón no se abre nada. El costo solo lo ve y lo cambia quien tiene «Ver montos».
