// proyecto@diagrama_agente_ia — F2: ARRANCAR Y SEGUIR UNA PILA EN VIVO
// ============================================================================
// Lo que antes vivía dentro de TestBatteryModal (eliminado en F3: la pila vive en
// el panel Pruebas, TestsPanel): arrancar la pila (las generadas o las escritas
// a mano), leer su avance cada POLL_MS y dejar de leer al terminar o al salir.
//
// El componente pone `batteryTemplateId` (y, si quiere, `batteryBriefId`).
// ============================================================================
import AssistantAPI from 'dashboard/api/assistant';

export const POLL_MS = 4000;

export default {
  data() {
    return {
      batteryId: null,
      state: null,
      error: '',
      starting: false,
      timer: null,
    };
  },
  computed: {
    results() {
      return (this.state && this.state.results) || [];
    },
    running() {
      return this.starting || ['queued', 'running'].includes(this.stateStatus);
    },
    stateStatus() {
      return this.state ? this.state.status : '';
    },
    passed() {
      return this.results.filter(r => r.cumple).length;
    },
    progress() {
      if (!this.state || !this.state.total) return '';
      return this.$t('TRACKING_ASSISTANT_VIEW.BATTERY_PROGRESS', {
        done: this.state.done || 0,
        total: this.state.total,
      });
    },
  },
  beforeDestroy() {
    this.stop();
  },
  methods: {
    // messages: pruebas escritas a mano; sin ellas, las que genera el backend.
    async start(messages = null) {
      if (!this.batteryTemplateId || this.running) return null;
      this.error = '';
      this.state = null;
      this.starting = true;
      try {
        const { data } = await AssistantAPI.startTestBattery(
          this.batteryTemplateId,
          { briefId: this.batteryBriefId || null, messages }
        );
        this.batteryId = data.id;
        this.poll();
        return data.id;
      } catch (error) {
        const code =
          error.response && error.response.data && error.response.data.error;
        this.error = this.$t(
          code === 'no_sandbox'
            ? 'TRACKING_ASSISTANT_VIEW.BATTERY_NO_SANDBOX'
            : 'TRACKING_ASSISTANT_VIEW.BATTERY_ERROR'
        );
        return null;
      } finally {
        this.starting = false;
      }
    },
    // Retomar una pila que ya corrió (vive dos días en la caché del backend).
    resume(id) {
      if (!id) return;
      this.batteryId = id;
      this.poll();
    },
    async poll() {
      this.stop();
      try {
        const { data } = await AssistantAPI.testBattery(this.batteryId);
        this.state = data;
        if (data.status === 'failed') {
          this.error = this.$t('TRACKING_ASSISTANT_VIEW.BATTERY_ERROR');
          return;
        }
        if (data.status !== 'done') this.timer = setTimeout(this.poll, POLL_MS);
      } catch (error) {
        // 404: ya venció en la caché; no tiene caso seguir preguntando.
        if (error.response && error.response.status === 404) {
          this.batteryId = null;
          return;
        }
        this.timer = setTimeout(this.poll, POLL_MS);
      }
    },
    stop() {
      if (this.timer) clearTimeout(this.timer);
      this.timer = null;
    },
  },
};
