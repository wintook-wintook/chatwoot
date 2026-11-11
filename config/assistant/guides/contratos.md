---
key: contratos
title: Contratos (servicios recurrentes)
areas: [clients, sales]
keywords: [contrato, contratos, nuevo contrato, servicio recurrente, iguala, monitoreo, licencia, poliza, membresia, renovar, renovacion automatica, se renueva solo, plazo, proximo cobro, registrar pago, pago vencido, por renovar, suspender, cancelar contrato, reactivar, precio especial, tipo de contrato, importar contratos, csv]
pages: [contracts, contact, catalog, contract_types]
---
## Para qué sirve
Un contrato es lo que un cliente paga o renueva cada cierto tiempo: monitoreos, igualas, licencias, pólizas, membresías… Lleva cuánto se cobra, cada cuánto, el próximo cobro y el plazo.

## Dónde está
- Clientes › Contratos: todos, con pestañas por estado, el buscador «Buscar por cliente o concepto» y el filtro «Todos los tipos».
- La pestaña «Contratos» de la ficha del contacto, y la de la página de la organización.
- Los tipos se dan de alta en Catálogos › Tipos de contrato.

## Cómo se hace
### Crear un contrato
1. Pulsa «Nuevo contrato» en Clientes › Contratos o en la pestaña «Contratos» del contacto.
2. Elige el cliente: «Organización (opcional)» y «Contacto» (desde la ficha ya viene puesto).
3. Elige el «Tipo de contrato»: se llenan solos cada cuánto se cobra, el plazo y si se renueva solo (los puedes cambiar).
4. Si quieres, elige un producto en «Del catálogo (opcional)» y escribe el «Concepto» (ej. Monitoreo 24/7).
5. «Cantidad», «Precio por periodo» y «Moneda».
6. «Se cobra cada» (número y días, semanas, meses o años), «Inicio» y «Próximo cobro» (vacío = el día de inicio).
7. «Plazo (meses)» (vacío = sin plazo), la casilla «Se renueva solo al terminar el plazo», «Equipo ligado (opcional)», «Responsable», los datos propios del tipo y «Notas».
8. Pulsa «Guardar».

### Precio del catálogo o precio especial
1. Al elegir un producto se marca «Usar el precio del producto»: si el precio cambia en Catálogos › Productos y servicios, el contrato se actualiza solo.
2. Desmárcala para darle a este cliente un precio especial.

### Registrar el pago, renovar y demás
1. En el contrato pulsa «⋯» (Acciones).
2. «Registrar pago»: el próximo cobro avanza un periodo.
3. «Renovar»: le suma otro plazo igual (solo si tiene plazo).
4. «Suspender», «Reactivar», «Cancelar contrato» (pide un motivo opcional) y «Editar».

### Importar varios
1. Pulsa «Plantilla» para bajar las columnas y llénala (en Excel: Guardar como › CSV UTF-8).
2. Súbela con «Importar». El cliente se busca por correo o teléfono y el tipo por su nombre; si no existe, esa fila se reporta con su número y no se crea.
3. Con la columna «id» se actualiza ese contrato en vez de crear otro.

## Dudas frecuentes
- ¿Qué significan los estados? «Al corriente»; «Por renovar» (el plazo termina en 30 días o menos); «Pago vencido» (ya pasó el próximo cobro); «Terminado» (se acabó el plazo y no se renueva solo); «Suspendido»; «Cancelado».
- ¿Cómo funciona «Se renueva solo»? El plazo se alarga cuando registras un pago que cae después del fin del plazo. No se renueva solo por la fecha: mientras tanto sale «Por renovar»; puedes usar «Renovar».
- ¿Cuánto es el monto? Cantidad por precio por periodo.
- ¿El contrato hace cliente a la organización? Sí, si está encendida la regla «Al dar de alta un contrato» (viene encendida).
- ¿Cómo doy de alta un tipo? En Catálogos › Tipos de contrato › «Nuevo tipo»: nombre, color, cada cuánto se cobra, plazo por omisión, si se renueva solo y sus «Datos propios» (texto, número o fecha).

## Quién puede
Se ven con acceso a Clientes o a Ventas; se crean y cambian con «Todo» o «Solo lo suyo» en cualquiera de las dos (con «Solo lo suyo», los de tus contactos). El precio solo lo ve y lo cambia quien tiene «Ver montos». Los tipos de contrato los da de alta el Administrador.
