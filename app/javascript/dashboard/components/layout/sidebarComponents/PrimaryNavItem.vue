<script>
// feat/apariencia B2 — cada área del menú con su color: se ubica más rápido dónde
// estás. Las escalas (sky, grass, orange…) traen su versión oscura, así que sirven
// en los dos modos; Inicio usa el color del tema y Ajustes queda neutro.
// Clases completas (no armadas) para que Tailwind las genere.
const TONES = {
  inicio: {
    idle: 'text-woot-600 dark:text-woot-300 hover:bg-woot-25 dark:hover:bg-woot-800/40',
    active: 'bg-woot-75 dark:bg-woot-800 text-woot-700 dark:text-woot-100',
  },
  conversations: {
    idle: 'text-sky-600 hover:bg-sky-50',
    active: 'bg-sky-100 text-sky-700',
  },
  agenda: {
    idle: 'text-purple-600 hover:bg-purple-50',
    active: 'bg-purple-100 text-purple-700',
  },
  ventas: {
    idle: 'text-grass-600 hover:bg-grass-50',
    active: 'bg-grass-100 text-grass-700',
  },
  servicio: {
    idle: 'text-orange-600 hover:bg-orange-50',
    active: 'bg-orange-100 text-orange-700',
  },
  contacts: {
    idle: 'text-indigo-600 hover:bg-indigo-50',
    active: 'bg-indigo-100 text-indigo-700',
  },
  campaigns: {
    idle: 'text-pink-600 hover:bg-pink-50',
    active: 'bg-pink-100 text-pink-700',
  },
  agentes: {
    idle: 'text-teal-600 hover:bg-teal-50',
    active: 'bg-teal-100 text-teal-700',
  },
  reports: {
    idle: 'text-amber-700 hover:bg-amber-50',
    active: 'bg-amber-100 text-amber-800',
  },
};
const NEUTRAL = {
  idle: 'text-slate-600 dark:text-slate-300 hover:bg-slate-25 dark:hover:bg-slate-700',
  active: 'bg-slate-75 dark:bg-slate-800 text-slate-800 dark:text-slate-100',
};

export default {
  props: {
    // Área del menú (inicio, ventas, servicio…): da el color. Sin área, neutro.
    area: {
      type: String,
      default: '',
    },
    to: {
      type: String,
      default: '',
    },
    name: {
      type: String,
      default: '',
    },
    icon: {
      type: String,
      default: '',
    },
    count: {
      type: String,
      default: '',
    },
    isChildMenuActive: {
      type: Boolean,
      default: false,
    },
    openInNewPage: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    tone() {
      return TONES[this.area] || NEUTRAL;
    },
    isExternal() {
      return /^(https?:)?\/\//.test(this.to);
    },
  },
};
</script>

<template>
  <!-- Link externo (el foro de ayuda): router-link lo tomaría como ruta interna
       y abriría /https://… dentro de la app. -->
  <a
    v-if="isExternal"
    v-tooltip.right="$t(`SIDEBAR.${name}`)"
    :href="to"
    class="relative flex items-center justify-center w-10 h-10 my-2 transition-colors rounded-lg"
    :class="tone.idle"
    :rel="openInNewPage ? 'noopener noreferrer nofollow' : undefined"
    :target="openInNewPage ? '_blank' : undefined"
  >
    <fluent-icon :icon="icon" />
    <span class="sr-only">{{ name }}</span>
  </a>
  <router-link v-else v-slot="{ href, isActive, navigate }" :to="to" custom>
    <a
      v-tooltip.right="$t(`SIDEBAR.${name}`)"
      :href="href"
      class="relative flex items-center justify-center w-10 h-10 my-2 transition-colors rounded-lg"
      :class="isActive || isChildMenuActive ? tone.active : tone.idle"
      :rel="openInNewPage ? 'noopener noreferrer nofollow' : undefined"
      :target="openInNewPage ? '_blank' : undefined"
      @click="navigate"
    >
      <fluent-icon :icon="icon" />
      <span class="sr-only">{{ name }}</span>
      <span
        v-if="count"
        class="text-black-900 bg-yellow-300 absolute -top-0.5 -right-1 text-xxs min-w-[1rem] rounded-full text-center"
      >
        {{ count }}
      </span>
    </a>
  </router-link>
</template>
