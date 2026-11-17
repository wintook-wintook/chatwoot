---
key: organizaciones
title: Organizaciones, prospectos y clientes
areas: [clients]
keywords: [organizacion, portal del cliente, eliminar organizacion, responsable de la organizacion, al enviar una cotizacion, al aceptarse una cotizacion, organizaciones, empresa, prospecto, prospectos, cliente, marcar como cliente, regresar a prospecto, publico en general, rfc, razon social, convertir en prospecto, ligar contacto, quitar de la organizacion, cambiar de organizacion, sustituto, agrupar contactos, importar organizaciones, csv, prospectos y clientes automaticos, bitacora, etapa]
pages: [organizations, organization, contact, commercial_settings, clients_dashboard]
sources:
  - app/javascript/dashboard/views/organizations/*.vue
  - app/javascript/dashboard/views/organizations/*.js
  - app/javascript/dashboard/routes/dashboard/contacts/components/ContactOrganization.vue
  - app/javascript/dashboard/routes/dashboard/contacts/components/ChangeOrganizationModal.vue
  - app/javascript/dashboard/i18n/locale/es/organizations.json
  - app/controllers/api/v1/accounts/organizations_controller.rb
  - app/models/organization.rb
  - app/services/organizations/*.rb
reviewed: 2026-11-14
---
## Para qué sirve
Una organización es la empresa (o el público en general) detrás de tus contactos. Tiene etapa, Prospecto o Cliente, y tipo: «Empresa» (se le factura, con RFC) o «Público en general» (sin factura). Cada contacto pertenece a una sola organización; sin ella es solo un contacto.

## Dónde está
- Clientes › Organizaciones: pestañas Prospectos (abre aquí), Clientes y Todas, con cuántas hay en cada una; el buscador «Buscar por nombre, RFC o dominio» y el filtro «Empresas y público en general» / Empresa / Público en general.
- Columnas de la lista: «Nombre» (con el tipo y el giro), «Etapa», «RFC», «Contactos» (cuántos tiene) y «Responsable». Salen 50 por página; pulsa una para abrirla.
- La página de cada organización: «Datos» (RFC, Giro, Sitio web, Dominio de correo, Teléfono, Dirección, Responsable, «Prospecto desde», «Cliente desde» y Notas; solo salen los que tienen algo), su «Portal del cliente», sus «Contactos», sus Oportunidades, Casos, Cotizaciones, Contratos y Equipos (de todos sus contactos), sus «Tareas» y la «Bitácora» (cambios de etapa y contactos que llegaron o se fueron).
- En la ficha del contacto, el bloque «Organización».

## Cómo se hace
### Crear una organización
1. En Clientes › Organizaciones pulsa «Nueva organización».
2. Elige el «Tipo»: Empresa o Público en general.
3. Escribe el «Nombre o razón social» (en Público en general dice «Nombre»; es obligatorio) y elige la «Etapa» (Prospecto o Cliente). La etapa solo se elige al crearla; después se cambia con los botones de la página.
4. Si es Empresa: «RFC» (opcional, se puede completar al facturar), «Giro», «Sitio web» y «Dominio de correo» (ej. empresa.com).
5. «Teléfono», «Responsable» (o «Sin responsable»), «Dirección» y «Notas». Pulsa «Guardar».

### Editar o eliminar
1. En la página de la organización pulsa «Editar», cambia lo que quieras y «Guardar».
2. Para eliminarla usa el ícono de basura junto a «Editar» y confirma. Sus contactos se quedan, solo sin organización.

### Convertir un contacto en prospecto
1. Abre la ficha del contacto. En «Organización» dice «Sin organización: es un contacto.».
2. Pulsa «Convertir en prospecto»: se llena con la empresa que tiene escrita (o con su nombre, como Público en general). Revisa y guarda.
3. Si la empresa ya existe, usa «Ligar a una organización existente» y búscala.

### Cambiar la etapa
1. En la página de la organización pulsa «Marcar como cliente» o «Regresar a prospecto».
2. Solo cambia la etapa; queda en la Bitácora con quién lo hizo.

### Agregar o quitar contactos
1. En la página de la organización, en «Ligar un contacto», busca y elige al contacto. Solo se puede ligar uno que no tenga organización; si ya es de otra, te avisa que uses «Cambiar de organización» en su ficha.
2. Para quitarlo pulsa la «x» («Quitar de la organización») junto a su nombre. Lo suyo que ya está en la organización se queda ahí.
3. Desde la ficha del contacto también puedes usar «Quitar de la organización» en el bloque «Organización».

### Cambiar a un contacto de organización
1. En la ficha del contacto, bloque «Organización», pulsa «Cambiar de organización».
2. «1. ¿A qué organización se va?»: elige la nueva, o «A ninguna (se queda sin organización)».
3. «2. ¿Pasar también lo suyo?»: te dice cuántas oportunidades y casos, cotizaciones, contratos, equipos, mantenimientos y tareas tiene. Elige «Sí, pasar todo a la nueva» (estaba en la equivocada) o «No, que todo se quede» (se cambió de empresa).
4. Si se queda: en «3. ¿Quién queda … en lugar de …?» elige un contacto o «+ Dar de alta uno nuevo» (Nombre, Correo, Teléfono). Esa persona queda como contacto de lo que sigue vivo (casos y oportunidades abiertos, cotizaciones sin decidir, contratos, equipos, mantenimientos); lo cerrado se queda con quien lo atendió.
5. Pulsa «Cambiar de organización».

### Agrupar los contactos que ya tenías
1. En Clientes › Organizaciones pulsa «Agrupar contactos existentes».
2. Propone organizaciones para los contactos sin organización: «Por la empresa escrita en el contacto», «Por el dominio de su correo» o «Cliente sin empresa (tiene contrato u oportunidad ganada)» (como Público en general). Si la organización «ya existe», se ligan a ella.
3. Quita o corrige lo que no quieras y pulsa «Aplicar». Nada cambia antes. Si no hay nada que proponer, te lo dice.

### Importar desde CSV
1. Pulsa «Plantilla CSV» para bajar las columnas, llénala y súbela con «Importar».
2. Columnas: id, nombre, tipo (empresa o publico_en_general), etapa (prospecto o cliente), rfc, giro, sitio_web, dominio_correo, telefono, direccion, responsable (su correo), notas y contactos (correos o teléfonos separados por «;»).
3. Si ya existe (por id, RFC o nombre) se actualiza. Al terminar te dice cuántas nuevas y cuántas actualizadas, y la primera fila con error.

## Dudas frecuentes
- ¿Pasan solas a prospecto o a cliente? Sí, con las reglas de Ajustes › Casos y etapas › Parámetros de ventas › «Prospectos y clientes automáticos». A prospecto: «Al crear una oportunidad (incluye «Convertido» en el Embudo de contactos)» y «Al enviar una cotización»; si el contacto no tiene organización, se le crea. A cliente: «Al ganar una oportunidad», «Al dar de alta un contrato» y «Al aceptarse una cotización». Vienen encendidas la de oportunidad, la de ganar y la de contrato; las de cotización vienen apagadas. Nunca la regresan a prospecto y queda en la Bitácora con el motivo.
- ¿Si elimino la organización? Sus contactos se quedan, solo sin organización. El ícono de eliminar (junto a «Editar») solo aparece a quien puede editar en Clientes y además tiene el permiso «Borrar» (por omisión, el Administrador).
- ¿Dos con el mismo RFC? No se puede.

## Quién puede
Con Clientes en «Todo» o «Solo lo suyo» se crean, editan, importan, agrupan y cambian de etapa (los botones «Agrupar contactos existentes», «Plantilla CSV», «Importar», «Nueva organización», «Marcar como cliente», «Editar» y «Ligar un contacto» solo salen así); con «Solo lo suyo» ves las que tienes a tu cargo y las de tus contactos. «Ve todo (sin cambiar)» solo consulta. Las reglas automáticas las cambia el Administrador.
