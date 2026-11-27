// CrmZeus A2 — artículos (catalogados / no catalogados), su imagen y «catalogar».
import ApiClient from './ApiClient';

/* global axios */

class CrmArticlesAPI extends ApiClient {
  constructor() {
    super('crm/articles', { accountScoped: true });
  }

  list(params) {
    return axios.get(this.url, { params });
  }

  catalog(id) {
    return axios.post(`${this.url}/${id}/catalog`);
  }

  uploadImage(id, file) {
    const data = new FormData();
    data.append('image', file);
    return axios.post(`${this.url}/${id}/image`, data);
  }

  deleteImage(id) {
    return axios.delete(`${this.url}/${id}/image`);
  }
}

export default new CrmArticlesAPI();
