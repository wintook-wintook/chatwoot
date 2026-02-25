// Proyecto: DEV0001
// app/javascript/dashboard/api/scheduledMessages.js

/* global axios */
import endPoints from './endPoints';

class ScheduledMessagesAPI {
  constructor() {
    // El accountId se obtiene de manera dinámica
  }

  get accountId() {
    if (window.store) {
      return window.store.state.auth.currentAccountId;
    }
    
    const match = window.location.pathname.match(/accounts\/(\d+)/);
    return match ? match[1] : null;
  }

  get baseUrl() {
    const accountId = this.accountId;
    if (!accountId) {
      console.error('No se pudo obtener el accountId');
      return '';
    }
    return `/api/v1/accounts/${accountId}`;
  }

  get(conversationId) {
    return axios.get(`${this.baseUrl}/conversations/${conversationId}/scheduled_messages`);
  }

  create({ conversation_id, content, scheduled_at, timezone, recipient_type, template_name, template_category, template_language, template_namespace, template_params, accountId }) {
    const effectiveAccountId = accountId || this.accountId;
    const baseUrl = `/api/v1/accounts/${effectiveAccountId}`;
    const url = `${baseUrl}/conversations/${conversation_id}/scheduled_messages`;
    
    console.log('Creating scheduled message with URL:', url);
    console.log('AccountId:', effectiveAccountId);
    
    const payload = {
      content,
      scheduled_at,
      timezone,
      message_type: recipient_type === 'agent' ? 'private' : 'outgoing'
    };

    // Agregar campos de plantilla si están presentes
    if (template_name) {
      payload.template_name = template_name;
      payload.template_category = template_category;
      payload.template_language = template_language;
      payload.template_namespace = template_namespace;
      payload.template_params = template_params;
    }

    console.log('Payload:', payload);
    
    return axios.post(url, payload);
  }

  update(id, data) {
    const payload = { ...data };
    
    // Convertir recipient_type a message_type para el backend
    if (data.recipient_type) {
      payload.message_type = data.recipient_type === 'agent' ? 'private' : 'outgoing';
      delete payload.recipient_type;
    }

    return axios.patch(`${this.baseUrl}/scheduled_messages/${id}`, payload);
  }

  delete(id) {
    return axios.delete(`${this.baseUrl}/scheduled_messages/${id}`);
  }

  getAll(params = {}) {
    return axios.get(`${this.baseUrl}/scheduled_messages`, { params });
  }
}

export default new ScheduledMessagesAPI();