<!--
  Logo de la empresa arriba de la barra de íconos: lleva a Inicio (Mi resumen) o,
  en cuentas sin casos, a Conversaciones (`homePath`, lo calcula Primary.vue).
  Antes abría un menú de accesos rápidos (Dali, Tarea, Reportar actividad, Buscar,
  Nuevo contacto, Ayuda); todo eso vive ahora en la barra de arriba
  (components/assistant/AssistantTopBar.vue), con las mismas ventanas.
-->
<script>
export default {
  name: 'QuickActions',
  props: {
    logoSource: { type: String, default: '' },
    name: { type: String, default: '' },
    homePath: { type: String, default: '' },
  },
};
</script>

<template>
  <router-link
    v-tooltip.right="$t('QUICK_ACTIONS.GO_HOME')"
    :to="homePath"
    class="block w-8 h-8 m-4 mb-2"
    :aria-label="$t('QUICK_ACTIONS.GO_HOME')"
  >
    <img
      :src="logoSource"
      :alt="name"
      class="object-contain w-8 h-8 rounded-md"
    />
  </router-link>
</template>
