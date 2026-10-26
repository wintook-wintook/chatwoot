// @tickets_cases — Plan-Clase-Proyecto P1: utilidades de proyectos compartidas
// por el formulario, el panel de la ficha, la Lista y el Tablero.

export const PROJECT_CLASS = 'project';

export const isProjectType = type => type?.case_class === PROJECT_CLASS;

// Payload de los datos del proyecto. `clear` = vacío se manda como null
// (edición, y ahí también va el avance); si no, vacío se omite (alta).
export const projectPayload = (form, { clear = false } = {}) => {
  const empty = clear ? null : undefined;
  const value = v => (v === '' || v === null || v === undefined ? empty : v);
  const out = {
    project_start_on: value(form.project_start_on),
    project_due_on: value(form.project_due_on),
    budget_hours: value(form.budget_hours),
    budget_amount: value(form.budget_amount),
  };
  if (clear) out.progress = value(form.progress);
  return out;
};
