<script>
// proyecto@asistente_agentes_ia — LÍNEAS MARCADAS EN EL EDITOR DEL ENTRENAMIENTO
// ============================================================================
// Pedido del usuario (24/09/2026): una @ruta mal escrita tiene que verse en rojo EN
// EL CÓDIGO. Un <textarea> no pinta líneas, así que esto va DETRÁS de él: el mismo
// texto, invisible y con la misma caja, con el fondo de color en las líneas
// marcadas. El textarea va encima, transparente, y sigue siendo el que se edita.
//
// La caja se copia del textarea (tipografía, relleno, ancho sin la barra de
// desplazamiento) y se mide de nuevo cuando cambia de tamaño: si no coincidiera, las
// líneas largas cortarían en otro lugar y el color quedaría en la línea de al lado.
// El desplazamiento se copia en cada scroll.
// ============================================================================
// Una línea vacía sin nada adentro no ocupa alto: con un espacio de ancho cero sí.
const EMPTY_LINE = String.fromCharCode(0x200b);

const COPIED = [
  'fontFamily',
  'fontSize',
  'fontWeight',
  'lineHeight',
  'letterSpacing',
  'tabSize',
  'paddingTop',
  'paddingRight',
  'paddingBottom',
  'paddingLeft',
];

export default {
  props: {
    text: { type: String, default: '' },
    // { 12: 'blocking', 30: 'degrading' } — ver lineMarks en draftNavigation.js.
    marks: { type: Object, default: () => ({}) },
    // El <textarea>, cuando ya está montado.
    target: { type: null, default: null },
  },
  data() {
    return { box: {}, EMPTY_LINE };
  },
  computed: {
    hasMarks() {
      return Object.keys(this.marks).length > 0;
    },
    lines() {
      return this.text.split('\n').map((texto, i) => ({
        texto,
        level: this.marks[i + 1] || '',
      }));
    },
  },
  watch: {
    target() {
      this.attach();
    },
    // Mientras no hay marcas está oculto y no se alinea: al aparecer, se alinea.
    hasMarks() {
      this.$nextTick(this.sync);
    },
  },
  mounted() {
    this.attach();
  },
  beforeDestroy() {
    this.detach();
  },
  methods: {
    attach() {
      this.detach();
      if (!this.target) return;
      this.el = this.target;
      this.el.addEventListener('scroll', this.sync);
      if (window.ResizeObserver) {
        this.observer = new ResizeObserver(this.measure);
        this.observer.observe(this.el);
      }
      this.measure();
    },
    detach() {
      if (this.el) this.el.removeEventListener('scroll', this.sync);
      if (this.observer) this.observer.disconnect();
      this.el = null;
      this.observer = null;
    },
    measure() {
      const el = this.el;
      if (!el) return;
      const estilo = window.getComputedStyle(el);
      const box = {
        top: `${el.offsetTop + el.clientTop}px`,
        left: `${el.offsetLeft + el.clientLeft}px`,
        width: `${el.clientWidth}px`,
        height: `${el.clientHeight}px`,
      };
      COPIED.forEach(prop => {
        box[prop] = estilo[prop];
      });
      this.box = box;
      this.$nextTick(this.sync);
    },
    sync() {
      const fondo = this.$refs.backdrop;
      if (!fondo || !this.el) return;
      fondo.scrollTop = this.el.scrollTop;
      fondo.scrollLeft = this.el.scrollLeft;
    },
  },
};
</script>

<template>
  <div
    v-show="hasMarks"
    ref="backdrop"
    aria-hidden="true"
    class="absolute box-border overflow-hidden pointer-events-none select-none"
    :style="box"
  >
    <!-- El texto va en un <span> con pre-wrap y el <div> no: el salto de línea y
         la sangría que el template deja alrededor del texto, con pre-wrap, se
         pintaban como renglones de más — el color de las rutas bajaba hasta
         [ROL] (24/09/2026). En el <div> normal esos espacios no cuentan. -->
    <div
      v-for="(linea, index) in lines"
      :key="index"
      class="text-transparent [overflow-wrap:break-word]"
      :class="{
        'bg-red-100 dark:bg-red-900/40': linea.level === 'blocking',
        'bg-amber-50 dark:bg-amber-900/30': linea.level === 'degrading',
      }"
    >
      <span class="whitespace-pre-wrap">{{ linea.texto || EMPTY_LINE }}</span>
    </div>
  </div>
</template>
