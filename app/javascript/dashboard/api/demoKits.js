/* global axios */
// Ajustes › Demostraciones: exportar e importar kits de demo (agentes listos, catálogo, bandejas) y limpiarlos.
import ApiClient from './ApiClient';

class DemoKitsAPI extends ApiClient {
  constructor() {
    super('demo_kits', { accountScoped: true });
  }

  // El archivo .json (blob) con los agentes y las categorías elegidas.
  export(params) {
    return axios.post(`${this.url}/export`, params, { responseType: 'blob' });
  }

  // { kit: 'estetica' } o { data } (el JSON del archivo) → qué crea y qué lugares hay que elegir.
  preview(source) {
    return axios.post(`${this.url}/preview`, source);
  }

  // { kit | data, people: { p1: userId }, inboxes: { i1: 'new' | inboxId } }.
  import(params) {
    return axios.post(`${this.url}/import`, params);
  }

  clean(id) {
    return axios.post(`${this.url}/${id}/clean`);
  }
}

export default new DemoKitsAPI();
