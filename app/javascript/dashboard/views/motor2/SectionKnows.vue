<script>
// Motor 2.0 › Qué sabe: las fuentes que el agente consulta (las tarjetas del 1.0, FichaCards,
// sin cambios) y los datos fijos del negocio (FichaBusiness). Sin directivas: se marcan y ya.
import formSection from './formSection';
import FichaCards from '../contactTrackings/ficha/FichaCards.vue';
import FichaBusiness from '../contactTrackings/ficha/FichaBusiness.vue';

export default {
  components: { FichaCards, FichaBusiness },
  mixins: [formSection],
  computed: {
    // Las respuestas predefinidas van siempre: no se marcan, solo se avisa si algo falta.
    canned() {
      return (this.options.sources || []).find(c => c.kind === 'canned');
    },
    others() {
      return (this.options.sources || []).filter(c => c.kind !== 'canned');
    },
  },
};
</script>

<template>
  <div class="space-y-5">
    <div>
      <h4 class="m2-subtitle">{{ t('KNOWS.SOURCES') }}</h4>
      <p class="m2-hint">{{ t('KNOWS.SOURCES_HINT') }}</p>
      <p class="p-2 m-0 mb-2 text-xs rounded bg-slate-50 dark:bg-slate-800">
        {{ t('KNOWS.CANNED_ALWAYS') }}
        <span v-if="canned && canned.warning" class="block text-amber-700">
          {{ t('KNOWS.CANNED_WARN', { text: canned.warning }) }}
        </span>
      </p>
      <p v-if="!others.length" class="m2-hint">
        {{ t('KNOWS.NO_SOURCES') }}
      </p>
      <FichaCards
        v-else
        :cards="others"
        :value="m2.sources"
        :show-headers="false"
        @input="list => setM2('sources', list)"
      />
    </div>
    <div>
      <h4 class="m2-subtitle">{{ t('KNOWS.BUSINESS') }}</h4>
      <p class="m2-hint">
        {{ t('KNOWS.BUSINESS_SHARED') }}
        <router-link :to="{ name: 'ai_voice' }" class="text-woot-600">
          {{ t('KNOWS.BUSINESS_EDIT') }}
        </router-link>
      </p>
      <ul
        v-if="(options.business || []).length"
        class="p-2 mb-3 text-xs list-none rounded bg-slate-50 dark:bg-slate-800"
      >
        <li v-for="(line, i) in options.business" :key="i">{{ line }}</li>
      </ul>
      <p v-else class="m2-hint text-amber-700">
        {{ t('KNOWS.BUSINESS_EMPTY') }}
      </p>
      <h4 class="m2-subtitle">{{ t('KNOWS.BUSINESS_OWN') }}</h4>
      <p class="m2-hint">{{ t('KNOWS.BUSINESS_HINT') }}</p>
      <FichaBusiness
        :value="m2.business"
        :agent-name="value.customer_display_name"
        @input="rows => setM2('business', rows)"
      />
    </div>
  </div>
</template>
