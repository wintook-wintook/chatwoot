---
key: contactos
title: Contactos y su ficha
areas: [clients]
keywords: [contacto, contactos, nuevo contacto, crear contacto, ficha del contacto, editar contacto, filtrar, filtro, segmento, editar segmento, eliminar filtro, etiqueta, etiquetas, atributos personalizados, importar contactos, exportar contactos, csv, fusionar, duplicado, eliminar contacto, nota ia, nota para ia, notas, agregar nota, delegar seguimiento, nueva nota privada, mensaje, ordenar, columnas, ver detalles, pidio no ser contactado, no contactar, correo reboto, portal del cliente, filtrar por evento, bloqueado, identificador]
pages: [contacts, contact, custom_attributes, labels]
sources:
  - app/javascript/dashboard/routes/dashboard/contacts/**/*.vue
  - app/javascript/dashboard/routes/dashboard/contacts/**/*.js
  - app/javascript/dashboard/routes/dashboard/conversation/contact/ContactInfo.vue
  - app/javascript/dashboard/routes/dashboard/conversation/contact/ContactForm.vue
  - app/javascript/dashboard/routes/dashboard/conversation/contact/CreateContact.vue
  - app/javascript/dashboard/routes/dashboard/conversation/contact/ContactOptOutField.vue
  - app/javascript/dashboard/i18n/locale/es/contact.json
  - app/controllers/api/v1/accounts/contacts_controller.rb
  - app/controllers/api/v1/accounts/actions/contact_merges_controller.rb
  - app/actions/contact_merge_action.rb
  - app/policies/contact_policy.rb
reviewed: 2026-11-14
---
## Para qué sirve
Un contacto es una persona con quien habla tu empresa. Su ficha junta sus datos, su organización, sus conversaciones, casos, cotizaciones, tareas, equipos, contratos, eventos y notas.

## Dónde está
- Clientes › Contactos: la lista, con el buscador «Buscar contactos» (escribe y pulsa «Buscar» o Enter). En el menú también salen «Segmentos» (filtros guardados) y «Etiquetas» (los contactos de cada etiqueta).
- Columnas de la lista: «Nombre», «Organización» (con su etapa, Prospecto o Cliente), «Dirección de correo electrónico», «Número de teléfono», «Empresa», «Ciudad», «País», «Perfiles sociales», «Última actividad» y «Creado en». Pulsa el título de una columna para ordenar (todas menos Organización y Perfiles sociales). Salen 15 por página.
- Al pulsar el nombre de un contacto se abre su ficha; «Ver detalles» abre un panel a un lado sin salir de la lista.

## Cómo se hace
### Crear un contacto
1. En Clientes › Contactos pulsa «Nuevo contacto» (o «Nuevo contacto» en la barra de arriba).
2. Escribe el «Nombre completo» (es lo único obligatorio) y, si quieres, la «Empresa».
3. En «Cómo contactarlo»: «Número de teléfono» (elige el código de país, por ejemplo +52; va en formato +52…) y «Dirección de correo electrónico».
4. En «Ubicación»: «País» y «Ciudad». Luego la «Descripción».
5. En «Redes sociales» usa «Agregar red» para las que tenga. Arriba puedes «Cambiar foto» (o «Quitar»).
6. Pulsa «Crear contacto». Si el teléfono o el correo ya son de otro contacto, te avisa y no lo crea.

### Editar un contacto
1. En su ficha pulsa «Editar».
2. Cambia los mismos datos del alta y pulsa «Guardar cambios».

### Filtrar y guardar el filtro
1. Pulsa «Filtrar» y elige el dato (Nombre, Correo electrónico, Número de teléfono, Identificador, País, Ciudad, Creado en, Última Actividad, Bloqueado, Evento o un atributo personalizado), la condición (por ejemplo «Igual a», «Contiene», «Está presente», «Es x días antes») y el valor.
2. «Evento» sirve para sacar a los que están (o no) en un evento con un estado, por ejemplo «Feria · Asistió».
3. Con un filtro puesto aparece «Guardar filtro»: ponle nombre y queda en el menú como segmento.
4. Al abrir un segmento salen «Editar segmento» (cambiar sus condiciones) y «Eliminar filtro» (borrar el segmento).
5. Con filtro o etiqueta aparece «Asignar Agente IA» para mandar a esos contactos con un agente IA.

