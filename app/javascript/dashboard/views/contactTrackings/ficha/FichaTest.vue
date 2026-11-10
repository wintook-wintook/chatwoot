<script>
// feat/ficha_agente_ia — PROBAR EL AGENTE ANTES DE CREARLO
// ============================================================================
// Idea 1 (09/11/2026). [Probar mi agente] corre en segundo plano (Ficha::TestJob): frases
// sacadas de cada recurso + frases reales de los clientes, por el clasificador REAL.
//
//   ✓ 8 de 8 frases cayeron en su ruta
//   Lo que escriben tus clientes:
//     «¿a qué hora atienden?» → ruta por defecto   [Mandarla a: ▾ ruta] [Agregar]
//
// «Agregar» suma la frase a la descripción de esa ruta (sin IA): emite addPhrase y la
// pantalla vuelve a armar el Entrenamiento; la prueba queda «por repetir».
// ============================================================================
import FichaAPI from 'dashboard/api/fichaAgente';

const POLL_MS = 1500;
const MAX_POLLS = 120;

export default {
  props: {
    payload: { type: Object, default: () => ({}) },
    // Un agente que ya existe: se prueba su Entrenamiento guardado.
    templateId: { type: Number, default: null },
    // Las rutas del Entrenamiento generado: [{ name, key, label }]
    routes: { type: Array, default: () => [] },
    disabled: { type: Boolean, default: false },
  },
  emits: ['addPhrase', 'result'],
  data() {
    return {
      running: false,
      progress: null,
      result: null,
      stale: false,
      error: '',
      target: {},
      timer: null,
      polls: 0,
      testedPayload: '',
    };
  },
  computed: {
    failures() {
      if (!this.result) return [];
      return (this.result.per_route || []).flatMap(ruta =>
        (ruta.results || [])
          .filter(item => !item.ok)
          .map(item => ({
            ...item,
            key: ruta.key,
            route: ruta.route,
            label: ruta.label,
          }))
      );
    },
    fallbacks() {
      return ((this.result && this.result.real) || []).filter(
        item => item.fallback
      );
    },
    understood() {
      return ((this.result && this.result.real) || []).filter(
        item => !item.fallback
      );
    },
    // Las rutas para elegir: las que pasa la pantalla o, en un agente que ya existe, las
    // que regresa la prueba.
    routeList() {
      if (this.routes.length) return this.routes;
      return (this.result && this.result.routes) || [];
    },
    allPassed() {
      return this.result && this.result.passed === this.result.total;
    },
    progressText() {
      if (!this.progress || !this.progress.total)
        return this.$t('TRACKING_TEMPLATES.FICHA.TEST_RUNNING');
      return this.$t('TRACKING_TEMPLATES.FICHA.TEST_PROGRESS', {
        done: this.progress.done,
        total: this.progress.total,
      });
    },
  },
  watch: {
    payload: {
      deep: true,
      handler(nuevo) {
        if (this.result && JSON.stringify(nuevo) !== this.testedPayload)
          this.stale = true;
      },
    },
  },
  beforeDestroy() {
    clearTimeout(this.timer);
  },
  methods: {
    async run() {
      this.running = true;
      this.error = '';
      this.progress = null;
      this.polls = 0;
      this.testedPayload = JSON.stringify(this.payload);
      try {
        const turnId = `ficha-${Date.now()}`;
        if (this.templateId)
          await FichaAPI.testExisting(this.templateId, turnId);
        else await FichaAPI.test({ ...this.payload, turn_id: turnId });
        this.poll(turnId);
      } catch (error) {
        this.running = false;
        this.error = this.$t('TRACKING_TEMPLATES.FICHA.TEST_ERROR');
      }
    },
    poll(turnId) {
      this.timer = setTimeout(async () => {
        this.polls += 1;
        try {
          const { data } = await FichaAPI.testResult(turnId);
          if (data.done) {
            this.finish(data.result);
            return;
          }
          this.progress = data.progress || null;
        } catch (error) {
          // se reintenta en la siguiente vuelta
        }
        if (this.polls < MAX_POLLS) this.poll(turnId);
        else this.finish({ error: 'timeout' });
      }, POLL_MS);
    },
    finish(resultado) {
      this.running = false;
      if (!resultado || resultado.error) {
        this.error = this.$t('TRACKING_TEMPLATES.FICHA.TEST_ERROR');
        return;
      }
      this.result = resultado;
      this.stale = false;
      this.$emit('result', resultado);
    },
    routeOf(name) {
      return this.routeList.find(ruta => ruta.name === name);
    },
    // Emite la ruta (agente existente) y la llave del recurso (agente nuevo).
    add(item, routeName) {
      const ruta = this.routeOf(routeName);
      if (!ruta) return;
      this.$emit('addPhrase', {
        key: ruta.key,
        route: ruta.name,
        phrase: item.phrase,
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <div class="flex items-center justify-between gap-2">
      <span class="text-sm font-medium text-slate-800 dark:text-slate-100">
        {{ $t('TRACKING_TEMPLATES.FICHA.TEST_TITLE') }}
      </span>
      <woot-button
        size="tiny"
        variant="smooth"
        icon="arrow-clockwise"
        :is-loading="running"
        :is-disabled="disabled || running || (!templateId && !routes.length)"
        @click="run"
      >
        {{
          result
            ? $t('TRACKING_TEMPLATES.FICHA.TEST_AGAIN')
            : $t('TRACKING_TEMPLATES.FICHA.TEST_RUN')
        }}
      </woot-button>
    </div>

    <p v-if="running" class="!m-0 text-xs text-slate-500">{{ progressText }}</p>
    <p v-else-if="error" class="!m-0 text-xs text-red-600">{{ error }}</p>
    <p v-else-if="!result" class="!m-0 text-xs text-slate-500">
      {{ $t('TRACKING_TEMPLATES.FICHA.TEST_HINT') }}
    </p>

    <template v-if="result && !running">
      <p v-if="stale" class="!m-0 text-xs text-amber-800">
        {{ $t('TRACKING_TEMPLATES.FICHA.TEST_STALE') }}
      </p>
      <div
        class="flex items-center gap-2 text-xs"
        :class="allPassed ? 'text-green-700' : 'text-amber-800'"
      >
        <fluent-icon
          :icon="allPassed ? 'checkmark-circle' : 'warning'"
          size="14"
        />
        {{
          $t('TRACKING_TEMPLATES.FICHA.TEST_SCORE', {
            passed: result.passed,
            total: result.total,
          })
        }}
      </div>
      <ul
        v-if="failures.length"
        class="!m-0 !p-0 list-none flex flex-col gap-1 text-xs"
      >
        <li
          v-for="(item, index) in failures"
          :key="`f-${index}`"
          class="flex flex-col gap-0.5"
        >
          <span class="text-slate-700 dark:text-slate-200">
            {{
              $t('TRACKING_TEMPLATES.FICHA.TEST_QUOTE', { phrase: item.phrase })
            }}
            {{
              $t('TRACKING_TEMPLATES.FICHA.TEST_WENT', {
                got: item.got_label || '—',
                want: item.label,
              })
            }}
          </span>
          <woot-button
            size="tiny"
            variant="clear"
            icon="add"
            class="self-start"
            @click="add(item, item.route)"
          >
            {{
              $t('TRACKING_TEMPLATES.FICHA.TEST_ADD_TO', { route: item.label })
            }}
          </woot-button>
        </li>
      </ul>

      <div v-if="fallbacks.length" class="flex flex-col gap-1 text-xs">
        <span class="text-slate-600 dark:text-slate-300">
          {{ $t('TRACKING_TEMPLATES.FICHA.TEST_REAL_FALLBACK') }}
        </span>
        <div
          v-for="(item, index) in fallbacks"
          :key="`r-${index}`"
          class="flex flex-col gap-1 p-2 rounded bg-white dark:bg-slate-900"
        >
          <span class="text-slate-700 dark:text-slate-200">
            {{
              $t('TRACKING_TEMPLATES.FICHA.TEST_QUOTE', { phrase: item.phrase })
            }}
          </span>
          <div class="flex items-center gap-1">
            <select v-model="target[index]" class="!mb-0 !h-7 !py-0 text-xs">
              <option :value="undefined">
                {{ $t('TRACKING_TEMPLATES.FICHA.TEST_SEND_TO') }}
              </option>
              <option
                v-for="ruta in routeList"
                :key="ruta.name"
                :value="ruta.name"
              >
                {{ ruta.label }}
              </option>
            </select>
            <woot-button
              size="tiny"
              variant="smooth"
              :is-disabled="!target[index]"
              @click="add(item, target[index])"
            >
              {{ $t('TRACKING_TEMPLATES.FICHA.TEST_ADD') }}
            </woot-button>
          </div>
        </div>
      </div>
      <p v-if="understood.length" class="!m-0 text-xs text-slate-500">
        {{
          $t('TRACKING_TEMPLATES.FICHA.TEST_REAL_OK', {
            count: understood.length,
          })
        }}
      </p>
    </template>
  </div>
</template>
