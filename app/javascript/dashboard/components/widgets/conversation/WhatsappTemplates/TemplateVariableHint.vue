<script>
/**
 * feat/plantillas_variables_resolver F9.3 — DE DÓNDE SALIÓ EL DATO DE UNA VARIABLE
 *
 * Bajo cada variable con nombre: «Se llenó con: Edad», o en rojo si el contacto no tiene ese
 * dato. Las que el sistema no conoce las escribe el agente y no llevan aviso. Lo usan la
 * conversación y los mensajes programados.
 */
import { mapGetters } from 'vuex';
import { variableHint } from 'dashboard/routes/dashboard/settings/whatsappTemplates/templateVariableSources';

export default {
  props: {
    variable: {
      type: String,
      required: true,
    },
    value: {
      type: String,
      default: '',
    },
    context: {
      type: Object,
      default: () => ({}),
    },
  },
  computed: {
    ...mapGetters({ attributes: 'attributes/getAttributes' }),
    hint() {
      return variableHint(
        this.variable,
        this.value,
        this.context,
        this.attributes
      );
    },
    source() {
      if (!this.hint) return '';
      return this.hint.kind === 'field'
        ? this.$t(
            `WHATSAPP_TEMPLATE_EDITOR.VARIABLES.FIELDS.${this.hint.key.toUpperCase()}`
          )
        : this.hint.label;
    },
  },
};
</script>

<template>
  <p
    v-if="hint"
    class="w-full mt-1 mb-0 text-xs basis-full"
    :class="hint.missing ? 'text-red-600 dark:text-red-400' : 'text-slate-500'"
  >
    {{
      hint.missing
        ? $t('WHATSAPP_TEMPLATES.PARSER.VARIABLE_MISSING', { source })
        : $t('WHATSAPP_TEMPLATES.PARSER.VARIABLE_FILLED', { source })
    }}
  </p>
</template>
