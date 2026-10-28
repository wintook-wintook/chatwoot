/* global axios */
// Plan-Organizaciones O1 — prospectos y clientes con sus contactos ligados.
import ApiClient from './ApiClient';

class OrganizationsAPI extends ApiClient {
  constructor() {
    super('organizations', { accountScoped: true });
  }

  // { organizations, meta: { count, page, per_page, counts } }
  list(params = {}) {
    return axios.get(this.url, { params });
  }

  // { organization } con contactos y bitácora
  find(id) {
    return axios.get(`${this.url}/${id}`);
  }

  // Con contactId se liga ese contacto al crearla («Convertir en prospecto»).
  create(data, { contactId, stage } = {}) {
    return axios.post(this.url, {
      organization: data,
      contact_id: contactId,
      stage,
    });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, { organization: data });
  }

  remove(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  // Plan-Organizaciones O2 — { opportunities, cases, quotes, contracts, assets }
  summary(id) {
    return axios.get(`${this.url}/${id}/summary`);
  }

  // Plan-Organizaciones O5 — Informes › Dashboard de clientes ({ months })
  metrics(params = {}) {
    return axios.get(`${this.url}/metrics`, { params });
  }

  // Plan-Organizaciones O4 — asistente (vista previa y aplicar) e importación CSV.
  suggestions() {
    return axios.get(`${this.url}/suggestions`);
  }

  applySuggestions(groups) {
    return axios.post(`${this.url}/apply_suggestions`, { groups });
  }

  template() {
    return axios.get(`${this.url}/template`, { responseType: 'blob' });
  }

  importCsv(file) {
    const data = new FormData();
    data.append('file', file);
    return axios.post(`${this.url}/import`, data);
  }

  // «Cambiar de organización» del contacto: { organization, counts: { all, live }, candidates }
  changePreview(contactId) {
    return axios.get(`${this.url}/change_preview`, {
      params: { contact_id: contactId },
    });
  }

  // { contact_id, to_organization_id, move, replacement_contact_id | new_contact }
  changeContact(data) {
    return axios.post(`${this.url}/change_contact`, data);
  }

  changeStage(id, stage) {
    return axios.post(`${this.url}/${id}/change_stage`, { stage });
  }

  addContact(id, contactId) {
    return axios.post(`${this.url}/${id}/add_contact`, {
      contact_id: contactId,
    });
  }

  removeContact(id, contactId) {
    return axios.post(`${this.url}/${id}/remove_contact`, {
      contact_id: contactId,
    });
  }
}

export default new OrganizationsAPI();
