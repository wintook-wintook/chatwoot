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
// Colores FIJOS, no los de la paleta (25/09/2026): con los temas de Apariencia el
// ámbar es una variable que cambia con cada tema, y el red-50/100 de Chatwoot es casi
// el color del fondo; la marca desaparecía. Semitransparentes para que se vean sobre
// fondo claro y oscuro, más una franja sólida a la izquierda que se ve siempre.
const LEVEL_COLORS = {
  blocking: { fill: 'rgba(239, 68, 68, 0.22)', stripe: '#dc2626' },
  degrading: { fill: 'rgba(245, 158, 11, 0.26)', stripe: '#d97706' },
};
const STRIPE_PX = 4;
const TOOLTIP_WIDTH = 360;

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
    // Qué dice cada línea marcada: { 12: [{ level, message }] } — ver lineMessages.
    messages: { type: Object, default: () => ({}) },
  },
  data() {
    // hover: la línea marcada bajo el mouse y dónde va su recuadro, o null.
    return { box: {}, EMPTY_LINE, hover: null, TOOLTIP_WIDTH };
  },
  computed: {
    hoverMessages() {
      return this.hover ? this.messages[this.hover.line] || [] : [];
    },
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
    // El fondo llega hasta el borde (entra en el relleno del editor) y la franja va en
    // ese borde, así no tapa ni corre el texto.
    lineStyle(level) {
      const colores = LEVEL_COLORS[level];
      if (!colores) return null;
      const izq = this.box.paddingLeft || '0px';
      const der = this.box.paddingRight || '0px';
      return {
        backgroundColor: colores.fill,
        boxShadow: `inset ${STRIPE_PX}px 0 0 ${colores.stripe}`,
        marginLeft: `-${izq}`,
        paddingLeft: izq,
        marginRight: `-${der}`,
        paddingRight: der,
      };
    },
    attach() {
      this.detach();
      if (!this.target) return;
      this.el = this.target;
      this.el.addEventListener('scroll', this.sync);
      this.el.addEventListener('mousemove', this.onMove);
      this.el.addEventListener('mouseleave', this.onLeave);
      if (window.ResizeObserver) {
        this.observer = new ResizeObserver(this.measure);
        this.observer.observe(this.el);
      }
      this.measure();
    },
    detach() {
      if (this.el) {
        this.el.removeEventListener('scroll', this.sync);
        this.el.removeEventListener('mousemove', this.onMove);
        this.el.removeEventListener('mouseleave', this.onLeave);
      }
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
      this.hover = null;
      const fondo = this.$refs.backdrop;
      if (!fondo || !this.el) return;
      fondo.scrollTop = this.el.scrollTop;
      fondo.scrollLeft = this.el.scrollLeft;
    },
    // El fondo está DETRÁS del editor: el mouse nunca lo toca. Se busca qué línea
    // marcada tiene el mouse encima comparando con el lugar de cada una (solo las
    // marcadas: son pocas). El recuadro va justo debajo de esa línea.
    onMove(event) {
      const filas = this.$refs.lines || [];
      const marcada = Object.keys(this.messages)
        .map(Number)
        .find(numero => {
          const caja = filas[numero - 1]?.getBoundingClientRect();
          return (
            caja && event.clientY >= caja.top && event.clientY < caja.bottom
          );
        });
      if (!marcada) {
        this.hover = null;
        return;
      }
      const marco = this.$el.parentElement.getBoundingClientRect();
      const fila = filas[marcada - 1].getBoundingClientRect();
      // En la parte de abajo del editor el recuadro va ARRIBA de la línea: debajo se
      // saldría del marco.
      const abajo = fila.bottom - marco.top > marco.height * 0.6;
      this.hover = {
        line: marcada,
        position: abajo
          ? { bottom: `${marco.bottom - fila.top + 4}px` }
          : { top: `${fila.bottom - marco.top + 4}px` },
        left: Math.max(
          8,
          Math.min(
            event.clientX - marco.left - 40,
            marco.width - TOOLTIP_WIDTH - 8
          )
        ),
      };
    },
    onLeave() {
      this.hover = null;
    },
  },
};
</script>

<template>
  <!-- `contents`: no arma caja propia; el fondo y el recuadro se ubican respecto del
       marco del editor (el padre, relative). -->
  <div class="contents">
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
        ref="lines"
        :key="index"
        class="text-transparent [overflow-wrap:break-word]"
        :style="lineStyle(linea.level)"
      >
        <span class="whitespace-pre-wrap">{{ linea.texto || EMPTY_LINE }}</span>
      </div>
    </div>
    <!-- El aviso de la línea bajo el mouse (pedido del usuario, 25/09/2026). -->
    <div
      v-if="hover && hoverMessages.length"
      class="absolute z-20 flex flex-col gap-1 p-2 text-xs rounded-md shadow-lg pointer-events-none bg-slate-800 text-slate-50 dark:bg-slate-100 dark:text-slate-900"
      :style="{
        ...hover.position,
        left: `${hover.left}px`,
        width: `${TOOLTIP_WIDTH}px`,
      }"
    >
      <p v-for="(aviso, i) in hoverMessages" :key="i" class="!m-0 leading-snug">
        {{ aviso.level === 'blocking' ? '🔴' : '🟡' }} {{ aviso.message }}
      </p>
    </div>
  </div>
</template>
