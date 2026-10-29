import { shallowMount, mount } from '@vue/test-utils';
import TemplateHeader from '../TemplateHeader.vue';
import BubbleFile from '../File.vue';

// feat/plantillas_whatsapp_mejoras F3 — el archivo del encabezado de una plantilla en la burbuja
const montar = header =>
  shallowMount(TemplateHeader, { propsData: { header } });

describe('TemplateHeader', () => {
  it('pinta la imagen con liga para abrirla', () => {
    const wrapper = montar({
      media_url: 'https://cdn.mx/p.png',
      media_type: 'image',
    });

    expect(wrapper.find('img').attributes('src')).toBe('https://cdn.mx/p.png');
    expect(wrapper.find('a').attributes('href')).toBe('https://cdn.mx/p.png');
  });

  it('pinta el video con controles', () => {
    const wrapper = montar({
      media_url: 'https://cdn.mx/v.mp4',
      media_type: 'video',
    });

    expect(wrapper.find('video').attributes()).toMatchObject({
      src: 'https://cdn.mx/v.mp4',
      controls: 'controls',
    });
  });

  it('el documento sale con el nombre con que se mandó', () => {
    const wrapper = montar({
      media_url: 'https://cdn.mx/f.pdf',
      media_type: 'document',
      media_name: 'Factura A1.pdf',
    });

    expect(wrapper.findComponent(BubbleFile).props()).toEqual({
      url: 'https://cdn.mx/f.pdf',
      name: 'Factura A1.pdf',
    });
  });
});

describe('BubbleFile', () => {
  const opciones = {
    mocks: { $t: clave => clave },
    stubs: ['fluent-icon'],
  };

  it('con nombre muestra el nombre; sin él, el de la liga', () => {
    const conNombre = mount(BubbleFile, {
      ...opciones,
      propsData: { url: 'https://cdn.mx/x123.pdf', name: 'Factura A1.pdf' },
    });
    const sinNombre = mount(BubbleFile, {
      ...opciones,
      propsData: { url: 'https://cdn.mx/x123.pdf' },
    });

    expect(conNombre.text()).toContain('Factura A1.pdf');
    expect(sinNombre.text()).toContain('x123.pdf');
  });
});
