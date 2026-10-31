// @waba_templates — réplica en cliente del validador del backend (Whatsapp::TemplateValidator)
// para dar feedback en vivo antes de enviar. Mantener en sync con el PORO de Ruby.

const NAME_FORMAT = /^[a-z0-9_]{1,512}$/;
const VAR_REGEX = /\{\{\s*(\d+)\s*\}\}/g;
// feat/plantillas_variables_chatwoot F9.1: números ({{1}}) o nombres ({{edad}}).
const TOKEN_REGEX = /\{\{\s*([^{}]*?)\s*\}\}/g;
const NUMBER_VAR = /^\d+$/;
const NAMED_VAR = /^[a-z][a-z0-9_]*$/;
const STARTS_WITH_VAR = /^\{\{[^{}]*\}\}/;
const ENDS_WITH_VAR = /\{\{[^{}]*\}\}$/;
export const COPY_CODE_MAX = 15;

const firstExample = b =>
  String((Array.isArray(b.example) ? b.example[0] : b.example) || '').trim();

export const templateVariables = text => {
  const matches = String(text || '').match(VAR_REGEX) || [];
  return matches.map(m => Number(m.replace(/[^0-9]/g, '')));
};

// Todas las variables, con repetidas y en orden de aparición.
const variableTokens = text =>
  [...String(text || '').matchAll(TOKEN_REGEX)].map(m => m[1]);

// Las distintas, en el orden de sus ejemplos: los números de menor a mayor; los nombres, por
// orden de aparición.
export const variableKeys = text => {
  const distintas = [...new Set(variableTokens(text))];
  return distintas.every(v => NUMBER_VAR.test(v))
    ? distintas.sort((a, b) => Number(a) - Number(b))
    : distintas;
};

// Sustituye cada variable por su ejemplo; si no hay ejemplo, la deja tal cual.
// Se usa en la vista previa para mostrar la plantilla como la verá el cliente.
export const substituteVariables = (text, samples = []) => {
  const claves = variableKeys(text);
  return String(text || '').replace(TOKEN_REGEX, (match, clave) => {
    const posicion = NUMBER_VAR.test(clave)
      ? Number(clave) - 1
      : claves.indexOf(clave);
    return samples[posicion] || match;
  });
};

// Números o nombres, nunca los dos: el formato es de toda la plantilla (encabezado y cuerpo).
const checkVariableFormat = (t, errors) => {
  const encabezado = t.header_type === 'text' ? t.header_content : '';
  const todas = [...variableTokens(encabezado), ...variableTokens(t.body_text)];
  const invalida = todas.find(v => !NUMBER_VAR.test(v) && !NAMED_VAR.test(v));
  if (invalida !== undefined) {
    errors.push(
      `Variables: {{${invalida}}} no es válida (usa minúsculas, números y _, empezando con letra)`
    );
  }
  if (
    todas.some(v => NUMBER_VAR.test(v)) &&
    todas.some(v => NAMED_VAR.test(v))
  ) {
    errors.push(
      'Variables: no mezcles números con nombres (usa solo {{1}} o solo {{nombre}})'
    );
  }
};

const checkContiguous = (nums, field, errors) => {
  if (!nums.length) return;
  const sorted = [...new Set(nums)].sort((a, b) => a - b);
  if (sorted[0] !== 1) {
    errors.push(`${field}: la primera variable debe ser {{1}}`);
    return;
  }
  for (let i = 1; i <= sorted[sorted.length - 1]; i += 1) {
    if (!sorted.includes(i)) {
      errors.push(`${field}: falta la variable {{${i}}}`);
      return;
    }
  }
};

const validateButtons = (buttons, errors) => {
  if (!buttons.length) return;
  if (buttons.length > 10)
    errors.push(`Botones: máximo 10 (hay ${buttons.length})`);

  const counts = buttons.reduce((acc, b) => {
    const type = String(b.type || '').toUpperCase();
    acc[type] = (acc[type] || 0) + 1;
    return acc;
  }, {});
  if ((counts.URL || 0) > 2) errors.push('Botones: máximo 2 de tipo liga');
  if ((counts.PHONE_NUMBER || 0) > 1)
    errors.push('Botones: máximo 1 de tipo teléfono');
  if ((counts.COPY_CODE || 0) > 1)
    errors.push('Botones: máximo 1 de tipo código');

  let seenCta = false;
  buttons.forEach((b, i) => {
    const type = String(b.type || '').toUpperCase();
    const pos = i + 1;
    if (type === 'QUICK_REPLY') {
      if (seenCta) {
        errors.push(
          'Botones: las respuestas rápidas deben ir agrupadas al inicio'
        );
      }
    } else {
      seenCta = true;
    }
    if (type !== 'COPY_CODE' && String(b.text || '').length > 25) {
      errors.push(`Botón #${pos}: el texto excede 25 caracteres`);
    }
    if (type === 'URL' && !b.url)
      errors.push(`Botón #${pos} (liga): falta la liga`);
    // feat/plantillas_whatsapp_mejoras: Meta pide un ejemplo de la liga con {{1}} y del código.
    if (type === 'URL' && templateVariables(b.url).length && !firstExample(b)) {
      errors.push(`Botón #${pos} (liga): falta el ejemplo de la liga completa`);
    }
    if (type === 'COPY_CODE') {
      const ejemplo = firstExample(b);
      if (!ejemplo)
        errors.push(`Botón #${pos} (código): falta el código de ejemplo`);
      else if (ejemplo.length > COPY_CODE_MAX) {
        errors.push(
          `Botón #${pos} (código): el ejemplo admite hasta ${COPY_CODE_MAX} caracteres`
        );
      }
    }
    if (type === 'PHONE_NUMBER' && !b.phone_number) {
      errors.push(`Botón #${pos} (teléfono): falta el número`);
    }
  });
};

