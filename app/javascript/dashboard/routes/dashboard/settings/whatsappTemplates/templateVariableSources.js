// feat/plantillas_variables_chatwoot F9.1 — QUÉ DATO DE CHATWOOT ES CADA VARIABLE
// ============================================================================
// Plan: docs/plantillas_whatsapp_mejoras_plan.md §7.11. Por convención de nombres: si la
// variable se llama como un campo reservado (en español, D9a) o como la clave de un atributo
// personalizado, ese es su dato. Si no, la escribe el agente al mandarla.
// ============================================================================
const VALID_NAME = /^[a-z][a-z0-9_]*$/;

export const RESERVED_FIELDS = [
  'nombre',
  'primer_nombre',
  'apellido',
  'correo',
  'telefono',
  'empresa',
  'agente',
  'conversacion',
  'bandeja',
  'fecha_hoy',
];

// { kind: 'field', key } | { kind: 'attribute', label } | { kind: 'manual' }
// null: una variable numerada ({{1}}), que no se reconoce por nombre.
export const recognizeVariable = (clave, attributes = []) => {
  if (!VALID_NAME.test(clave)) return null;
  if (RESERVED_FIELDS.includes(clave)) return { kind: 'field', key: clave };
  const atributo = attributes.find(a => a.attribute_key === clave);
  if (!atributo) return { kind: 'manual' };
  return {
    kind: 'attribute',
    label: atributo.attribute_display_name || clave,
  };
};

// Los atributos que sirven como variable: Meta no acepta otras claves. Una vez cada clave
// (puede existir en contacto y en conversación) y sin pisar a los campos reservados.
export const attributeVariables = (attributes = []) => {
  const vistas = new Set(RESERVED_FIELDS);
  return attributes.filter(a => {
    const clave = a.attribute_key;
    if (!VALID_NAME.test(clave || '') || vistas.has(clave)) return false;
    vistas.add(clave);
    return true;
  });
};
