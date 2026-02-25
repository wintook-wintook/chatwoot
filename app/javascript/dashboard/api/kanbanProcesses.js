// app/javascript/dashboard/api/kanbanProcesses.js
// KANBAN0725
import ApiClient from './ApiClient';

class KanbanProcessAPI extends ApiClient {
  constructor() {
    super('kanban_processes', { accountScoped: true });
  }

  get(kanbanTypeProcessId) {
    return axios.get(
      `${this.url.replace(
        'kanban_processes',
        `kanban_type_processes/${kanbanTypeProcessId}/kanban_processes`
      )}`
    );
  }

  show(kanbanTypeProcessId, id) {
    return axios.get(
      `${this.url.replace(
        'kanban_processes',
        `kanban_type_processes/${kanbanTypeProcessId}/kanban_processes`
      )}/${id}`
    );
  }

  create(kanbanTypeProcessId, kanbanProcessObj) {
    return axios.post(
      `${this.url.replace(
        'kanban_processes',
        `kanban_type_processes/${kanbanTypeProcessId}/kanban_processes`
      )}`,
      {
        kanban_process: kanbanProcessObj,
      }
    );
  }

  // update(kanbanTypeProcessId, id, kanbanProcessObj) {
  //   return axios.patch(
  //     `${this.url.replace(
  //       'kanban_processes',
  //       `kanban_type_processes/${kanbanTypeProcessId}/kanban_processes`
  //     )}/${id}`,
  //     {
  //       kanban_process: kanbanProcessObj,
  //     }
  //   );
  // }

 update(kanbanTypeProcessId, id, kanbanProcessObj) {
  console.log('🔍 API UPDATE called with:');
  console.log('- kanbanTypeProcessId:', kanbanTypeProcessId, '(type:', typeof kanbanTypeProcessId, ')');
  console.log('- id:', id, '(type:', typeof id, ')');
  console.log('- kanbanProcessObj:', kanbanProcessObj);
  
  // Validar que los parámetros son correctos
  if (!kanbanTypeProcessId || kanbanTypeProcessId === 'undefined') {
    throw new Error(`Invalid kanbanTypeProcessId: ${kanbanTypeProcessId}`);
  }
  
  if (!id || id === 'undefined') {
    throw new Error(`Invalid id: ${id}`);
  }
  
  // Asegurar que son números/strings válidos, no objetos
  const validTypeProcessId = String(kanbanTypeProcessId);
  const validId = String(id);
  
  const url = `${this.url.replace('kanban_processes', `kanban_type_processes/${validTypeProcessId}/kanban_processes`)}/${validId}`;
  console.log('🌐 UPDATE URL:', url);
  
  const payload = {
    kanban_process: kanbanProcessObj,
  };
  console.log('📦 UPDATE payload:', payload);
  
  return axios.patch(url, payload);
}

  // delete(kanbanTypeProcessId, id) {
  //   //return axios.delete(`${this.url.replace('kanban_processes', `kanban_type_processes/${kanbanTypeProcessId}/kanban_processes`)}/${id}`);
  //   console.log('🔍 API DELETE called with:');
  //   console.log(
  //     '- kanbanTypeProcessId:',
  //     kanbanTypeProcessId,
  //     typeof kanbanTypeProcessId
  //   );
  //   console.log('- id:', id, typeof id);

  //   const baseUrl = this.url;
  //   const finalUrl = `${baseUrl.replace(
  //     'kanban_processes',
  //     `kanban_type_processes/${kanbanTypeProcessId}/kanban_processes`
  //   )}/${id}`;

  //   console.log('🌐 Final URL:', finalUrl);
  //   console.log('🌐 Base URL was:', baseUrl);

  //   if (!kanbanTypeProcessId || !id) {
  //     console.error('❌ Missing required parameters!');
  //     throw new Error(
  //       `Missing parameters: kanbanTypeProcessId=${kanbanTypeProcessId}, id=${id}`
  //     );
  //   }

  //   return axios.delete(finalUrl);
  // }
  // 🎯 CAMBIAR ESTE MÉTODO para usar la ruta simple DE DELETE:
  // delete(id) {
  //   console.log('🔍 API DELETE (simple route) called with id:', id);
  //   console.log('🌐 Delete URL:', `${this.url}/${id}`);

  //   if (!id) {
  //     throw new Error(`Missing id parameter: ${id}`);
  //   }

  //   return axios.delete(`${this.url}/${id}`);
  // }
  async delete(id) {
    console.log('🔍 API DELETE (simple route) called with id:', id);
    console.log('🌐 Delete URL:', `${this.url}/${id}`);

    // if (!id) {
    //   throw new Error(Missing id parameter: ${id});
    // }
    // axios.delete(${this.url}/${id});

    try {
      const response = await axios.delete(`${this.url}/${id}`);
      // console.log('✅ Delete successful:', response.data);
      return response.data;
    } catch (error) {
      if (error.response?.status === 422) {
        // console.error('❌ Error 422 - Unprocessable Entity:', error.response.data);
        throw new Error(`No se puede eliminar la etapas de la oportunidad con conversaciones asociadas`);
      }
      // console.error('❌ Delete error:', error.message);
      throw error;
    }
  }

  reorder(kanbanTypeProcessId, kanbanProcesses) {
    return axios.patch(
      `${this.url.replace(
        'kanban_processes',
        `kanban_type_processes/${kanbanTypeProcessId}/kanban_processes`
      )}/reorder`,
      kanbanProcesses
    );
  }
}

export default new KanbanProcessAPI();