<script>
// Motor 2.0 › Agente: quién es, qué busca y por dónde atiende. El canal y los intentos son los
// mismos campos del 1.0 (FichaChannel, sin cambios): los usan las campañas y los intentos.
import formSection from './formSection';
import FichaChannel from '../contactTrackings/ficha/FichaChannel.vue';

export default {
  components: { FichaChannel },
  mixins: [formSection],
};
</script>

<template>
  <div class="space-y-4">
    <div class="grid gap-3 md:grid-cols-2">
      <label class="block">
        <span class="m2-label">{{ t('AGENT.NAME') }}</span>
        <input
          :value="value.name"
          type="text"
          maxlength="100"
          :placeholder="t('AGENT.NAME_PH')"
          @input="set('name', $event.target.value)"
        />
      </label>
      <label class="block">
        <span class="m2-label">{{ t('AGENT.DISPLAY_NAME') }}</span>
        <input
          :value="value.customer_display_name"
          type="text"
          maxlength="30"
          :placeholder="t('AGENT.DISPLAY_NAME_PH')"
          @input="set('customer_display_name', $event.target.value)"
        />
      </label>
    </div>
    <label class="block">
      <span class="m2-label">{{ t('AGENT.OBJECTIVE') }}</span>
      <textarea
        :value="value.objective"
        rows="2"
        maxlength="500"
        :placeholder="t('AGENT.OBJECTIVE_PH')"
        @input="set('objective', $event.target.value)"
      />
    </label>
    <label class="block">
      <span class="m2-label">{{ t('AGENT.CONTEXT') }}</span>
      <textarea
        :value="value.ai_context"
        rows="3"
        :placeholder="t('AGENT.CONTEXT_PH')"
        @input="set('ai_context', $event.target.value)"
      />
    </label>
    <div class="flex items-center gap-3">
      <span class="m2-label !mb-0">{{ t('AGENT.TONE') }}</span>
      <label
        v-for="tone in ['tu', 'usted']"
        :key="tone"
        class="flex items-center gap-1 text-sm"
      >
        <input
          type="radio"
          class="!mb-0"
          :checked="m2.tone === tone"
          @change="setM2('tone', tone)"
        />
        {{ t(`AGENT.TONE_${tone.toUpperCase()}`) }}
      </label>
    </div>
    <div>
      <h4 class="m2-subtitle">{{ t('AGENT.CHANNEL') }}</h4>
      <FichaChannel
        :value="value.channel"
        @input="channel => set('channel', channel)"
      />
    </div>
  </div>
</template>
