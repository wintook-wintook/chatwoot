<script>
// proyecto@asistente_agentes_ia — BUSCAR UNA RAMA QUE YA EXISTE
// ============================================================================
// Las ramas que la cuenta ya escribió, en fichas, para copiar una al agente que se
// está armando en vez de escribirla de cero. Sirve de dos maneras: se ahorra el
// trabajo, y se ve CÓMO están escritas las que ya funcionan —qué frases de cliente
// usan, con qué fuente, qué escalan—, que es lo más difícil de acertar de una rama.
//
// La ficha muestra las dos mitades de una rama: la línea @ruta y su línea de
// [ALCANCE POR RAMA] (ver RouteModal), porque al copiarla se copian las dos.
//
// Una rama con un nombre que el agente ya tiene NO se puede agregar: para el motor
// existe una sola con ese nombre, se queda con la primera y la otra no se elige
// nunca. Se muestra igual, marcada: verla es la mitad de la utilidad.
// ============================================================================
export default {
  props: {
    show: { type: Boolean, default: false },
    // [{ name, tag, description, source, escalation, action, case_type, priority,
    //    scope, agents: [...] }] — ver ContactTrackings::TrainingRouteCatalog.
    routes: { type: Array, default: () => [] },
    isLoading: { type: Boolean, default: false },
    // Los nombres que el agente ya tiene: esos no se pueden repetir.
    takenNames: { type: Array, default: () => [] },
  },
  emits: ['close', 'pick'],
  data() {
    return {
      query: '',
    };
  },
  computed: {
    // Busca por nombre, por las frases del cliente, por la fuente y por el agente de
    // donde sale: son las cuatro formas en que alguien recuerda una rama.
    filtered() {
      const q = this.query.trim().toLowerCase();
      if (!q) return this.routes;
      return this.routes.filter(r =>
        [
          r.name,
          r.description,
          r.source,
          r.escalation,
          (r.agents || []).join(' '),
        ]
          .join(' ')
          .toLowerCase()
          .includes(q)
      );
    },
  },
  watch: {
    show(abierto) {
      if (abierto) this.query = '';
    },
  },
  methods: {
    taken(route) {
      return this.takenNames.includes(route.name);
    },
    pick(route) {
      if (this.taken(route)) return;
      // Sin `raw` ni `agents`: la línea se escribe de cero en este agente.
      const { agents, raw, scope, ...campos } = route;
      this.$emit('pick', {
        route: { kind: 'route', ...campos },
        scope: scope || '',
      });
    },
  },
};
</script>

<template>
  <woot-modal :show="show" size="medium" :on-close="() => $emit('close')">
    <div class="flex flex-col gap-4 p-8 text-sm max-h-[85vh]">
      <div class="shrink-0">
        <h2 class="!m-0 text-lg font-medium text-slate-800 dark:text-slate-100">
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_FIND_TITLE') }}
        </h2>
        <p class="!mt-1 !mb-0 text-xs text-slate-500 dark:text-slate-400">
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_FIND_HINT') }}
        </p>
      </div>

      <input
        id="route-catalog-search"
        v-model="query"
        type="text"
        class="w-full !mb-0 shrink-0"
        :placeholder="$t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_FIND_SEARCH')"
      />

      <p
        v-if="isLoading"
        class="!m-0 text-xs text-slate-500 dark:text-slate-400"
      >
        {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_FIND_LOADING') }}
      </p>
      <p
        v-else-if="!filtered.length"
        class="!m-0 py-6 text-xs text-center text-slate-500 dark:text-slate-400"
      >
        {{
          routes.length
            ? $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_FIND_NO_MATCH')
            : $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_FIND_EMPTY')
        }}
      </p>

      <!-- La lista scrollea: la cuenta puede tener decenas de ramas escritas. -->
      <div class="flex flex-col flex-1 min-h-0 gap-2 overflow-y-auto">
        <div
          v-for="(rama, i) in filtered"
          :key="`${rama.name}-${i}`"
          class="p-3 border rounded-md border-slate-200 dark:border-slate-600"
        >
          <div class="flex items-start gap-2">
            <div class="flex-1 min-w-0">
              <p
                class="!m-0 font-mono text-xs text-slate-800 dark:text-slate-100"
              >
                {{ rama.name }}
                <span v-if="rama.tag" class="text-slate-400">
                  #{{ rama.tag }}
                </span>
              </p>
              <p class="!mt-1 !mb-0 text-xs text-slate-600 dark:text-slate-300">
                {{ rama.description }}
              </p>
            </div>
            <woot-button
              size="tiny"
              variant="smooth"
              color-scheme="success"
              icon="add"
              :is-disabled="taken(rama)"
              :title="
                taken(rama)
                  ? $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_FIND_TAKEN')
                  : ''
              "
              @click="pick(rama)"
            >
              {{
                taken(rama)
                  ? $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_FIND_TAKEN')
                  : $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_FIND_USE')
              }}
            </woot-button>
          </div>

          <dl
            class="grid grid-cols-[auto,1fr] gap-x-2 gap-y-0.5 !mt-2 !mb-0 text-xs"
          >
            <dt class="text-slate-400">
              {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SOURCE') }}
            </dt>
            <dd class="!m-0 font-mono text-slate-600 dark:text-slate-300">
              {{
                rama.source ||
                $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_SOURCE_NONE')
              }}
            </dd>
            <dt class="text-slate-400">
              {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_ESCALATION') }}
            </dt>
            <dd class="!m-0 font-mono text-slate-600 dark:text-slate-300">
              {{
                rama.escalation ||
                $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_ESCALATION_NONE')
              }}
            </dd>
            <template v-if="rama.scope">
              <dt class="text-slate-400">
                {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_FIND_SCOPE') }}
              </dt>
              <dd class="!m-0 text-slate-600 dark:text-slate-300">
                {{ rama.scope }}
              </dd>
            </template>
            <dt class="text-slate-400">
              {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_FIND_AGENTS') }}
            </dt>
            <dd class="!m-0 text-slate-500 dark:text-slate-400">
              {{ (rama.agents || []).join(' · ') }}
            </dd>
          </dl>
        </div>
      </div>

      <div class="flex items-center justify-end shrink-0">
        <woot-button
          variant="clear"
          color-scheme="secondary"
          @click="$emit('close')"
        >
          {{ $t('TRACKING_TEMPLATES.FORM.TRAINING.ROUTE_MODAL_CANCEL') }}
        </woot-button>
      </div>
    </div>
  </woot-modal>
</template>
