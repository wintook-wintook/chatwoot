---
key: tipos_caso
title: Tipos de caso, clasificaciones y políticas SLA
areas: [settings]
keywords: [tipo de caso, tipos de caso, nuevo tipo, clase de caso, cambiar de clase, soporte, ventas, orden de trabajo, proyecto, prefijo, prefijo del folio, folio, portal, publico, privado, itil, campos, campos personalizados, agregar campo, columnas, etapas, estados, tablero, tareas de la etapa, pasa sola, trabajo en campo, fotos antes y despues, conformidad, reporte al cliente, clasificacion, clasificaciones, servicios afectados, categorias, subcategoria, aplica a, sla, politicas sla, politica, primera respuesta, resolucion, horario laboral, naturaleza itil, incidente, retirado]
pages: [case_types, classifications, sla_policies]
sources: [app/javascript/dashboard/views/gestorTickets/TicketTypes.vue, app/javascript/dashboard/views/gestorTickets/TicketTypeDetail.vue, app/javascript/dashboard/views/gestorTickets/typeDetail/*.vue, app/javascript/dashboard/views/gestorTickets/Classification.vue, app/javascript/dashboard/views/gestorTickets/SlaConfig.vue, app/controllers/api/v1/accounts/case_*_controller.rb, app/models/case_type*.rb, app/models/case_sla_policy.rb, app/services/cases/type_class_change.rb]
reviewed: 2026-11-14
---
## Para qué sirve
- Tipos de caso: cada caso se clasifica con un tipo (por ejemplo «Postventa»). El tipo decide su clase (Soporte, Ventas, Orden de trabajo o Proyecto), su prefijo de folio, los campos que se piden y las columnas (etapas) de su tablero.
- Clasificaciones: los «Servicios afectados» y las «Categorías» (con subcategorías) con que se clasifican los casos.
- Políticas SLA: los tiempos objetivo de primera respuesta y de resolución de los casos de Soporte.

## Dónde está
- Catálogos › Tipos de caso. Al hacer clic en un tipo se abre su detalle con las pestañas «Campos», «Columnas» y, en las órdenes de trabajo, «Trabajo en campo».
- Catálogos › Clasificaciones (la pantalla dice «Clasificación»), con las pestañas «Servicios afectados» y «Categorías».
- Catálogos › Políticas SLA.

## Cómo se hace
### Crear un tipo de caso
1. Entra a Catálogos › Tipos de caso y pulsa «+ Nuevo tipo».
2. Escribe el «Nombre» (obligatorio, por ejemplo «Postventa»).
3. En «Clase de caso» elige «Soporte» (viene marcada), «Ventas», «Orden de trabajo» o «Proyecto». Solo salen las clases activas en tu cuenta.
4. Elige el «Color» y, si quieres, el «Prefijo del folio» (hasta 8 letras; vacío = se arma solo con el nombre). El prefijo queda fijo en cuanto el tipo tiene su primer caso.
5. Marca «Visible en el portal del cliente» si debe salir en el formulario público del portal (solo aplica a Soporte).
6. Marca «Maneja ITIL» si quieres las columnas ITIL (13 estados, 6 etapas); sin marcar trae 5 etapas simples. Se pueden cambiar después.
7. Pulsa «+ Nuevo tipo» abajo para guardarlo.

En la lista se ven «Nombre», «Clase», «Prefijo», «Campos», «Columnas» y «Portal» (botón «Público» / «Privado» para cambiarlo ahí mismo). Arriba se filtra por clase: «Todas», «Soporte», «Ventas», «Orden de trabajo», «Proyecto». Cada renglón tiene editar, «Cambiar de clase», borrar y «Abrir».

### Cambiar un tipo de clase
1. En la lista pulsa «Cambiar de clase» en el renglón del tipo.
2. En «Nueva clase» elige la clase y pulsa «Cambiar de clase».
3. Si el tipo no tiene casos, cambia directo. Si tiene casos, esos casos se quedan en la clase de antes con todo igual; el tipo viejo queda como «… (anterior)» con la marca «Retirado» y se crea uno nuevo con el mismo nombre, prefijo y campos en la clase nueva.

### Agregar campos a un tipo
1. Abre el tipo y entra a la pestaña «Campos». Pulsa «Agregar campo».
2. Escribe la «Etiqueta» y la «Clave» (minúsculas, números y guion bajo; no se puede cambiar después).
3. Elige el «Tipo de campo»: «Texto», «Número», «Fecha», «Lista» o «Casilla». En «Lista» escribe las «Opciones» separadas por comas.
4. Marca «Obligatorio» si se debe llenar siempre y pulsa «Agregar».
Estos campos se piden al crear o editar un caso de ese tipo.

### Armar las columnas (etapas) del tablero
1. Abre el tipo y entra a la pestaña «Columnas».
2. «Agregar columna»: escribe el «Nombre», el «Color» y marca en «Estados que agrupa» uno o varios: Nuevo, Clasificado, Asignado, En diagnóstico, En proceso, En espera del cliente, En espera de tercero, En espera interna, Escalado, Resuelto, Validando con cliente, Cerrado, Cancelado.
3. Arrastra las filas para cambiar el orden.
4. Los 13 estados deben quedar cubiertos; si falta alguno sale «Estados sin cubrir» con el botón «Asignar a la última columna».
5. Pulsa «Guardar columnas». Nada se guarda hasta pulsarlo («Tienes cambios sin guardar.»).

### Poner tareas a una etapa
1. En «Columnas» pulsa «Tareas (…)» de la columna (primero guarda las columnas).
2. En «Al terminar las tareas obligatorias» elige «Sugerir pasar a la siguiente etapa», «Pasar sola a la siguiente etapa» o «No hacer nada».
3. «Agregar tarea»: «Tarea», «Descripción», «Vence» (horas o días después de entrar a la etapa), «Prioridad», «Quién la hace» («Responsable del caso», «Persona fija» o «Equipo»), «Minutos estimados» y «Obligatoria para avanzar a la siguiente etapa».
4. Las tareas se crean solas cuando un caso entra a esa etapa. Cambiarlas no toca los casos que ya existen.

### Ajustar el trabajo en campo (órdenes de trabajo)
En el detalle de un tipo de Orden de trabajo, pestaña «Trabajo en campo»: «Se ejecuta en campo», «Pide fotos de antes y después para terminar», «Pide la conformidad de quien recibió para terminar» y «Reporte al cliente» («Enviar solo al terminar» o «Revisar antes de enviar»). Se guarda al cambiarlo.

### Dar de alta servicios y categorías
1. Entra a Catálogos › Clasificaciones.
2. En «Servicios afectados» pulsa «+ Nuevo servicio»; en «Categorías», «+ Nueva categoría». Para una subcategoría pulsa «+» en el renglón de la categoría.
3. Escribe el «Nombre», elige en «Aplica a» «Todos los tipos» o un tipo de caso (las subcategorías heredan el de su categoría), el color (en servicios) y deja «Activo».
4. Pulsa «Guardar». El botón «Activo» / «Inactivo» del renglón lo prende o apaga.
Arriba, «Aplica a:» filtra: «Todo», «Solo globales (todos los tipos)» o un tipo.

### Crear una política SLA
1. Entra a Catálogos › Políticas SLA y pulsa «+ Nueva política».
2. Elige la «Prioridad», la «Naturaleza ITIL» (Incidente, Solicitud de servicio, Problema, Cambio, Consulta o «Cualquiera») y el «Tipo de caso» (o «Cualquiera»).
3. Escribe «1ª respuesta (min)» y/o «Resolución (min)»: al menos uno.
4. Marca «Contar solo horario laboral (working hours)» si aplica y deja «Activa».
5. Pulsa «Guardar». Gana la política más específica; no puede haber dos para la misma prioridad + tipo + naturaleza.

## Límites
- Borrar un tipo deja sus casos sin tipo y también borra sus campos y columnas. Borrar un campo lo quita de los casos de ese tipo.
- Borrar una columna o una tarea de etapa no pide confirmación.
- Borrar un servicio o categoría deja los casos sin ese valor; borrar una categoría borra también sus subcategorías.
- Borrar una política SLA hace que esos casos usen el SLA por defecto.
- El SLA solo se usa en casos de Soporte. El portal también es solo para Soporte.

## Dudas frecuentes
- ¿Puedo cambiar la clase de un tipo? Al editarlo no; usa «Cambiar de clase» en la lista.
- ¿Por qué no puedo cambiar el prefijo? El tipo ya tiene casos con folio.
- Si no hay tipos, servicios o políticas, la cuenta trae unos de inicio que puedes editar.

## Quién puede
Solo el Administrador ve y cambia estas pantallas.
