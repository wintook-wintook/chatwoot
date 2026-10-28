<script setup>
import BackButton from '../../../../components/widgets/BackButton.vue';
defineProps({
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    required: true,
  },
  iconName: {
    type: String,
    default: '',
  },
  // eslint-disable-next-line vue/no-unused-properties -- se acepta, ya no se muestra
  linkText: {
    type: String,
    default: '',
  },
  // eslint-disable-next-line vue/no-unused-properties -- se acepta, ya no se muestra
  featureName: {
    type: String,
    default: '',
  },
  backButtonLabel: {
    type: String,
    default: '',
  },
});

// Sin el enlace «Aprende más sobre…» a la ayuda de Chatwoot (en inglés): `linkText`
// y `featureName` se siguen aceptando para no tocar cada página, pero ya no se muestran.
</script>

<template>
  <div class="flex flex-col items-start w-full gap-2 pt-4">
    <BackButton
      v-if="backButtonLabel"
      compact
      :button-label="backButtonLabel"
    />
    <div class="flex items-center justify-between w-full gap-4">
      <div class="flex items-center gap-3">
        <div
          v-if="iconName"
          class="flex items-center w-10 h-10 p-1 rounded-full bg-woot-25/60 dark:bg-woot-900/60"
        >
          <div
            class="flex items-center justify-center w-full h-full rounded-full bg-woot-75/70 dark:bg-woot-800/40"
          >
            <fluent-icon
              size="14"
              :icon="iconName"
              type="outline"
              class="flex-shrink-0 text-woot-500 dark:text-woot-500"
            />
          </div>
        </div>
        <h1
          class="text-2xl font-semibold font-interDisplay tracking-[0.3px] text-slate-900 dark:text-slate-25"
        >
          {{ title }}
        </h1>
      </div>
      <!-- Slot for additional actions on larger screens -->
      <div class="hidden gap-2 sm:flex">
        <slot name="actions" />
      </div>
    </div>
    <div class="flex flex-col gap-3 text-slate-600 dark:text-slate-300 w-full">
      <p
        class="mb-0 text-base font-normal line-clamp-5 sm:line-clamp-none max-w-3xl tracking-[-0.1px]"
      >
        <slot name="description">{{ description }}</slot>
      </p>
    </div>
    <div
      class="flex items-start justify-start w-full gap-3 sm:hidden flex-wrap"
    >
      <slot name="actions" />
    </div>
  </div>
</template>
