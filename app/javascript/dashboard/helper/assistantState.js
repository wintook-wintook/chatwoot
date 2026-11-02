// Asistente (Dali) — estado compartido del panel: abierto o no y cómo se llama en
// esta cuenta (lo pone cada cliente; por defecto «Dali»). Lo usan el panel, el botón
// de la barra lateral, el menú del logo y la Actividad del caso («vía Dali»).
import Vue from 'vue';

export const DEFAULT_ASSISTANT_NAME = 'Dali';

export const assistantState = Vue.observable({
  open: false,
  name: DEFAULT_ASSISTANT_NAME,
});

export const toggleAssistant = (open = !assistantState.open) => {
  assistantState.open = open;
};
