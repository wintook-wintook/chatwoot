/* global axios */
// Cotizaciones › Formatos — los formatos de la empresa, sus datos (encabezado) y la vista previa.
import ApiClient from './ApiClient';

class QuoteFormatsAPI extends ApiClient {
  constructor() {
    super('quote_formats', { accountScoped: true });
  }

  list() {
    return axios.get(this.url);
  }

  // quote_format: { name, is_default, settings }
  save(format, id = null) {
    return id
      ? axios.patch(`${this.url}/${id}`, { quote_format: format })
      : axios.post(this.url, { quote_format: format });
  }

  remove(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  duplicate(id) {
    return axios.post(`${this.url}/${id}/duplicate`);
  }

  uploadLogo(id, file) {
    const data = new FormData();
    data.append('logo', file);
    return axios.post(`${this.url}/${id}/logo`, data);
  }

  removeLogo(id) {
    return axios.delete(`${this.url}/${id}/logo`);
  }

  saveCompany(company) {
    return axios.patch(`${this.url}/company`, { company });
  }

  uploadCompanyLogo(file) {
    const data = new FormData();
    data.append('logo', file);
    return axios.post(`${this.url}/company_logo`, data);
  }

  removeCompanyLogo() {
    return axios.delete(`${this.url}/company_logo`);
  }

  // Lo que está en pantalla, sin guardar → { html }
  preview(settings, id = null) {
    return axios.post(`${this.url}/preview`, { settings, id });
  }
}

export default new QuoteFormatsAPI();
