// feat/plantillas_whatsapp_mejoras F2 — QUÉ PIDE UNA PLANTILLA Y QUÉ SE MANDA
// ============================================================================
// Plan: docs/plantillas_whatsapp_mejoras_plan.md §4 (F2). Funciones puras sobre una
// plantilla de message_templates (lo que devuelve Meta: components HEADER / BODY /
// FOOTER / BUTTONS):
//
//   describeTemplate   qué campos pide: archivo del encabezado (y su nombre si es
//                      documento), variables del encabezado de texto, del cuerpo y los
//                      botones que llevan dato (URL con {{1}}, copiar código)
//   buildProcessedParams  lo que va en template_params.processed_params
//   renderPreview      el mensaje como lo verá el cliente
//
// FORMATO QUE SE MANDA:
//   - Plantilla que solo lleva variables en el cuerpo, o bandeja que no es WhatsApp
//     Cloud (360dialog, UnoAPI): el formato de siempre, { "1": "Juan" }. Así el envío
//     de esas plantillas no cambia en nada.
//   - WhatsApp Cloud con archivo, variables en el encabezado o botones con dato: el
//     formato por componente que entiende Whatsapp::TemplateProcessorService (F1):
//     { header: {...}, body: {...}, buttons: [...] }.
//
// EL ARCHIVO DE LA PLANTILLA: si la plantilla tiene archivo guardado (el subido en la
// pantalla de plantillas), el formulario lo trae ya puesto (valores.templateFile). Entonces
// el encabezado va como { source: 'template', media_type } sin liga: la liga para Meta la
// saca el servidor al mandar (caduca en una hora). El agente puede cambiarlo por un archivo
// de su máquina (valores.uploadedFile: { source: 'upload', signed_id }) o por otra liga.
// ============================================================================

export const MEDIA_FORMATS = ['IMAGE', 'VIDEO', 'DOCUMENT'];
export const COPY_CODE_MAX = 15;

const VARIABLE_RE = /{{\s*([^}]+?)\s*}}/g;

export const variablesIn = text =>
  [...(text || '').matchAll(VARIABLE_RE)].map(m => m[1]);

const component = (template, type) =>
  ((template && template.components) || []).find(c => c.type === type) || null;

export function describeTemplate(template) {
  const header = component(template, 'HEADER');
  const body = component(template, 'BODY');
  const footer = component(template, 'FOOTER');
  const botones = (component(template, 'BUTTONS') || {}).buttons || [];
  const formato = header ? header.format : null;

  const buttons = botones.map((boton, index) => {
    const tipo = (boton.type || '').toUpperCase();
    const conDato =
      (tipo === 'URL' && variablesIn(boton.url).length > 0) ||
      tipo === 'COPY_CODE';
    return {
      index,
      type: tipo,
      text: boton.text || '',
      url: boton.url || '',
      needsParam: conDato,
    };
  });

  const headerVars = formato === 'TEXT' ? variablesIn(header.text) : [];
  const media = MEDIA_FORMATS.includes(formato) ? formato.toLowerCase() : null;

  return {
    headerFormat: formato,
    headerText: formato === 'TEXT' ? header.text || '' : '',
    headerVars,
    media,
    bodyText: body ? body.text || '' : '',
    bodyVars: variablesIn(body ? body.text : ''),
    footerText: footer ? footer.text || '' : '',
    buttons,
    // Lleva algo más que variables en el cuerpo: necesita el formato por componente.
    needsComponents:
      Boolean(media) ||
      headerVars.length > 0 ||
      buttons.some(b => b.needsParam),
  };
}

const fill = (text, values) =>
  (text || '').replace(VARIABLE_RE, (match, clave) =>
    values && values[clave] ? values[clave] : match
  );

