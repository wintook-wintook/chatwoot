<script>
// Motor 2.0 › Reglas: las palabras clave (exactas, las cumple el código al instante; el mismo
// editor del 1.0) y lo que el agente nunca debe hacer.
import formSection from './formSection';
import KeywordActionsEditor from 'dashboard/components/contacts/ContactTracking/KeywordActionsEditor.vue';

export default {
  components: { KeywordActionsEditor },
  mixins: [formSection],
};
</script>

<template>
  <div class="space-y-5">
    <div>
      <h4 class="m2-subtitle">{{ t('RULES.KEYWORDS') }}</h4>
      <p class="m2-hint">{{ t('RULES.KEYWORDS_HINT') }}</p>
      <KeywordActionsEditor
        :value="value.keywordActions"
        @input="list => set('keywordActions', list)"
      />
    </div>
    <label class="block">
      <span class="m2-subtitle block">{{ t('RULES.NEVER') }}</span>
      <textarea
        :value="m2.never"
        rows="4"
        :placeholder="t('RULES.NEVER_PH')"
        @input="setM2('never', $event.target.value)"
      />
    </label>
    <label class="block">
      <span class="m2-subtitle block">{{ t('RULES.WELCOME') }}</span>
      <p class="m2-hint">{{ t('RULES.WELCOME_HINT') }}</p>
      <textarea
        :value="m2.welcome"
        rows="3"
        @input="setM2('welcome', $event.target.value)"
      />
    </label>
  </div>
</template>