// Recibe un objeto tipo { name, header_type, header_content, body_text, footer_text,
// buttons, sample_values } y devuelve un array de errores (vacío = válido).
export const validateTemplate = t => {
  const errors = [];
  const buttons = Array.isArray(t.buttons) ? t.buttons : [];
  const samples = t.sample_values || {};

  // nombre
  if (!t.name) errors.push('Nombre: es obligatorio');
  else if (!NAME_FORMAT.test(t.name)) {
    errors.push('Nombre: solo minúsculas, números y _ (1-512 caracteres)');
  }

  // feat/plantillas_whatsapp_mejoras: autenticación tiene formato fijo de Meta.
  if (String(t.category || '').toUpperCase() === 'AUTHENTICATION') {
    errors.push(
      'Categoría: las de autenticación (códigos de verificación) se crean en WhatsApp Manager de Meta'
    );
  }

  checkVariableFormat(t, errors);

  // body
  if (!t.body_text) errors.push('Mensaje: es obligatorio');
  else {
    if (t.body_text.length > 1024) {
      errors.push(`Mensaje: excede 1024 caracteres (${t.body_text.length})`);
    }
    checkContiguous(templateVariables(t.body_text), 'Mensaje', errors);
    // feat/plantillas_whatsapp_mejoras: Meta rechaza variables en la orilla del cuerpo.
    const texto = t.body_text.trim();
    if (STARTS_WITH_VAR.test(texto))
      errors.push('Mensaje: no puede empezar con una variable');
    if (ENDS_WITH_VAR.test(texto)) {
      errors.push(
        'Mensaje: no puede terminar con una variable (agrega un punto o texto después)'
      );
    }
  }

  // header
  if (t.header_type === 'text') {
    const text = t.header_content || '';
    if (!text) errors.push('Encabezado: falta el texto');
    if (text.length > 60)
      errors.push(`Encabezado: excede 60 caracteres (${text.length})`);
    const vars = variableKeys(text);
    if (vars.length > 1) errors.push('Encabezado: máximo 1 variable');
    const numeros = [...new Set(templateVariables(text))];
    if (numeros.length && (numeros.length > 1 || numeros[0] !== 1)) {
      errors.push('Encabezado: la variable debe ser exactamente {{1}}');
    }
  } else if (['image', 'video', 'document'].includes(t.header_type)) {
    // feat/plantillas_whatsapp_mejoras F6: o el archivo subido (header_sample).
    if (!t.header_media_url && !t.header_handle && !t.header_sample) {
      errors.push('Encabezado: falta el archivo (súbelo o pega una liga)');
    }
  }

  // footer
  if (t.footer_text) {
    if (t.footer_text.length > 60) {
      errors.push(`Pie: excede 60 caracteres (${t.footer_text.length})`);
    }
    if (variableTokens(t.footer_text).length) {
      errors.push('Pie: no puede contener variables');
    }
  }

  // botones
  validateButtons(buttons, errors);

  // samples
  const bodyVars = variableKeys(t.body_text).length;
  const bodySamples = Array.isArray(samples.body) ? samples.body : [];
  if (bodySamples.length !== bodyVars) {
    errors.push(
      `Ejemplos: se requieren ${bodyVars} valor(es) del mensaje (hay ${bodySamples.length})`
    );
  } else if (bodySamples.some(v => !String(v || '').trim())) {
    errors.push('Ejemplos: hay ejemplos del mensaje vacíos');
  }

  if (t.header_type === 'text' && variableTokens(t.header_content).length) {
    const headerSamples = Array.isArray(samples.header) ? samples.header : [];
    if (headerSamples.length !== 1 || !String(headerSamples[0] || '').trim()) {
      errors.push('Ejemplos: falta el ejemplo del encabezado');
    }
  }

  return errors;
};
