# frozen_string_literal: true

require 'rails_helper'

# @waba_templates — validador puro de plantillas contra las reglas de Meta.
RSpec.describe Whatsapp::TemplateValidator do
  # Plantilla base VÁLIDA; cada caso sobreescribe lo que prueba.
  def build(**attrs)
    base = {
      name: 'cobro_vencido',
      language: 'es',
      body_text: 'Hola {{1}}, tu saldo es {{2}}.',
      sample_values: { 'body' => %w[Juan $100] }
    }
    described_class.call(WhatsappTemplate.new(base.merge(attrs)))
  end

  it 'acepta una plantilla válida' do
    result = build
    expect(result).to be_valid
    expect(result.errors).to be_empty
  end

  # feat/plantillas_whatsapp_mejoras
  describe 'categoría y orillas del cuerpo' do
    it 'rechaza autenticación (formato fijo de Meta)' do
      expect(build(category: 'AUTHENTICATION').errors).to include(a_string_matching(/autenticación.*WhatsApp Manager/))
      expect(build(category: 'UTILITY')).to be_valid
    end

    it 'rechaza un cuerpo que empieza o termina con variable' do
      inicio = build(body_text: '{{1}}, tu saldo es {{2}} pesos', sample_values: { 'body' => %w[Juan 100] })
      final = build(body_text: 'Hola {{1}}, tu saldo es {{2}}', sample_values: { 'body' => %w[Juan 100] })
      expect(inicio.errors).to include('Mensaje: no puede empezar con una variable')
      expect(final.errors).to include('Mensaje: no puede terminar con una variable (agrega un punto o texto después)')
    end

    it 'con un punto después de la variable pasa' do
      expect(build(body_text: 'Hola {{1}}, tu saldo es {{2}}.')).to be_valid
    end
  end

  # feat/plantillas_variables_chatwoot F9.1
  describe 'variables con nombre' do
    it 'acepta nombres, con un ejemplo por cada nombre distinto' do
      result = build(body_text: 'Hola {{nombre}}, tu edad es {{edad}} y {{nombre}} sigue.', sample_values: { 'body' => %w[Juan 34] })
      expect(result).to be_valid
    end

    it 'no deja mezclar números con nombres, ni entre encabezado y cuerpo' do
      mezcla = build(body_text: 'Hola {{1}} y {{edad}}.', sample_values: { 'body' => %w[a b] })
      expect(mezcla.errors).to include(a_string_matching(/no mezcles/))

      cruzada = build(header_type: 'text', header_content: 'Pedido {{pedido}}', body_text: 'Hola {{1}}.',
                      sample_values: { 'body' => ['a'], 'header' => ['b'] })
      expect(cruzada.errors).to include(a_string_matching(/no mezcles/))
    end

    it 'rechaza nombres que Meta no acepta' do
      ['{{Edad}}', '{{contact.name}}', '{{mi dato}}', '{{1a}}'].each do |variable|
        expect(build(body_text: "Hola #{variable}.", sample_values: { 'body' => ['a'] }).errors)
          .to include(a_string_matching(/no es válida/))
      end
    end

    it 'aplica las reglas de orilla, pie y encabezado a los nombres' do
      expect(build(body_text: '{{nombre}}, hola.', sample_values: { 'body' => ['a'] }).errors)
        .to include('Mensaje: no puede empezar con una variable')
      expect(build(footer_text: 'Hola {{nombre}}').errors).to include('Pie: no puede contener variables')
      expect(build(header_type: 'text', header_content: '{{a}} {{b}}', sample_values: { 'body' => %w[Juan $100], 'header' => ['x'] }).errors)
        .to include('Encabezado: máximo 1 variable')
    end
  end

  describe 'nombre' do
    it 'rechaza nombre con mayúsculas/espacios' do
      expect(build(name: 'Cobro Vencido').errors).to include(a_string_matching(/Nombre/))
    end

    it 'rechaza nombre vacío' do
      expect(build(name: '').errors).to include('Nombre: es obligatorio')
    end
  end

  describe 'body' do
    it 'exige cuerpo' do
      expect(build(body_text: '', sample_values: {}).errors).to include('Mensaje: es obligatorio')
    end

    it 'rechaza body > 1024' do
      expect(build(body_text: 'a' * 1025, sample_values: {}).errors).to include(a_string_matching(/Mensaje: excede/))
    end

    it 'exige variables contiguas ({{1}} {{3}} → falta {{2}})' do
      result = build(body_text: '{{1}} y {{3}}', sample_values: { 'body' => %w[a b] })
      expect(result.errors).to include('Mensaje: falta la variable {{2}}')
    end

    it 'exige que la primera variable sea {{1}}' do
      result = build(body_text: 'solo {{2}}', sample_values: { 'body' => %w[a] })
      expect(result.errors).to include('Mensaje: la primera variable debe ser {{1}}')
    end
  end

  describe 'header' do
    it 'texto: máximo 1 variable' do
      result = build(header_type: 'text', header_content: '{{1}} {{2}}',
                     sample_values: { 'body' => %w[Juan $100], 'header' => ['x'] })
      expect(result.errors).to include('Encabezado: máximo 1 variable')
    end

    it 'texto: la variable debe ser {{1}}' do
      result = build(header_type: 'text', header_content: 'Hola {{2}}',
                     sample_values: { 'body' => %w[Juan $100], 'header' => ['x'] })
      expect(result.errors).to include('Encabezado: la variable debe ser exactamente {{1}}')
    end

    it 'texto: rechaza > 60 caracteres' do
      expect(build(header_type: 'text', header_content: 'a' * 61).errors).to include(a_string_matching(/Encabezado: excede/))
    end

    it 'media: exige archivo (url o handle)' do
      expect(build(header_type: 'image').errors).to include('Encabezado: falta el archivo (súbelo o pega una liga)')
    end

    it 'media: acepta con header_media_url' do
      expect(build(header_type: 'image', header_media_url: 'https://x/y.png')).to be_valid
    end
  end

  describe 'footer' do
    it 'rechaza variables en el pie' do
      expect(build(footer_text: 'Gracias {{1}}').errors).to include('Pie: no puede contener variables')
    end

    it 'rechaza pie > 60' do
      expect(build(footer_text: 'a' * 61).errors).to include(a_string_matching(/Pie: excede/))
    end
  end

  describe 'botones' do
    it 'máximo 10 botones' do
      btns = Array.new(11) { |i| { 'type' => 'QUICK_REPLY', 'text' => "b#{i}" } }
      expect(build(buttons: btns).errors).to include(a_string_matching(/máximo 10/))
    end

    it 'URL sin url' do
      expect(build(buttons: [{ 'type' => 'URL', 'text' => 'Ver' }]).errors).to include('Botón #1 (liga): falta la liga')
    end

    it 'URL con {{1}} exige example' do
      result = build(buttons: [{ 'type' => 'URL', 'text' => 'Ver', 'url' => 'https://x/{{1}}' }])
      expect(result.errors).to include('Botón #1 (liga): falta el ejemplo de la liga completa')
    end

    it 'URL con {{1}} y su example pasa' do
      result = build(buttons: [{ 'type' => 'URL', 'text' => 'Ver', 'url' => 'https://x/{{1}}', 'example' => ['https://x/123'] }])
      expect(result).to be_valid
    end

    it 'teléfono sin phone_number' do
      expect(build(buttons: [{ 'type' => 'PHONE_NUMBER', 'text' => 'Llamar' }]).errors).to include('Botón #1 (teléfono): falta el número')
    end

    it 'COPY_CODE exige example' do
      expect(build(buttons: [{ 'type' => 'COPY_CODE' }]).errors).to include('Botón #1 (código): falta el código de ejemplo')
    end

    it 'COPY_CODE con example de hasta 15 pasa; de más, no' do
      expect(build(buttons: [{ 'type' => 'COPY_CODE', 'example' => ['DESCUENTO2026'] }])).to be_valid
      expect(build(buttons: [{ 'type' => 'COPY_CODE', 'example' => ['A' * 16] }]).errors)
        .to include('Botón #1 (código): el ejemplo admite hasta 15 caracteres')
    end

    it 'máximo 2 botones URL' do
      btns = Array.new(3) { { 'type' => 'URL', 'text' => 'Ver', 'url' => 'https://x' } }
      expect(build(buttons: btns).errors).to include('Botones: máximo 2 de tipo liga')
    end

    it 'texto de botón > 25' do
      expect(build(buttons: [{ 'type' => 'QUICK_REPLY', 'text' => 'a' * 26 }]).errors).to include(a_string_matching(/Botón #1: el texto excede/))
    end

    it 'QUICK_REPLY no puede ir después de un CTA' do
      btns = [
        { 'type' => 'URL', 'text' => 'Ver', 'url' => 'https://x' },
        { 'type' => 'QUICK_REPLY', 'text' => 'Sí' }
      ]
      expect(build(buttons: btns).errors).to include('Botones: las respuestas rápidas deben ir agrupadas al inicio')
    end

    it 'acepta QUICK_REPLY agrupados antes de un CTA' do
      btns = [
        { 'type' => 'QUICK_REPLY', 'text' => 'Sí' },
        { 'type' => 'QUICK_REPLY', 'text' => 'No' },
        { 'type' => 'URL', 'text' => 'Ver', 'url' => 'https://x' }
      ]
      expect(build(buttons: btns)).to be_valid
    end
  end

  describe 'sample values' do
    it 'exige 1:1 con las variables de body' do
      result = build(body_text: 'Hola {{1}} {{2}}', sample_values: { 'body' => %w[solo_uno] })
      expect(result.errors).to include(a_string_matching(/se requieren 2 valor/))
    end

    it 'rechaza valores de body vacíos' do
      result = build(body_text: 'Hola {{1}}', sample_values: { 'body' => [''] })
      expect(result.errors).to include('Ejemplos: hay ejemplos del mensaje vacíos')
    end

    it 'exige el sample de la cabecera de texto con variable' do
      result = build(header_type: 'text', header_content: 'Hola {{1}}',
                     sample_values: { 'body' => %w[Juan $100] })
      expect(result.errors).to include('Ejemplos: falta el ejemplo del encabezado')
    end
  end
end
