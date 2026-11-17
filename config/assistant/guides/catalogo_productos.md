---
key: catalogo_productos
title: Catálogo de productos y servicios
areas: [sales, service]
keywords: [catalogo, productos, producto, servicios, servicio, refaccion, refacciones, precio, precio de venta, costo, margen, clave, sku, categoria, unidad, moneda, importar, exportar, csv, lista de precios, desactivar, inactivo, alta de producto, borrar producto, eliminar producto]
pages: [catalog, quotes, contracts]
sources: [app/javascript/dashboard/views/gestorTickets/catalog/*.vue, app/javascript/dashboard/api/catalogItems.js, app/controllers/api/v1/accounts/catalog_items_controller.rb, app/models/catalog_item.rb]
reviewed: 2026-11-14
---
## Para qué sirve
El catálogo es la lista de lo que vende tu empresa (productos y servicios) y de las refacciones que usa el técnico, con su precio. Se da de alta una vez y se usa en las cotizaciones, las órdenes de trabajo y los contratos.

## Dónde está
- Catálogos › Productos y servicios (la pantalla se llama «Catálogo de productos y servicios»).
- Arriba hay una búsqueda («Buscar por nombre o clave») y tres filtros: tipo («Todos los tipos», «Servicio», «Producto», «Refacción»), categoría («Todas las categorías» o una de las que ya usas) y estado («Activos», «Inactivos» o «Todos»). Por omisión se ven solo los activos.
- La lista tiene las columnas «Clave», «Nombre», «Tipo», «Categoría», «Unidad», «Precio», «Costo» y «Activo», ordenada por nombre y de 50 en 50 (flechas abajo para cambiar de página). Los inactivos se ven más tenues.

## Cómo se hace
### Dar de alta un producto o servicio
1. Entra a Catálogos › Productos y servicios.
2. Pulsa «Producto o servicio».
3. Escribe el «Nombre» (obligatorio). La «Clave» es opcional, sirve para buscar e importar y no se puede repetir.
4. Elige el «Tipo»: «Servicio» (viene marcado), «Producto» o «Refacción». Si quieres, escribe la «Categoría» (te sugiere las que ya existen) y la «Unidad» (pieza, hora, kg, servicio…).
5. Pon el «Precio de venta» y la «Moneda» (3 letras, por ejemplo MXN; si la dejas vacía toma la de tu cuenta). El «Costo» es opcional y sirve para ver el margen.
6. Agrega una «Descripción» si hace falta y deja marcado «Activo (se puede usar en cotizaciones y órdenes)».
7. Pulsa «Guardar».

### Cambiar un precio o un dato
1. Haz clic en el renglón del producto: se abre «Editar producto o servicio».
2. Cambia el «Precio de venta» (o lo que necesites) y pulsa «Guardar».
3. Los contratos que tienen marcado «Usar el precio del producto» se actualizan solos. Las cotizaciones ya hechas no cambian: guardan el precio con el que se cotizó.

### Importar o exportar la lista
1. «Exportar» descarga el catálogo completo (activos e inactivos) en un archivo CSV.
2. «Importar» sube un CSV. La primera fila debe traer los nombres de las columnas, sin acentos: clave, nombre, tipo, categoria, unidad, precio, moneda, costo, descripcion, activo.
3. Si el renglón ya existe (por clave o, si no tiene clave, por nombre) se actualiza; si no, se crea. Al terminar dice «Importado: … nuevos, … actualizados» y, si hubo, cuántas filas tuvieron error y cuál fue el primero.
4. En «tipo» escribe producto, servicio o refaccion (lo que no se reconozca queda como Producto). En «activo», «no», «0» o «inactivo» lo desactivan; cualquier otra cosa lo deja activo.

### Dejar de usar un producto
1. Abre el producto y desmarca «Activo».
2. Pulsa «Guardar». Los productos no se borran (no hay botón de borrar): se desactivan, para conservar la historia. Para volver a verlos usa el filtro «Inactivos».

## Límites
- No se pueden borrar productos, solo desactivar.
- Al importar, una columna vacía en el CSV deja vacío ese dato en el producto (por ejemplo la descripción o la categoría). Exporta primero, cambia el archivo y vuelve a importarlo completo.
- Si en el CSV pones una clave nueva con un nombre que ya existe, se crea otro producto con el mismo nombre.

## Dudas frecuentes
- ¿Cómo lo uso en una cotización? En las partidas escribe en «Buscar en el catálogo…» y elige el producto: llega con su nombre, unidad y precio, que puedes ajustar en esa cotización. Ver la guía Cotizaciones.
- ¿Y en un contrato? En el contrato elige el producto en «Del catálogo (opcional)» y marca «Usar el precio del producto». Desmárcala para darle a ese cliente un precio especial.
- ¿Puedo cotizar algo que no está en el catálogo? Sí, con «Usar «…» sin catálogo» en las partidas.
- ¿Por qué no veo la columna Costo? Solo la ve quien tiene el permiso «Ver montos» (tampoco sale en el formulario ni en el archivo exportado).
- Solo los productos activos se pueden usar en cotizaciones y órdenes.
- No hay productos: sale «Todavía no hay productos ni servicios. Agrega el primero o importa tu lista.»

## Quién puede
Lo consulta y lo exporta cualquiera con acceso a Ventas o a Servicio (el técnico busca refacciones). Dar de alta, editar e importar solo lo hace quien tiene Ventas en «Todo» (por ejemplo el Administrador y el Supervisor); los demás no ven los botones «Producto o servicio» ni «Importar» y al hacer clic en un renglón no se abre nada. El costo solo lo ve y lo cambia quien tiene «Ver montos».
