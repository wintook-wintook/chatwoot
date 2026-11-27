/* global axios */
// Plan-Catalogo-Cotizaciones C1 — Ventas › Catálogo.
import ApiClient from './ApiClient';

class CatalogItemsAPI extends ApiClient {
  constructor() {
    super('catalog_items', { accountScoped: true });
  }

  // params: { q, kind, category_id, active: 'true' | 'false' | 'all', page }
  search(params = {}) {
    return axios.get(this.url, { params });
  }

  categories() {
    return axios.get(`${this.url}/categories`);
  }

  exportCsv() {
    return axios.get(`${this.url}/export`, { responseType: 'blob' });
  }

  // La foto del producto (la manda el agente de prospectos al recomendarlo).
  uploadImage(id, file) {
    const data = new FormData();
    data.append('image', file);
    return axios.post(`${this.url}/${id}/image`, data);
  }

  removeImage(id) {
    return axios.delete(`${this.url}/${id}/image`);
  }

  // Productos y servicios › Parámetros: categorías, impuestos y unidades.
  parameters() {
    return axios.get(this.url.replace(/catalog_items$/, 'catalog_parameters'));
  }

  // list: 'categories' | 'taxes' | 'units'
  saveParameter(list, record, id = null) {
    const base = `${this.url.replace(
      /catalog_items$/,
      'catalog_parameters'
    )}/${list}`;
    return id
      ? axios.patch(`${base}/${id}`, { record })
      : axios.post(base, { record });
  }

  removeParameter(list, id) {
    return axios.delete(
      `${this.url.replace(
        /catalog_items$/,
        'catalog_parameters'
      )}/${list}/${id}`
    );
  }

  importCsv(file) {
    const data = new FormData();
    data.append('file', file);
    return axios.post(`${this.url}/import`, data);
  }
}

export default new CatalogItemsAPI();
