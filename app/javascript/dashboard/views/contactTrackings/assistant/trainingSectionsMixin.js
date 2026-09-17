// proyecto@asistente_agentes_ia — LA ESTRUCTURA DEL AGENTE, SINCRONIZADA
// ============================================================================
// Planes: docs/formulario_entrenamiento_plan.md y docs/estructura_agente_arbol_plan.md.
// Conecta Assistant.vue con el árbol de la Estructura del Agente sin engordar esa
// pantalla: la estructura en bloques, el comprobador y la sincronización con el texto.
//
// El Entrenamiento se arma en el árbol de la izquierda (la ficha del Agente IA quedó
// con su caja de texto de siempre). Cada cambio en una sección o en una rama se manda
// a training_preview, y el texto que devuelve se escribe en el borrador: el texto
// sigue siendo la verdad —es lo que lee el motor, lo que comprueba el comprobador y
// lo que se guarda—. Al revés también: si el borrador cambia por otro camino, se
// vuelve a separar en bloques.
//
// La pantalla define `trainingText` (get y set) y `trainingInboxId`.
// ============================================================================
import TrackingTemplatesAPI from 'dashboard/api/trackingTemplates';

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
    };
  },
  computed: {
    // Explicar usa el endpoint del Asistente, que es solo de administradores.
    canExplainTraining() {
      return this.$store.getters.getCurrentRole === 'administrator';
    },
    // Las listas de las tarjetas de rama: fuente, etiqueta, tipo de caso y acción
    // solo pueden ser algo que la cuenta TIENE (ver RouteFields).
    routeOptions() {
      const inv = this.inventory;
      if (!inv) return {};
      const fuentes = [
        ...new Set((inv.sources || []).map(f => f.directive).filter(Boolean)),
      ];
      // @buscar_predefinidas(GRUPO): el grupo acota el corpus, y sin él la rama
      // busca en todas las respuestas predefinidas de la cuenta.
      const grupos = (inv.canned_groups || [])
        .map(g => `@buscar_predefinidas(${g.prefix})`)
        .filter(g => !fuentes.includes(g));
      return {
        sources: [...fuentes, ...grupos],
        labels: inv.labels || [],
        caseTypes: inv.case_types || [],
        actions: (inv.actions || [])
          .filter(a => a.available)
          .map(a => a.directive),
      };
    },
    // Los hallazgos del comprobador, colgados del nodo que los causó:
    //   { 'route:soporte': 'blocking', 'section:3': 'degrading' }
    // Los de rama vienen con su nombre (`route`/`routes`); el resto se ubica por el
    // número de línea contra el rango de cada bloque (first_line/last_line, que los
    // manda el backend). Un hallazgo dentro del bloque de ramas que no dice de qué
    // rama habla marca el grupo entero, con la clave pelada 'route:'.
    nodeIssues() {
      // Primero la del comprobador en vivo (training_preview, que corre al abrir y en
      // cada cambio): la de la conversación viene guardada y puede ser vieja.
      const v = this.trainingValidation || this.validation;
      if (!v) return {};
      const bloques = this.trainingStructure?.blocks || [];
      const mapa = {};
      const poner = (clave, nivel) => {
        if (mapa[clave] !== 'blocking') mapa[clave] = nivel;
      };
      const bloqueDe = linea =>
        bloques.findIndex(b => linea >= b.first_line && linea <= b.last_line);
      ['blocking', 'degrading'].forEach(nivel => {
        (v[nivel] || []).forEach(hallazgo => {
          const ramas =
            hallazgo.routes || (hallazgo.route ? [hallazgo.route] : []);
          ramas.forEach(nombre => poner(`route:${nombre}`, nivel));
          if (ramas.length || !hallazgo.line) return;
          const i = bloqueDe(hallazgo.line);
          if (i < 0) return;
          poner(
            bloques[i].type === 'routes' ? 'route:' : `section:${i}`,
            nivel
          );
        });
      });
      return mapa;
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
    // Separa el borrador en bloques y trae las sugerencias de nombres de sección.
    loadTrainingFromText(texto) {
      this.trainingStructure = { blocks: [] };
      this.textFromSections = texto || '';
      this.trainingValidation = null;
      this.fetchSectionTitles();
      // replaceStructure: la estructura sale del texto, no de una ficha guardada.
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
    // Termina la sincronización pendiente antes de cambiar de vista o de guardar.
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
  },
};