### Usar la ficha
1. Arriba: correo, teléfono, «Responsable fijo», «Etiquetas» (con «Agregar») y los botones «Mensaje» (conversación nueva con el cliente), «Nueva nota privada» (conversación interna, el cliente no la ve) y «Editar». En «⋯» están «Fusionar contacto» y «Eliminar contacto».
2. Si el cliente pidió no ser contactado sale el aviso «Pidió no ser contactado» (con «Quitar» para volver a contactarlo); si su correo rebotó sale «Su correo rebotó» (se quita al corregir el correo).
3. A la izquierda: «Delegar seguimiento» (un agente IA le da seguimiento por ti), «Portal del cliente» (su enlace; si tiene organización es el de la organización), su «Organización» y sus «Datos»: Empresa, Ubicación, Alta, Último contacto, Descripción y los atributos personalizados.
4. Pestañas: Resumen, Conversaciones, Casos, Cotizaciones, Tareas, Equipos, Contratos, Eventos y Notas. Casos, Cotizaciones, Tareas y Equipos solo salen si tu empresa usa casos.
5. El Resumen muestra «Conversaciones abiertas», «Casos abiertos», «Oportunidades en curso», la «Próxima tarea» y la «Actividad reciente».
6. Para crear algo para el contacto usa su pestaña: «Nuevo caso» (en Casos, con «Ver también los cerrados»), «+ Cotización», «Nuevo equipo» y «Nuevo mantenimiento» (en Equipos) o «Nuevo contrato». En Tareas eliges «Pendientes» o «Todas».
7. En Notas escribe en «Agregar una nota» y pulsa «Agregar» (o Shift + Enter). Cada nota tiene «Editar nota» y «Eliminar nota».
8. «Regresar» (arriba) te devuelve a la pantalla de donde venías.

### Fusionar un duplicado
1. En la ficha del contacto que sobra pulsa «⋯» › «Fusionar contacto».
2. En «Contacto que se queda» busca el contacto que se mantiene y pulsa «Fusionar contactos».
3. El contacto donde estabas se elimina y todo lo suyo pasa al que se queda: conversaciones, mensajes, notas, casos, tareas, cotizaciones, contratos, equipos, mantenimientos, asistencias a eventos y seguimientos. También los datos que le falten, incluido el responsable fijo y la organización (si los dos tienen un mismo dato, gana el del que se queda).
4. Si los dos estaban en el mismo evento o campaña, se conserva solo el registro del que se queda.
5. Fusionar pide poder editar en Clientes; con «solo lo suyo» solo puedes fusionar contactos que te tocan.

### Marcar la nota IA
1. Abre el panel del contacto («Ver detalles» en la lista, o el panel del contacto en una conversación) y pulsa el ícono «Notas».
2. En la nota que quieras pulsa «Marcar como nota para IA». Solo hay una por contacto: lo que diga la usa el agente de «Delegar seguimiento».

### Importar y exportar
1. «Importar»: sube un «Archivo CSV» (hay «Descargar un ejemplo de CSV.») y pulsa «Importar». Te llega un correo cuando termina.
2. «Exportar»: confirma con «Sí, exportar». Si tienes un filtro puesto exporta solo los filtrados; si no, todos. Te llega un correo con el archivo.

## Límites
- «Importar», «Exportar» y «Eliminar contacto» solo los ve el Administrador.
- El teléfono debe llevar el código de país (+52…) o quedar vacío.

## Dudas frecuentes
- ¿Dónde se crean los atributos personalizados y las etiquetas? En Catálogos › Atributos personalizados y Catálogos › Etiquetas (administrador). Los valores se llenan en «Datos» de la ficha.
- ¿Cómo lo ligo a una empresa? En la ficha, bloque «Organización». Ver la guía «Organizaciones».
- No encuentro a un contacto: con «Solo lo suyo» en Clientes solo ves los tuyos (ver abajo). Si la búsqueda no da nada sale «No se encontraron contactos que coincidan con tu búsqueda».

## Quién puede
Con Clientes en «Todo» ves y cambias todos los contactos; con «Solo lo suyo», los que tienen una conversación o un caso tuyo, de los que eres responsable fijo o de las organizaciones a tu cargo; con «Ve todo (sin cambiar)» solo consultas. «Fusionar contacto» pide «Todo» o «Solo lo suyo». «Eliminar contacto», «Importar» y «Exportar» solo los tiene el Administrador. Cambiar el responsable fijo pide el permiso «Asignar a otra persona».
