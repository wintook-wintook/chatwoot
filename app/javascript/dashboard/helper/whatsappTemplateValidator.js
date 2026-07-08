// @waba_templates — réplica en cliente del validador del backend (Whatsapp::TemplateValidator)
// para dar feedback en vivo antes de enviar. Mantener en sync con el PORO de Ruby.

const NAME_FORMAT = /^[a-z0-9_]{1,512}$/;
const VAR_REGEX = /\{\{\s*(\d+)\s*\}\}/g;

export const templateVariables = text => {
  const matches = String(text || '').match(VAR_REGEX) || [];
  return matches.map(m => Number(m.replace(/[^0-9]/g, '')));
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
  if ((counts.URL || 0) > 2) errors.push('Botones: máximo 2 de tipo URL');
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
    if (type === 'URL' && !b.url) errors.push(`Botón #${pos} (URL) sin url`);
    if (type === 'PHONE_NUMBER' && !b.phone_number) {
      errors.push(`Botón #${pos} (teléfono) sin phone_number`);
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

  // body
  if (!t.body_text) errors.push('Body: el cuerpo es obligatorio');
  else {
    if (t.body_text.length > 1024) {
      errors.push(`Body: excede 1024 caracteres (${t.body_text.length})`);
    }
    checkContiguous(templateVariables(t.body_text), 'Body', errors);
  }

  // header
  if (t.header_type === 'text') {
    const text = t.header_content || '';
    if (!text) errors.push('Cabecera de texto: falta el contenido');
    if (text.length > 60)
      errors.push(`Cabecera: excede 60 caracteres (${text.length})`);
    const vars = [...new Set(templateVariables(text))];
    if (vars.length > 1) errors.push('Cabecera: máximo 1 variable');
    if (vars.length && vars[0] !== 1) {
      errors.push('Cabecera: la variable debe ser exactamente {{1}}');
    }
  } else if (['image', 'video', 'document'].includes(t.header_type)) {
    if (!t.header_media_url && !t.header_handle) {
      errors.push('Cabecera multimedia: falta el archivo (URL o handle)');
    }
  }

  // footer
  if (t.footer_text) {
    if (t.footer_text.length > 60) {
      errors.push(`Pie: excede 60 caracteres (${t.footer_text.length})`);
    }
    if (templateVariables(t.footer_text).length) {
      errors.push('Pie: no puede contener variables');
    }
  }

  // botones
  validateButtons(buttons, errors);

  // samples
  const bodyVars = new Set(templateVariables(t.body_text)).size;
  const bodySamples = Array.isArray(samples.body) ? samples.body : [];
  if (bodySamples.length !== bodyVars) {
    errors.push(
      `Ejemplos: se requieren ${bodyVars} valor(es) de body (hay ${bodySamples.length})`
    );
  } else if (bodySamples.some(v => !String(v || '').trim())) {
    errors.push('Ejemplos: hay valores de body vacíos');
  }

  if (t.header_type === 'text' && templateVariables(t.header_content).length) {
    const headerSamples = Array.isArray(samples.header) ? samples.header : [];
    if (headerSamples.length !== 1 || !String(headerSamples[0] || '').trim()) {
      errors.push('Ejemplos: falta el valor de la cabecera');
    }
  }

  return errors;
};
