/* global axios */
// Reporte de cierre: se manda antes de concluir la tarea.
import ApiClient from './ApiClient';

class TaskReportsAPI extends ApiClient {
  constructor() {
    super('task_reports', { accountScoped: true });
  }

  list(params = {}) {
    return axios.get(this.url, { params });
  }

  // Tiempo propuesto para el reporte y si la cuenta lo exige: { minutes, required }.
  suggestion(item) {
    return axios.get(`${this.url}/suggestion`, {
      params: { item_type: item.type, item_id: item.id },
    });
  }

  // item = { type: 'task' | 'meeting', id }
  send(item, { content, outcomeId, files, minutes }) {
    const data = new FormData();
    data.append('item_type', item.type);
    data.append('item_id', item.id);
    data.append('content', content);
    if (minutes) data.append('minutes', minutes);
    if (outcomeId) data.append('task_outcome_id', outcomeId);
    files.forEach(file => data.append('evidence[]', file));
    return axios.post(this.url, data);
  }

  // Avance: lo hecho en una tarea que sigue pendiente (no la completa).
  sendProgress(taskId, { content, doneAt, outcomeId, files, minutes }) {
    const data = new FormData();
    data.append('item_type', 'task');
    data.append('item_id', taskId);
    data.append('progress', 'true');
    data.append('content', content);
    if (minutes) data.append('minutes', minutes);
    if (doneAt) data.append('done_at', doneAt);
    if (outcomeId) data.append('task_outcome_id', outcomeId);
    files.forEach(file => data.append('evidence[]', file));
    return axios.post(this.url, data);
  }

  // Actividad reportada: algo que se hizo sin tarea. Caso, contacto y organización
  // son opcionales; sin ninguno es interna.
  sendActivity({
    title,
    content,
    doneAt,
    outcomeId,
    files,
    minutes,
    caseId,
    contactId,
    organizationId,
  }) {
    const data = new FormData();
    data.append('item_type', 'activity');
    data.append('title', title);
    data.append('content', content);
    if (minutes) data.append('minutes', minutes);
    if (doneAt) data.append('done_at', doneAt);
    if (outcomeId) data.append('task_outcome_id', outcomeId);
    if (caseId) data.append('case_ticket_id', caseId);
    if (contactId) data.append('contact_id', contactId);
    if (organizationId) data.append('organization_id', organizationId);
    files.forEach(file => data.append('evidence[]', file));
    return axios.post(this.url, data);
  }
}

export default new TaskReportsAPI();
