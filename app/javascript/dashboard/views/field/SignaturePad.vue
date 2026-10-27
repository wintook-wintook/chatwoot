<!--
  Plan-Trabajo-Campo R2 — firma con el dedo (o el mouse). `v-model` es la
  imagen PNG en data-URL ('' si no hay firma).
-->
<script>
export default {
  name: 'SignaturePad',
  props: {
    value: { type: String, default: '' },
  },
  emits: ['input'],
  data() {
    return { drawing: false, ctx: null };
  },
  watch: {
    // Si quien lo usa limpia la firma, se borra el lienzo.
    value(newValue) {
      if (!newValue && this.ctx) {
        const canvas = this.$refs.canvas;
        this.ctx.clearRect(0, 0, canvas.width, canvas.height);
      }
    },
  },
  mounted() {
    const canvas = this.$refs.canvas;
    const box = canvas.getBoundingClientRect();
    canvas.width = box.width;
    canvas.height = box.height;
    this.ctx = canvas.getContext('2d');
    this.ctx.lineWidth = 2;
    this.ctx.lineCap = 'round';
  },
  methods: {
    point(event) {
      const box = this.$refs.canvas.getBoundingClientRect();
      const p = event.touches ? event.touches[0] : event;
      return { x: p.clientX - box.left, y: p.clientY - box.top };
    },
    start(event) {
      this.drawing = true;
      const p = this.point(event);
      this.ctx.beginPath();
      this.ctx.moveTo(p.x, p.y);
    },
    move(event) {
      if (!this.drawing) return;
      const p = this.point(event);
      this.ctx.lineTo(p.x, p.y);
      this.ctx.stroke();
    },
    end() {
      if (!this.drawing) return;
      this.drawing = false;
      this.$emit('input', this.$refs.canvas.toDataURL('image/png'));
    },
    clear() {
      const canvas = this.$refs.canvas;
      this.ctx.clearRect(0, 0, canvas.width, canvas.height);
      this.$emit('input', '');
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-1">
    <canvas
      ref="canvas"
      class="w-full h-36 bg-white border border-dashed rounded-lg touch-none border-slate-300"
      @mousedown.prevent="start"
      @mousemove.prevent="move"
      @mouseup="end"
      @mouseleave="end"
      @touchstart.prevent="start"
      @touchmove.prevent="move"
      @touchend="end"
    />
    <button
      type="button"
      class="self-end p-0 text-sm text-slate-500"
      @click="clear"
    >
      {{ $t('FIELD.CLEAR') }}
    </button>
  </div>
</template>
