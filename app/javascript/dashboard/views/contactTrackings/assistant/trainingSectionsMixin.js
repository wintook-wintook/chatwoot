// proyecto@asistente_agentes_ia — Entrenamiento por secciones en la ficha
// ============================================================================
// Plan: docs/formulario_entrenamiento_plan.md. Conecta EditTemplate.vue con el
// editor de secciones sin engordar esa pantalla (arrastra 167 errores de lint
// previos): la vista elegida, la estructura, el comprobador y qué se manda al
// guardar.
//
// Lo usan las dos pantallas: la ficha del agente (el texto es
// `form.complementary_prompt`) y el Asistente (es `draft`). Cada una define
// `trainingText` —get y set— y el resto del comportamiento es el mismo.
//
// La verdad sigue siendo el texto para todo lo que ya existía
// (validación del formulario, Generar con IA, Restaurar, el editor expandido).
// En la vista Secciones, cada cambio se manda a training_preview y el texto que
// devuelve se escribe en `form.complementary_prompt`; al revés, si el texto
// cambia por otro camino, se vuelve a separar en bloques.
// ============================================================================
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';
import AssistantAPI from 'dashboard/api/assistant';

const PREVIEW_DEBOUNCE_MS = 500;

export default {
  data() {
    return {
      trainingView: 'sections',
      trainingStructure: { blocks: [] },
      trainingValidation: null,
      sectionTitles: { suggested: [], from_account: [] },
      trainingPreviewTimer: null,
      trainingPreviewPromise: null,
      // El texto que escribió la propia vista Secciones: el watcher no lo vuelve a
      // separar (movería el cursor y perdería lo que se está escribiendo).
      textFromSections: null,
      // F4: Explicar una sección (ExplainModal del Asistente).
      trainingExplain: {
        show: false,
        excerpt: '',
        result: null,
        isRunning: false,
        error: '',
      },
    };
  },
  computed: {
    canExplainTraining() {
      return this.$store.getters.getCurrentRole === 'administrator';
    },
    // La pantalla que use el mixin lo redefine si su texto no es el de la ficha.
    trainingText: {
      get() {
        return this.form.complementary_prompt;
      },
      set(texto) {
        this.form.complementary_prompt = texto;
      },
    },
    // Con qué canal se explica una sección (el Asistente tiene el suyo elegido).
    trainingInboxId() {
      return this.selectedInboxId || null;
    },
  },
  watch: {
    trainingText(texto) {
      if (this.trainingView !== 'sections' || texto === this.textFromSections)
        return;
      this.scheduleTrainingPreview({ text: texto }, { replaceStructure: true });
    },
  },
  beforeDestroy() {
    clearTimeout(this.trainingPreviewTimer);
  },
  methods: {
    // Al abrir la ficha: la estructura que mandó el backend y las sugerencias.
    loadTrainingStructure(template) {
      this.trainingStructure = template?.training_structure || { blocks: [] };
      this.textFromSections = template?.complementary_prompt || '';
      this.trainingValidation = null;
      this.fetchSectionTitles();
      this.scheduleTrainingPreview(
        { text: template?.complementary_prompt || '' },
        { delay: 0 }
      );
    },
    // El Asistente no tiene ficha: arranca del texto del borrador.
    loadTrainingFromText(texto) {
      this.trainingStructure = { blocks: [] };
      this.textFromSections = texto || '';
      this.trainingValidation = null;
      this.fetchSectionTitles();
      // replaceStructure: acá la estructura sale del texto, no de una ficha guardada.
      return this.scheduleTrainingPreview(
        { text: texto || '' },
        { delay: 0, replaceStructure: true }
      );
    },
    async fetchSectionTitles() {
      try {
        const { data } = await TrackingTemplatesAPI.getSectionTitles();
        this.sectionTitles = data;
      } catch (error) {
        // Sin sugerencias igual se puede escribir un nombre propio.
      }
    },
    onSectionsInput(structure) {
      this.trainingStructure = structure;
      this.scheduleTrainingPreview({ training_structure: structure });
    },
    scheduleTrainingPreview(
      payload,
      { delay = PREVIEW_DEBOUNCE_MS, replaceStructure = false } = {}
    ) {
      clearTimeout(this.trainingPreviewTimer);
      this.trainingPreviewPromise = new Promise(resolve => {
        this.trainingPreviewTimer = setTimeout(async () => {
          await this.runTrainingPreview(payload, replaceStructure);
          this.trainingPreviewPromise = null;
          resolve();
        }, delay);
      });
      return this.trainingPreviewPromise;
    },
    async runTrainingPreview(payload, replaceStructure) {
      try {
        const { data } = await TrackingTemplatesAPI.trainingPreview(payload);
        this.trainingValidation = data.validation;
        if (payload.training_structure) {
          this.textFromSections = data.text;
          this.trainingText = data.text;
        }
        if (replaceStructure) this.trainingStructure = data.training_structure;
      } catch (error) {
        // Sin vista previa sigue valiendo lo último que se sincronizó.
      }
    },
    // Termina la sincronización pendiente antes de cambiar de vista o guardar.
    async flushTrainingPreview() {
      if (this.trainingPreviewPromise) {
        clearTimeout(this.trainingPreviewTimer);
        const pendiente =
          this.trainingView === 'sections'
            ? { training_structure: this.trainingStructure }
            : { text: this.trainingText };
        await this.runTrainingPreview(
          pendiente,
          this.trainingView !== 'sections'
        );
        this.trainingPreviewPromise = null;
      }
    },
    async switchTrainingView(vista) {
      if (vista === this.trainingView) return;
      await this.flushTrainingPreview();
      if (vista === 'sections') {
        await this.runTrainingPreview({ text: this.trainingText }, true);
      }
      this.trainingView = vista;
    },
    // Lo que se agrega al payload de guardado.
    trainingPayload() {
      return this.trainingView === 'sections'
        ? {
            training_structure: { blocks: this.trainingStructure.blocks || [] },
          }
        : {};
    },
    async explainTrainingBlock(excerpt) {
      this.trainingExplain = {
        show: true,
        excerpt,
        result: null,
        isRunning: true,
        error: '',
      };
      try {
        const { data } = await AssistantAPI.explain(
          this.trainingText,
          excerpt,
          this.trainingInboxId
        );
        this.trainingExplain.result = data;
      } catch (error) {
        this.trainingExplain.error = this.$t(
          'TRACKING_TEMPLATES.FORM.TRAINING.EXPLAIN_ERROR'
        );
      } finally {
        this.trainingExplain.isRunning = false;
      }
    },
    trainingIssues() {
      const v = this.trainingValidation;
      return {
        blocking: v?.blocking?.length || 0,
        degrading: v?.degrading?.length || 0,
        routes: v?.routes?.length || 0,
      };
    },
  },
};
