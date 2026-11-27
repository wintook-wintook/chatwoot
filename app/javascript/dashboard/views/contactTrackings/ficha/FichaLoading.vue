<script>
// feat/ficha_agente_ia — «CARGANDO» CON UN BOT ANIMADO
// ============================================================================
// Pedido del usuario (10/11/2026): «cuando voy a Recursos se ve un mensaje cargando, me
// gustaría algo más vistoso, como un gif de un agente, un bot». SVG + animación CSS (no
// un archivo): nítido a cualquier tamaño, sigue el modo oscuro y respeta
// «reducir movimiento» del sistema.
// ============================================================================
export default {
  props: {
    // El texto debajo del bot (ya traducido); por omisión «Preparando tus recursos…».
    text: { type: String, default: '' },
  },
};
</script>

<template>
  <div
    class="flex flex-col items-center justify-center flex-1 gap-3 py-10"
    role="status"
    aria-live="polite"
  >
    <svg
      class="ficha-bot"
      width="96"
      height="96"
      viewBox="0 0 96 96"
      aria-hidden="true"
    >
      <!-- sombra -->
      <ellipse class="ficha-bot__shadow" cx="48" cy="88" rx="22" ry="4" />
      <g class="ficha-bot__body">
        <!-- antena -->
        <line x1="48" y1="14" x2="48" y2="24" class="ficha-bot__line" />
        <circle cx="48" cy="11" r="4" class="ficha-bot__antenna" />
        <!-- cabeza -->
        <rect
          x="20"
          y="24"
          width="56"
          height="42"
          rx="14"
          class="ficha-bot__head"
        />
        <!-- orejas -->
        <rect
          x="14"
          y="38"
          width="6"
          height="14"
          rx="3"
          class="ficha-bot__ear"
        />
        <rect
          x="76"
          y="38"
          width="6"
          height="14"
          rx="3"
          class="ficha-bot__ear"
        />
        <!-- cara -->
        <rect
          x="28"
          y="32"
          width="40"
          height="26"
          rx="10"
          class="ficha-bot__face"
        />
        <ellipse cx="39" cy="44" rx="4" ry="5" class="ficha-bot__eye" />
        <ellipse cx="57" cy="44" rx="4" ry="5" class="ficha-bot__eye" />
        <path d="M41 52 Q48 56 55 52" class="ficha-bot__smile" />
        <!-- cuerpo -->
        <rect
          x="32"
          y="68"
          width="32"
          height="12"
          rx="6"
          class="ficha-bot__head"
        />
      </g>
    </svg>
    <div class="flex items-center gap-1" aria-hidden="true">
      <span class="ficha-bot__dot" />
      <span class="ficha-bot__dot" />
      <span class="ficha-bot__dot" />
    </div>
    <span class="text-sm text-slate-500 dark:text-slate-400">
      {{ text || $t('TRACKING_TEMPLATES.FICHA.LOADING_BOT') }}
    </span>
  </div>
</template>

<style scoped>
.ficha-bot__body {
  animation: ficha-bot-float 2.4s ease-in-out infinite;
  transform-origin: 48px 48px;
}
.ficha-bot__shadow {
  fill: rgb(148 163 184 / 0.35);
  animation: ficha-bot-shadow 2.4s ease-in-out infinite;
  transform-origin: 48px 88px;
}
.ficha-bot__head {
  fill: var(--w-500, #1f93ff);
}
.ficha-bot__ear {
  fill: var(--w-400, #52a7ff);
}
.ficha-bot__face {
  fill: #fff;
}
.ficha-bot__eye {
  fill: rgb(30 41 59);
  animation: ficha-bot-blink 3.2s infinite;
  transform-box: fill-box;
  transform-origin: center;
}
.ficha-bot__smile {
  fill: none;
  stroke: rgb(30 41 59);
  stroke-width: 2.5;
  stroke-linecap: round;
}
.ficha-bot__line {
  stroke: var(--w-500, #1f93ff);
  stroke-width: 3;
  stroke-linecap: round;
}
.ficha-bot__antenna {
  fill: #fbbf24;
  animation: ficha-bot-glow 1.2s ease-in-out infinite alternate;
}
.ficha-bot__dot {
  width: 7px;
  height: 7px;
  border-radius: 9999px;
  background: var(--w-500, #1f93ff);
  animation: ficha-bot-dots 1.2s ease-in-out infinite;
}
.ficha-bot__dot:nth-child(2) {
  animation-delay: 0.2s;
}
.ficha-bot__dot:nth-child(3) {
  animation-delay: 0.4s;
}
@media (prefers-color-scheme: dark) {
  .ficha-bot__face {
    fill: rgb(30 41 59);
  }
  .ficha-bot__eye {
    fill: #fff;
  }
  .ficha-bot__smile {
    stroke: #fff;
  }
}
@keyframes ficha-bot-float {
  0%,
  100% {
    transform: translateY(0) rotate(-2deg);
  }
  50% {
    transform: translateY(-6px) rotate(2deg);
  }
}
@keyframes ficha-bot-shadow {
  0%,
  100% {
    transform: scaleX(1);
    opacity: 0.6;
  }
  50% {
    transform: scaleX(0.8);
    opacity: 0.35;
  }
}
@keyframes ficha-bot-blink {
  0%,
  92%,
  100% {
    transform: scaleY(1);
  }
  95% {
    transform: scaleY(0.1);
  }
}
@keyframes ficha-bot-glow {
  from {
    opacity: 0.5;
  }
  to {
    opacity: 1;
  }
}
@keyframes ficha-bot-dots {
  0%,
  80%,
  100% {
    transform: translateY(0);
    opacity: 0.4;
  }
  40% {
    transform: translateY(-5px);
    opacity: 1;
  }
}
@media (prefers-reduced-motion: reduce) {
  .ficha-bot__body,
  .ficha-bot__shadow,
  .ficha-bot__eye,
  .ficha-bot__antenna,
  .ficha-bot__dot {
    animation: none;
  }
}
</style>
