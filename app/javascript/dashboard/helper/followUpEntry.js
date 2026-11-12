// «Delegar seguimiento»: ¿quién le da seguimiento ya? Si corre un agente a medida se abre ese;
// si no, el formulario (con la elección de motor si la empresa tiene agentes a medida).
import AiFollowUpsAPI from 'dashboard/api/aiFollowUps';

// target: conversation_id (número) o { contact_id } / { case_id }.
// → { ai, custom, custom_agents }; si falla, como si no hubiera nada corriendo.
export const whoFollows = async target => {
  try {
    const { data } = await AiFollowUpsAPI.running(target);
    return data || {};
  } catch (e) {
    return {};
  }
};
