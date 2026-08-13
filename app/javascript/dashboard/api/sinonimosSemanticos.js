import ApiClient from './ApiClient';

// Catálogo semántico FIJO (solo lectura) para el <select> de la palabra raíz.
class SinonimosSemanticos extends ApiClient {
  constructor() {
    super('sinonimos_semanticos', { accountScoped: true });
  }
}

export default new SinonimosSemanticos();
