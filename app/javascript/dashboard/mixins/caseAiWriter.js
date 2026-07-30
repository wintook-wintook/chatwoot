import OpenAPI from 'dashboard/api/integrations/openapi';

// @tickets_cases — Escritura asistida por IA para los editores de nota/tarea.
// Usa la integración OpenAI de la cuenta para corregir ortografía/gramática
// (`fix_spelling_grammar`) o mejorar la redacción (`rephrase`), y guarda el
// texto previo para poder volver al original. El componente que lo incluye
// debe exponer `aiFieldName` (el campo de `form` sobre el que opera, p. ej.
// 'description' o 'content').
export default {
  data() {
    return {
      // '' = inactivo; si no, el tipo de evento en curso ('rephrase' | 'fix_spelling_grammar').
      aiLoading: '',
      // Texto anterior a la primera edición con IA (null = no hay nada que revertir).
      aiOriginalText: null,
    };
  },
  computed: {
    aiHook() {
      const apps = this.$store.getters['integrations/getAppIntegrations'] || [];
      const openai = apps.find(
        a => a.id === 'openai' && a.hooks && a.hooks.length
      );
      return openai ? openai.hooks[0] : null;
    },
    aiEnabled() {
      return !!this.aiHook;
    },
    canRevertAi() {
      return this.aiOriginalText !== null;
    },
  },
  created() {
    // Carga las integraciones una sola vez para saber si OpenAI está activo.
    if (!this.$store.getters['integrations/getAppIntegrations'].length) {
      this.$store.dispatch('integrations/get');
    }
  },
  methods: {
    async aiImprove(type) {
      const field = this.aiFieldName;
      const text = (this.form[field] || '').trim();
      if (!this.aiHook || !text || this.aiLoading) return;
      this.aiLoading = type;
      try {
        const { data } = await OpenAPI.processEvent({
          hookId: this.aiHook.id,
          type,
          content: this.form[field],
        });
        const improved = data && data.message;
        if (improved) {
          // Guarda el original solo la primera vez, para poder volver a él.
          if (this.aiOriginalText === null)
            this.aiOriginalText = this.form[field];
          this.form[field] = improved;
        }
      } catch (error) {
        this.$emitter.emit('newToastMessage', {
          message: this.$t('CASE_TICKETS.AI.ERROR'),
        });
      } finally {
        this.aiLoading = '';
      }
    },
    aiRevert() {
      if (this.aiOriginalText === null) return;
      this.form[this.aiFieldName] = this.aiOriginalText;
      this.aiOriginalText = null;
    },
    resetAi() {
      this.aiOriginalText = null;
      this.aiLoading = '';
    },
  },
};
