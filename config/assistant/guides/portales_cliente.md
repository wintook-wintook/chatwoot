---
key: portales_cliente
title: Portales del cliente
areas: [service]
keywords: [portal, portales, portal del cliente, pagina de soporte, abrir solicitud, consultar estado, folio, cliente abre ticket, formulario publico, sin iniciar sesion, enlace del portal, slug, canal destino, acuse, plantilla whatsapp, tipos publicos, tu servicio, confirmar visita, calificar servicio]
pages: [cases, case, client_portals, help_center]
---
## Para qué sirve
Un portal del cliente es una página pública de soporte de tu empresa. Ahí tus clientes, sin usuario ni contraseña, abren una solicitud y reciben un folio, y después consultan en qué va. Cada solicitud llega como un caso de Soporte con su conversación.

## Dónde está
- Servicio › Portales del cliente.
- Los tipos de caso que se ofrecen en el portal se marcan en Catálogos › Tipos de caso con «Visible en el portal del cliente» (solo los de Soporte).

## Cómo se hace
### Crear un portal
1. Entra a Servicio › Portales del cliente y pulsa «+ Nuevo portal».
2. Escribe el «Nombre» y, si quieres, el «Slug (URL)»: la dirección queda como /portal/slug. Si lo dejas vacío, se genera del nombre.
3. Elige el «Idioma» y el «Canal destino»: dónde nacen las conversaciones y por dónde sale el acuse con el folio (API, Email o WhatsApp). Si no eliges, se usa uno de tipo API que se crea solo.
4. Si el canal es WhatsApp, escribe el nombre y el idioma de la plantilla aprobada para el acuse; el folio va como primer dato de la plantilla.
5. Escribe un «Texto de bienvenida» (opcional), deja marcado «Portal activo» y pulsa «Crear».
6. En la lista, copia la URL con el botón de copiar y compártela con tus clientes (en tu sitio, correo o redes).

### Elegir qué puede pedir el cliente
1. Entra a Catálogos › Tipos de caso.
2. Edita cada tipo de Soporte que quieras ofrecer y marca «Visible en el portal del cliente».
3. Si ningún tipo está marcado, el portal te avisa y el formulario saldrá vacío; usa «Configurar tipos».

## Qué ve el cliente
- La página de inicio dice «¿En qué podemos ayudarte?» con dos opciones: «Abrir una solicitud» y «Consultar estado».
- Abrir una solicitud: escribe su nombre, su correo o WhatsApp (al menos uno), el tipo de solicitud, los campos adicionales del tipo, asunto, mensaje y adjuntos, y pulsa «Enviar solicitud». Ve su folio en pantalla y le llega el acuse por el canal del portal.
- Consultar estado: escribe su correo o WhatsApp y el folio. Ve el estado, el tipo, la prioridad, la fecha y el «Avance del ticket». Nunca ve notas internas ni datos del SLA.

## Dudas frecuentes
- ¿Quién atiende lo que llega por el portal? Las reglas de automatización (Ajustes › Casos y etapas › Reglas de automatización) deciden el responsable; el origen del caso es Web.
- ¿Se puede consultar una oportunidad desde el portal? No, solo casos de Soporte.
- Para pausar un portal, edítalo y quita «Portal activo». Si lo eliminas, los clientes ya no podrán entrar a esa página.
- Las órdenes de trabajo tienen además su propio enlace, «Portal del cliente», en la orden (Reporte de servicio › Copiar enlace). Ahí el cliente ve en qué va su servicio, confirma la visita o pide otra fecha, ve el reporte y sus cotizaciones, y, al terminar, califica de 1 a 5 estrellas. Ese enlace también va en el mensaje de «Voy en camino».
- El Centro de ayuda (Servicio › Centro de Ayuda) es otra cosa: artículos para que el cliente resuelva solo.

## Quién puede
Solo el Administrador crea, edita y elimina portales, y marca los tipos visibles en el portal. El cliente no necesita usuario.