// valores: { body: {"1": ...}, header: {"1": ...}, mediaUrl, mediaName, buttons: {index: valor},
//            templateFile: { media_name, preview_url } | null  (usar el archivo de la plantilla),
//            mediaSource: 'template' | 'upload' | 'link',
//            uploadedFile: { signed_id, filename, preview_url } | null  (subido para este envío) }
export function buildProcessedParams(
  template,
  valores,
  { components = false } = {}
) {
  const info = describeTemplate(template);
  const body = { ...(valores.body || {}) };
  if (!components || !info.needsComponents) return body;

  const params = {};
  if (Object.keys(body).length) params.body = body;
  if (info.media && valores.mediaSource === 'upload') {
    const archivo = valores.uploadedFile || {};
    params.header = {
      source: 'upload',
      signed_id: archivo.signed_id,
      media_type: info.media,
    };
    if (info.media === 'document' && (valores.mediaName || '').trim())
      params.header.media_name = valores.mediaName.trim();
  } else if (info.media && valores.templateFile) {
    params.header = { source: 'template', media_type: info.media };
  } else if (info.media) {
    params.header = {
      media_url: (valores.mediaUrl || '').trim(),
      media_type: info.media,
    };
    if (info.media === 'document' && (valores.mediaName || '').trim())
      params.header.media_name = valores.mediaName.trim();
  } else if (info.headerVars.length) {
    params.header = { ...(valores.header || {}) };
  }
  // Solo los que llevan dato, cada uno con su posición en la plantilla (es la que lee
  // Meta): dejar un null en el lugar de los otros no sirve, Rails los quita al recibirlos.
  const conDato = info.buttons.filter(b => b.needsParam);
  if (conDato.length) {
    params.buttons = conDato.map(b => ({
      type: b.type === 'COPY_CODE' ? 'copy_code' : 'url',
      index: b.index,
      parameter: ((valores.buttons || {})[b.index] || '').trim(),
    }));
  }
  return params;
}

// El camino de regreso de buildProcessedParams, para editar un programado: separa el
// cuerpo de lo que captura TemplateExtraFields. { body, initial }
export function valuesFromProcessedParams(params) {
  const guardado = params || {};
  const porComponente = ['body', 'header', 'buttons'].some(k => k in guardado);
  if (!porComponente) return { body: { ...guardado }, initial: {} };

  const header = guardado.header || {};
  const archivo = 'source' in header || 'media_url' in header;
  const initial = {
    buttons: (guardado.buttons || []).reduce(
      (acc, b) => (b ? { ...acc, [b.index]: b.parameter } : acc),
      {}
    ),
  };
  if (!archivo)
    return { body: guardado.body || {}, initial: { ...initial, header } };

  return {
    body: guardado.body || {},
    initial: {
      ...initial,
      mediaSource: header.source || 'link',
      mediaUrl: header.media_url || '',
      mediaName: header.media_name || '',
      uploadedFile:
        header.source === 'upload'
          ? { signed_id: header.signed_id, filename: header.media_name }
          : null,
    },
  };
}

// Qué falta o está mal, para no mandar algo que Meta va a rechazar.
export function validateValues(template, valores, { components = false } = {}) {
  const info = describeTemplate(template);
  const errores = [];
  const lleno = (obj, clave) => Boolean(((obj || {})[clave] || '').trim());

  if (info.bodyVars.some(v => !lleno(valores.body, v))) errores.push('BODY');
  if (!components) return errores;

  if (info.headerVars.some(v => !lleno(valores.header, v)))
    errores.push('HEADER');
  if (info.media && valores.mediaSource === 'upload') {
    if (!valores.uploadedFile) errores.push('MEDIA_FILE');
  } else if (
    info.media &&
    !valores.templateFile &&
    !/^https?:\/\/\S+$/i.test((valores.mediaUrl || '').trim())
  )
    errores.push('MEDIA_URL');
  info.buttons
    .filter(b => b.needsParam)
    .forEach(b => {
      const valor = ((valores.buttons || {})[b.index] || '').trim();
      if (!valor) errores.push('BUTTON');
      else if (b.type === 'COPY_CODE' && valor.length > COPY_CODE_MAX)
        errores.push('COPY_CODE_LENGTH');
    });
  return [...new Set(errores)];
}

// El mensaje como lo verá el cliente (texto): encabezado, cuerpo, pie y botones.
export function renderPreview(template, valores) {
  const info = describeTemplate(template);
  return {
    header:
      info.headerFormat === 'TEXT' ? fill(info.headerText, valores.header) : '',
    media: info.media,
    mediaName:
      valores.templateFile && valores.mediaSource !== 'upload'
        ? valores.templateFile.media_name || ''
        : (valores.mediaName || '').trim(),
    body: fill(info.bodyText, valores.body),
    footer: info.footerText,
    buttons: info.buttons.map(b => b.text).filter(Boolean),
  };
}
