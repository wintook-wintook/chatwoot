<script setup>
defineProps({
  active: {
    type: Boolean,
    default: false,
  },
  title: {
    type: String,
    default: '',
  },
  name: {
    type: String,
    default: '',
  },
  swatches: {
    type: Array,
    default: () => [],
  },
});

defineEmits(['click']);
</script>

<template>
  <div
    class="flex flex-col gap-3 w-full h-fit p-4 rounded-md border border-solid border-ash-200 cursor-pointer"
    :class="{ 'border-primary-300': active }"
    @click="$emit('click')"
  >
    <div class="flex items-center justify-between w-full gap-1">
      <div class="flex items-center text-base font-medium text-ash-900">
        {{ title }}
      </div>
      <input
        :checked="active"
        type="radio"
        :name="name"
        class="shadow cursor-pointer grid place-items-center border-2 border-ash-200 appearance-none rounded-full w-5 h-5 checked:bg-primary-600 before:content-[''] before:bg-primary-600 before:border-4 before:rounded-full before:border-ash-25 checked:before:w-[18px] checked:before:h-[18px] checked:border checked:border-primary-600"
      />
    </div>
    <div
      class="flex w-full h-8 overflow-hidden rounded border border-solid border-ash-200"
    >
      <span
        v-for="swatch in swatches"
        :key="swatch"
        class="flex-1 h-full"
        :style="{ backgroundColor: swatch }"
      />
    </div>
  </div>
</template>
