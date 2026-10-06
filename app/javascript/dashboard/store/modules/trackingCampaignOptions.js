// ================================================================================
// proyecto@automatizacion_campanas
// ================================================================================
// Store Vuex: trackingCampaignOptions
// La lista liviana de campañas (id, nombre, estado, tipo, ventana, inbox) para los
// selectores, como la acción de automatización "Agregar a campaña". El listado con
// estadísticas del Dashboard de Seguimientos no pasa por acá: lo pide Campaigns.vue.
// ================================================================================

import TrackingCampaignsAPI from '../../api/trackingCampaigns';

const state = { records: [] };

export const getters = {
  getCampaignOptions: _state => _state.records,
};

export const actions = {
  async get({ commit }) {
    try {
      const { data } = await TrackingCampaignsAPI.getOptions();
      commit('SET_TRACKING_CAMPAIGN_OPTIONS', data);
    } catch {
      // Sin campañas el desplegable queda vacío; no bloquea el editor de automatizaciones.
    }
  },
};

export const mutations = {
  SET_TRACKING_CAMPAIGN_OPTIONS(_state, records) {
    _state.records = records || [];
  },
};

export default { namespaced: true, state, getters, actions, mutations };
