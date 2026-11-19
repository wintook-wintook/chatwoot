---
key: centro_ayuda
title: Centro de ayuda (artículos para tus clientes)
areas: [service]
keywords: [centro de ayuda, help center, articulo, articulos, nuevo articulo, publicar articulo, borrador, archivado, archivar, mis articulos, categoria, categorias, nueva categoria, idioma, idiomas, agregar idioma, portal de ayuda, nuevo portal, dominio personalizado, slug, logo, color del tema, texto del encabezado, autoservicio, preguntas frecuentes, insertar articulo, meta titulo, seo]
pages: [help_center]
sources: [app/javascript/dashboard/routes/dashboard/helpcenter/**/*.vue, app/javascript/dashboard/routes/dashboard/helpcenter/helpcenter.routes.js, app/javascript/dashboard/i18n/locale/es/helpCenter.json]
reviewed: 2026-11-14
---
## Para qué sirve
El Centro de ayuda es una página pública con artículos (cómo se usa, preguntas frecuentes, políticas) para que tus clientes resuelvan solos sin escribirte. Puedes tener varios portales, cada uno con sus categorías y sus idiomas. No es lo mismo que los Portales del cliente, donde el cliente abre y consulta solicitudes.

## Dónde está
- Agentes IA › Centro de Ayuda, justo debajo de «Bases de conocimiento» (sus artículos son una de las fuentes que leen los agentes: «Artículos de ayuda» en «Qué sabe»). Adentro tiene su propio menú: «Todos los Artículos», «Mis Artículos», «Borrador», «Archivado», «Configuración» y la lista de categorías.
- La página pública queda en la dirección de la plataforma con /hc/slug-del-portal/idioma (o en tu dominio personalizado).

## Cómo se hace
### Crear un portal
1. En Agentes IA › Centro de Ayuda pulsa el botón para cambiar de portal (arriba del menú del Centro de ayuda) › «Configuraciones del portal». Ahí ves «Portales» y pulsas «Nuevo Portal».
2. En «Información del centro de ayuda» sube el «Logo» (sale en el encabezado), escribe el «Nombre», el «Slug» (para la dirección) y, si quieres, el «Dominio Personalizado». Pulsa «Crear configuraciones básicas del portal».
3. En «Personalización del centro de ayuda» elige el «Color del tema del portal» y escribe el «Título de la Página», el «Texto del Encabezado» y el «Enlace de la Página de Inicio» (para regresar a tu sitio). Pulsa «Actualizar configuraciones del portal».
4. Pulsa «Ir a la página de todos los portales».

### Escribir y publicar un artículo
1. Pulsa «Nuevo Artículo».
2. Escribe el título («El título del artículo va aquí») y el contenido. Puedes subir imágenes (jpg, jpeg o png). Se guarda solo: arriba dice «Guardando...» y «Guardado».
3. Con «Abrir barra lateral» llegas a «Configuraciones del Artículo»: «Categoría», «Autor», «Meta título», «Meta descripción» y «Meta etiquetas» (separadas por coma, para buscadores).
4. Pulsa «Vista previa» para verlo como el cliente y «Publicar» para que salga en la página pública.
Mientras no lo publiques queda en «Borrador».

### Archivar o eliminar un artículo
1. Abre el artículo.
2. En el menú junto a «Publicar» elige «Mover a archivados», o en la barra lateral «Archivar artículo».
3. Para borrarlo, en la barra lateral pulsa «Eliminar artículo» y confirma con «Sí, Eliminar».

### Organizar con categorías
1. Entra a «Configuración» › pestaña «Categorías» y pulsa «Nueva categoría».
2. Elige el ícono y escribe el «Nombre», el «Slug» y la «Descripción».
3. Pulsa «Crear categoría». Desde la tabla puedes «Editar categoría» o «Eliminar categoría».
4. Al escribir un artículo, elige su «Categoría» en la barra lateral.

### Publicar en varios idiomas
1. Entra a «Configuración» › pestaña «Idiomas» y pulsa «Agregar idioma».
2. Elige el «Idioma» y pulsa «Crear idioma».
3. Cada idioma tiene sus artículos y sus categorías. Cambia de idioma arriba de la lista de artículos.
4. En la lista de idiomas puedes marcar uno como «Predeterminado» o eliminarlo.

### Mandar un artículo en una conversación
1. Liga el Centro de ayuda a la bandeja: Ajustes › Bandejas › la bandeja › «Centro de ayuda».
2. Al contestar, pulsa el ícono «Insertar artículo desde el Centro de Ayuda», busca el artículo y pulsa «Insertar enlace».

## Dudas frecuentes
- La lista de artículos muestra Título, Categoría, Vistas, Estado y Última edición.
- En «Configuraciones del portal» cada portal tiene «Visitar sitio» (abre su página pública), «Configuraciones», «Agregar idioma» y «Eliminar».
- Para cambiar el nombre, el slug, el logo o los colores, entra a «Configuración» y usa las pestañas «Información básica» (botón «Actualizar configuraciones básicas») y «Personalización del portal».
- Si eliminas un portal («Sí, eliminar portal»), su página pública deja de existir.
- No confundas el Centro de ayuda con Servicio › Portales del cliente: ahí el cliente abre solicitudes y consulta su folio.

## Quién puede
Agentes IA › Centro de Ayuda solo le aparece en el menú al Administrador, que crea portales, idiomas, categorías y artículos. Insertar artículos al contestar lo puede hacer cualquiera que conteste conversaciones en una bandeja con Centro de ayuda ligado.
