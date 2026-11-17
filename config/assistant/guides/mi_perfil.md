---
key: mi_perfil
title: Mi perfil (Configuración de Perfil)
areas: []
keywords: [mi perfil, perfil, configuracion de perfil, mi usuario, mi nombre, nombre para mostrar, foto, foto de perfil, avatar, correo, cambiar contrasena, contrasena, firma, firma de mensaje, enter, ctrl enter, tecla para enviar, apariencia, modo oscuro, modo claro, tema de color, al iniciar sesion, pagina de inicio, notificaciones de audio, sonido, tono de alerta, preferencias de notificacion, notificaciones por correo, notificaciones push, token de acceso, api, disponibilidad, en linea, ocupado, desconectado, cerrar sesion, cambiar cuenta, atajos de teclado]
pages: [profile]
sources:
  - app/javascript/dashboard/routes/dashboard/settings/profile/*.vue
  - app/javascript/dashboard/components/layout/sidebarComponents/OptionsMenu.vue
reviewed: 2026-11-14
---
## Para qué sirve
Tu perfil es lo tuyo como usuario: tu nombre, foto, correo y contraseña, la firma de tus mensajes, cómo se ve la plataforma, a qué pantalla entras y qué avisos te llegan. Lo que cambies aquí solo te afecta a ti.

## Dónde está
- Abajo a la izquierda, en tu foto (o tus iniciales): se abre un menú con tu «Disponibilidad», «Cambiar Cuenta» (si estás en varias empresas), «Atajos de Teclado», «Configuración de Perfil», «Cambiar Apariencia» y «Cerrar Sesión».
- «Configuración de Perfil» abre la página, con estas secciones en orden: foto y datos, «Usar Dali en mi teléfono», «Firma de mensaje personal», «Tecla de acceso rápido para enviar mensajes», «Apariencia», «Al iniciar sesión, ir a», «Contraseña», «Notificaciones de Audio», «Preferencias de notificación» y «Token de Acceso».
- También se lo puedes pedir a Dali: «abre mi perfil».

## Cómo se hace
### Cambiar tu foto, nombre o correo
1. En «Foto de Perfil» toca la foto para subir una imagen, o elimínala.
2. Cambia «Tu nombre completo», «Nombre para mostrar» (el que ven los clientes en las conversaciones) o «Tu dirección de correo electrónico».
3. Pulsa «Actualizar Perfil». Si cambiaste el correo, te pide volver a iniciar sesión con el nuevo.

### Cambiar tu contraseña
1. En «Contraseña» escribe «Contraseña actual», «Nueva contraseña» (6 caracteres o más) y «Confirmar nueva contraseña».
2. Pulsa «Cambiar contraseña».

### Tu firma en los mensajes
1. En «Firma de mensaje personal» escribe tu firma; puede llevar una imagen.
2. Pulsa «Guardar firma de mensaje». Sale al final de los mensajes que mandas desde cualquier bandeja.

### Con qué tecla se envían los mensajes
En «Tecla de acceso rápido para enviar mensajes» elige «Enter (↵)» o «Cmd/Ctrl + Enter (⌘ + ↵)». Se guarda al elegir.

### Cómo se ve la plataforma
1. En «Apariencia» elige el «Modo»: «Claro», «Oscuro» o «Sistema».
2. Elige el «Tema de color»: «De la empresa», «Predeterminado», «Cálido», «Bosque», «Índigo», «Sepia», «Alto contraste», «Violeta», «Turquesa», «Rosa» o «Grafito». La «Vista previa» te muestra cómo queda.
3. Se guarda en tu usuario: te sigue en cualquier navegador.

### A qué pantalla entras al iniciar sesión
En «Al iniciar sesión, ir a» elige «Inicio (Mi resumen)», «Conversaciones» o «Mi día». Sale «Listo: la próxima vez que entres irás ahí». Esta sección solo aparece si tu empresa usa casos.

### Qué avisos te llegan
1. «Notificaciones de Audio»: en «Eventos de alerta para conversaciones:» elige «Ninguno», «Asignado» o «Todos»; el «Tono de alerta:» y las «Condiciones de alerta:» (solo si la ventana no está activa; repetir cada 30 s hasta que leas las asignadas).
2. «Preferencias de notificación»: una tabla con cada «Tipo de notificación» (conversación nueva, asignada a ti, te mencionaron, mensaje nuevo en una conversación tuya o en la que participas y, si tu empresa usa SLA, los SLA no cumplidos) y dos columnas: «Correo Electrónico» y «Notificación Push». Marca lo que quieras recibir; se guarda al marcar. En el celular salen como dos listas: «Notificaciones por Correo Electrónico» y «Notificaciones Push».

### Usar Dali en el teléfono
En «Usar Dali en mi teléfono» pulsa «Mostrar código QR». Los pasos completos están en la guía «Dali en el teléfono».

## Dudas frecuentes
- ¿Para qué es el «Token de Acceso»? Para conectar otro sistema por la API; «Copiar» lo copia. No lo compartas.
- ¿Cómo me pongo «Ocupado»? En el menú de tu foto, en «Disponibilidad»: «En línea», «Ocupado» o «Desconectado».
- No veo «Configuración de Perfil» en el menú: tu empresa la ocultó para quienes no son administradores.
- No me deja cambiar el correo o la contraseña: la plataforma tiene bloqueado ese cambio; pídeselo al administrador.
- El nombre de la empresa, su logo y el nombre del asistente no están aquí: son de Ajustes › Configuración de Cuenta (administrador).

## Quién puede
Cada usuario cambia solo su propio perfil. Si la empresa activó ocultar el perfil a los agentes, solo los administradores lo abren.
