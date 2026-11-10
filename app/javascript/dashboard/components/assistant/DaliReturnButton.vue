<!--
  Portal de Dali — «Volver a Dali»: aparece en la plataforma solo si se llegó desde
  el portal del teléfono (helper/daliPortal). Al tocarlo regresa a la plática.
-->
<script>
import { daliReturnPath, clearDaliReturn } from 'dashboard/helper/daliPortal';
import {
  assistantState,
  DEFAULT_ASSISTANT_NAME,
} from 'dashboard/helper/assistantState';

export default {
  name: 'DaliReturnButton',
  data() {
    return { path: daliReturnPath(), state: assistantState };
  },
  computed: {
    name() {
      return this.state.name || DEFAULT_ASSISTANT_NAME;
    },
  },
  watch: {
    $route() {
      this.path = daliReturnPath();
    },
  },
  methods: {
    back() {
      const { path } = this;
      clearDaliReturn();
      this.path = null;
      this.$router.push(path);
    },
  },
};
</script>

<template>
  <div>
    <button
      v-if="path"
      type="button"
      class="fixed z-50 flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-white rounded-full shadow-lg bottom-4 left-1/2 -translate-x-1/2 bg-woot-500 hover:bg-woot-600"
      @click="back"
    >
      <fluent-icon icon="wand" size="14" />
      {{ $t('ASSISTANT.PORTAL.BACK', { name }) }}
    </button>
  </div>
</template>
