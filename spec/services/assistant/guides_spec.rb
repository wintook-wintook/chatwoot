# frozen_string_literal: true

require 'rails_helper'

# El candado de las guías de uso (config/assistant/guides): si se renombra una pantalla
# de open_page, se agrega un área sin guía o una guía queda incompleta, esto falla.
RSpec.describe Assistant::Guides do
  let(:admin) { Access::Grant.new(nil, nil) }
  let(:guides) { described_class.all }

  def grant_with(*areas)
    instance_double(Access::Grant, allowed?: false).tap do |grant|
      areas.each { |area| allow(grant).to receive(:allowed?).with(area).and_return(true) }
    end
  end

  describe 'los archivos' do
    it 'hay guías' do
      expect(guides).not_to be_empty
    end

    it 'cada una tiene cabecera completa y su clave es el nombre del archivo' do
      files = Dir[described_class::DIR.join('*.md')].map { |path| File.basename(path, '.md') }.sort
      expect(guides.map(&:key).sort).to eq(files)
      guides.each do |guide|
        expect(guide.title).to be_present, "#{guide.key}: falta title"
        expect(guide.keywords).to be_present, "#{guide.key}: faltan keywords"
        expect(guide.body).to match(/^## /), "#{guide.key}: el texto necesita secciones ##"
      end
    end

    it 'las áreas existen' do
      guides.each do |guide|
        expect(guide.areas - AccessRole::AREAS).to be_empty, "#{guide.key}: área desconocida #{guide.areas - AccessRole::AREAS}"
      end
    end

    it 'las pantallas que mencionan existen en open_page' do
      guides.each do |guide|
        unknown = guide.pages - Assistant::Pages::MAP.keys
        expect(unknown).to be_empty, "#{guide.key}: pantallas que open_page no conoce #{unknown}"
      end
    end

    it 'cada área del menú tiene al menos una guía' do
      covered = guides.flat_map(&:areas)
      expect(AccessRole::AREAS - covered).to be_empty
    end

    it 'las claves no se repiten' do
      expect(guides.map(&:key).uniq.size).to eq(guides.size)
    end
  end

  describe '.search' do
    it 'encuentra la guía por sus palabras' do
      expect(described_class.search('¿cómo creo un contrato?', admin).first[:key]).to eq('clientes')
      expect(described_class.search('para qué sirve el embudo de contactos', admin).first[:key]).to eq('embudo_contactos')
      expect(described_class.search('cómo concluyo una tarea', admin).first[:key]).to eq('agenda')
    end

    it 'no devuelve nada si no hay coincidencia' do
      expect(described_class.search('xyzzy plugh', admin)).to eq([])
      expect(described_class.search('¿cómo?', admin)).to eq([])
    end

    it 'no muestra guías de áreas que el usuario no tiene' do
      keys = described_class.search('contrato organización cliente', grant_with('agenda')).pluck(:key)
      expect(keys).not_to include('clientes')
    end
  end

  describe '.find' do
    it 'respeta el área' do
      expect(described_class.find('ventas', admin)).to be_present
      expect(described_class.find('ventas', grant_with('agenda'))).to be_nil
      expect(described_class.find('dali', grant_with)).to be_present
    end
  end
end
