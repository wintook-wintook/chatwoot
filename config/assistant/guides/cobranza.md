---
key: cobranza
title: Cobranza (cartera y agente de cobranza)
areas: [sales, ai_agents]
category: Ventas
keywords: [cobranza, cobrar, cartera, cuentas por cobrar, saldo, saldos, vencido, vencidas, facturas vencidas, antiguedad de saldos, subir cartera, excel de cobranza, plantilla de cartera, corte, promesa de pago, promesas, ya pague, comprobante de pago, validar comprobante, aclaracion, factura mal, agente de cobranza, cobrar solo, recordatorio de pago, datos para pagar, clabe, por ligar, ligar cliente, estado de cuenta, resumen de saldo, cobrador, microsip, aspel, contpaqi, sistema administrativo]
pages: [collections, ready_agents, organizations, contacts]
sources: [app/javascript/dashboard/views/collections/*.vue, app/controllers/api/v1/accounts/collections_controller.rb, app/services/receivables/*.rb, app/services/motor2/functions/collections.rb, app/services/motor2/skills/collections.rb, app/javascript/dashboard/views/readyAgents/CollectionsAgentModal.vue]
reviewed: 2026-11-23
---
## Para qué sirve
Cobranza junta tu cartera por cobrar y un agente de IA que le cobra a cada cliente: le recuerda su pago, le da el resumen de lo que debe y los datos para pagar, registra si promete pagar o si ya pagó, y pasa al cobrador lo que necesita una persona.
- La cartera entra por «cortes»: hoy subes un Excel o CSV; después se conectará a tu sistema administrativo (Microsip, Aspel SAE, CONTPAQi u otro) y se actualizará solo. El agente trabaja igual con cualquiera de las dos.
- Cada corte reemplaza al anterior: la factura que ya no viene, o viene en 0, se toma como pagada; si bajó su saldo, es un abono.

## Dónde está
- La cartera: Ventas › Cobranza (solo administradores), con las pestañas Tablero, Subir la cartera, Clientes, Promesas de pago, Comprobantes y Cortes.
- El agente: Agentes IA › Agentes listos › Cobranza.

## Cómo se hace
### Subir la cartera
1. En Ventas › Cobranza › «Subir la cartera», descarga la plantilla (o usa tu propio Excel).
2. Una fila por cada factura con saldo. Columnas: Clave cliente, Cliente*, RFC, Contacto, WhatsApp, Correo, Folio*, Fecha factura, Vencimiento* (dd/mm/aaaa), Total, Saldo*, Moneda, Cobrador (el correo del usuario). Con * son obligatorias; para cobrarle hace falta su WhatsApp o su correo.
3. Sube el archivo (.xlsx o .csv). Si es tu propio Excel, elige qué columna es cuál una sola vez: se recuerda para la próxima.
4. Revisa la vista previa: cuántas filas están listas y por qué se omiten las demás, el total, la antigüedad de saldos (por vencer, 1–15, 16–30, 31–60, 61–90 y más de 90 días) y qué cambia contra el corte anterior (nuevas, abonos, pagadas, clientes por ligar).
5. Pulsa «Aplicar el corte».

### Ligar a los clientes
- Al aplicar el corte, cada cliente se busca solo en Kontrolya por su WhatsApp, su correo o el RFC de su organización.
- Los que no se encuentran quedan «Por ligar» (pestaña Clientes): «Crear» los da de alta como organización (cliente, con su RFC) y contacto con los datos de la cartera; «Ligar» los une a un contacto que ya tienes; «Ignorar» hace que no se les cobre. «Crear los N por ligar» los crea todos de una vez.
- Mientras un cliente no esté ligado, el agente no le cobra.

### Activar el agente de Cobranza
En Agentes listos › Cobranza › «Activar». Pestañas:
1. El agente: nombre, nombre que ve el cliente y el cobrador (o equipo) por omisión. Si la cartera trae la columna Cobrador, cada cliente va con el suyo.
2. Tu empresa: datos del negocio y cómo habla.
3. Canal y plantillas: una bandeja de WhatsApp o de correo. En WhatsApp eliges una plantilla aprobada por etapa (antes de vencer, vencido 1–15, 16–30, 31–60 y más de 60 días). En la plantilla puedes usar {{nombre}}, {{cobranza_saldo}}, {{cobranza_vencido}}, {{cobranza_facturas}}, {{cobranza_dias}} y {{cobranza_vence}}. En la etapa sin plantilla no se le escribe por WhatsApp.
4. Cuándo cobra: «Cobrar solo» (apagado, solo atiende a quien le escriba), la hora del envío, solo de lunes a viernes, cuántos días antes de vencer avisa, cada cuántos días le vuelve a escribir a quien sigue debiendo, máximo de clientes por día y el saldo mínimo.
5. Datos para pagar: banco, cuenta, CLABE y referencia, tal cual se los da al cliente.
6. Cómo platica: el tono y tus indicaciones.
7. Seguimiento: si contesta y se queda a media plática, sus recordatorios.
8. Probar: tú eres el cliente (uno de tu cartera, de ejemplo); no se guarda nada.

### Qué hace el agente
- Le escribe a quien le toca: con una factura por vencer dentro de los días de aviso, o con saldo vencido cada N días. No le escribe a quien tiene una promesa de pago vigente, un comprobante por validar, facturas en aclaración, a quien ya está atendiendo una persona ni a quien se dio de baja.
- El mensaje lleva el «Resumen de saldo pendiente» (cada factura con su vencimiento y saldo, y el total) y los datos para pagar. Los montos salen de la cartera, no de la IA.
- Cuando contesta: «¿cuánto debo?» → le manda el resumen; «¿cómo pago?» → los datos para pagar; «pago el viernes» → registra la promesa de pago y no le vuelve a cobrar hasta esa fecha; «ya pagué» → le pide el comprobante y lo pasa a Comprobantes; «esa factura está mal» → la pone en aclaración y abre un caso; pide el estado de cuenta formal, un descuento, un convenio o una persona → lo pasa al cobrador.
- Nunca amenaza ni presiona, y no ofrece descuentos ni convenios por su cuenta.

### Validar un «ya pagué»
En Ventas › Cobranza › Comprobantes ves el comprobante que mandó el cliente. «Validar»: sus facturas no se cobran hasta que el siguiente corte las traiga pagadas. «Rechazar»: se le vuelve a cobrar y queda una nota en su conversación.

### Promesas de pago
En la pestaña Promesas de pago ves las vigentes, cumplidas e incumplidas. Con cada corte (y cada día), una promesa se marca cumplida si ya no debe lo vencido a esa fecha, o incumplida si pasó la fecha y sigue debiendo; entonces el agente lo vuelve a buscar.

## Dudas frecuentes
- ¿El agente manda el estado de cuenta? Manda el «Resumen de saldo pendiente» (las facturas abiertas y el total). El estado de cuenta formal (con pagos y abonos) lo pasa al cobrador.
- ¿Qué pasa con una factura que ya no viene en el Excel? Se toma como pagada y se deja de cobrar.
- ¿Puedo usar mi propio Excel? Sí: la primera vez eliges qué columna es cuál y se recuerda.
- ¿Por qué no le escribió a un cliente? Puede estar por ligar, sin WhatsApp o correo, con una promesa vigente, un comprobante por validar, facturas en aclaración, sin plantilla para su etapa (WhatsApp) o porque todavía no le toca según «Cuándo cobra».
- ¿Se conecta a Microsip, Aspel o CONTPAQi? Todavía no: por ahora se sube el Excel. Las conexiones se irán agregando y usarán el mismo agente.

## Quién puede
Ver la cartera, subirla y validar comprobantes: administradores. Configurar el agente: administradores.
