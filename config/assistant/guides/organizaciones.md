---
key: organizaciones
title: Organizaciones, prospectos y clientes
areas: [clients]
keywords: [organizacion, organizaciones, empresa, prospecto, prospectos, cliente, marcar como cliente, regresar a prospecto, publico en general, rfc, razon social, convertir en prospecto, ligar contacto, quitar de la organizacion, cambiar de organizacion, sustituto, agrupar contactos, importar organizaciones, csv, prospectos y clientes automaticos, bitacora, etapa]
pages: [organizations, organization, contact]
---
## Para qué sirve
Una organización es la empresa (o el público en general) detrás de tus contactos. Tiene etapa, Prospecto o Cliente, y tipo: «Empresa» (se le factura, con RFC) o «Público en general» (sin factura). Cada contacto pertenece a una sola organización; sin ella es solo un contacto.

## Dónde está
- Clientes › Organizaciones: pestañas Prospectos, Clientes y Todas (con cuántas hay), el buscador «Buscar por nombre, RFC o dominio» y el filtro Empresa / Público en general.
- La página de cada organización: sus datos, sus contactos, sus Oportunidades, Casos, Cotizaciones, Contratos y Equipos (de todos sus contactos), sus Tareas y la Bitácora de cambios de etapa.
- En la ficha del contacto, el bloque «Organización».

## Cómo se hace
### Crear una organización
1. En Clientes › Organizaciones pulsa «Nueva organización».
2. Elige el «Tipo»: Empresa o Público en general.
3. Escribe el «Nombre o razón social» y elige la «Etapa» (Prospecto o Cliente).
4. Si es Empresa: RFC (opcional, se puede completar al facturar), Giro, Sitio web y Dominio de correo.
5. Teléfono, «Responsable», Dirección y Notas. Pulsa «Guardar».

### Convertir un contacto en prospecto
1. Abre la ficha del contacto. En «Organización» dice «Sin organización: es un contacto.».
2. Pulsa «Convertir en prospecto»: se llena con la empresa que tiene escrita (o con su nombre, como Público en general). Revisa y guarda.
3. Si la empresa ya existe, usa «Ligar a una organización existente» y búscala.

### Cambiar la etapa
1. En la página de la organización pulsa «Marcar como cliente» o «Regresar a prospecto».
2. Solo cambia la etapa; queda en la Bitácora con quién lo hizo.

### Agregar o quitar contactos
1. En la página de la organización, en «Ligar un contacto», busca y elige al contacto. Solo se puede ligar uno que no tenga organización.
2. Para quitarlo pulsa la «x» junto a su nombre. Lo suyo que ya está en la organización se queda ahí.

### Cambiar a un contacto de organización
1. En la ficha del contacto, bloque «Organización», pulsa «Cambiar de organización».
2. «¿A qué organización se va?»: elige la nueva, o «A ninguna».
3. «¿Pasar también lo suyo?»: «Sí, pasar todo a la nueva» (estaba en la equivocada) o «No, que todo se quede» (se cambió de empresa).
4. Si se queda: elige quién queda en su lugar o «+ Dar de alta uno nuevo». Esa persona queda como contacto de lo que sigue vivo (casos y oportunidades abiertos, cotizaciones sin decidir, contratos, equipos, mantenimientos); lo cerrado se queda con quien lo atendió.
5. Pulsa «Cambiar de organización».

### Agrupar los contactos que ya tenías
1. En Clientes › Organizaciones pulsa «Agrupar contactos existentes».
2. Propone organizaciones por la empresa escrita, por el dominio del correo o, para clientes sin empresa con contrato u oportunidad ganada, como Público en general.
3. Quita o corrige lo que no quieras y pulsa «Aplicar». Nada cambia antes.

### Importar desde CSV
1. Pulsa «Plantilla CSV» para bajar las columnas, llénala y súbela con «Importar».
2. Si ya existe (por id, RFC o nombre) se actualiza. En «contactos» van correos o teléfonos separados por «;».

## Dudas frecuentes
- ¿Pasan solas a prospecto o a cliente? Sí, si están encendidas en Ajustes › Casos y etapas › Parámetros de ventas › «Prospectos y clientes automáticos». Ya vienen encendidas: al crear una oportunidad (prospecto), al ganarla y al dar de alta un contrato (cliente). Nunca la regresan a prospecto.
- ¿Si elimino la organización? Sus contactos se quedan, solo sin organización. El ícono de eliminar (junto a «Editar») solo aparece a quien tiene el permiso «Borrar» (por omisión, el Administrador).
- ¿Dos con el mismo RFC? No se puede.

## Quién puede
Con Clientes en «Todo» o «Solo lo suyo» se crean, editan y cambian de etapa; con «Solo lo suyo» ves las que tienes a tu cargo y las de tus contactos. «Ve todo (sin cambiar)» solo consulta. Las reglas automáticas las cambia el Administrador.
