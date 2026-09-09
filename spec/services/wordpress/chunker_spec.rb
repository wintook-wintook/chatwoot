# frozen_string_literal: true

# @knowledge_sources
require 'rails_helper'

RSpec.describe Wordpress::Chunker do
  def trocear(texto) = described_class.call(texto)

  # Cada párrafo termina en un marcador, para poder afirmar que el corte cayó en el
  # borde de un párrafo y no a mitad de uno.
  def parrafos(cantidad, largo)
    Array.new(cantidad) { |i| "p#{i} #{'a' * (largo - 8)} FIN#{i}" }.join("\n")
  end

  describe 'textos que no hace falta trocear' do
    it 'devuelve un solo chunk cuando entra entero' do
      texto = 'Para actualizar a la última versión, entrá al panel y hacé clic en Actualizar.'

      expect(trocear(texto)).to eq([texto])
    end

    # Un pie de página o una firma suelta no responden ninguna pregunta y solo
    # ensucian los resultados de similitud.
    it 'descarta un texto más corto que el mínimo' do
      expect(trocear('Gracias.')).to eq([])
    end

    it 'descarta un texto vacío' do
      expect(trocear('')).to eq([])
      expect(trocear(nil)).to eq([])
    end
  end

  describe 'textos largos' do
    it 'trocea en varias partes' do
      chunks = trocear(parrafos(5, 1000))

      expect(chunks.size).to be > 1
      expect(chunks.map(&:length).max).to be <= described_class::CHUNK_SIZE
    end

    # Cortar en el carácter 4.000 parte una frase al medio y deja dos embeddings
    # de algo que nadie escribió.
    it 'corta en un salto de párrafo, no a mitad de frase' do
      chunks = trocear(parrafos(10, 500))

      expect(chunks.first).to match(/FIN\d\z/)
      expect(chunks.first.length).to be < described_class::CHUNK_SIZE
    end

    # Si un párrafo solo ya excede el tamaño no hay alternativa: se corta duro.
    it 'corta duro cuando un solo párrafo no entra' do
      chunks = trocear('x' * 9000)

      expect(chunks.size).to be >= 2
      expect(chunks.map(&:length).max).to be <= described_class::CHUNK_SIZE
    end

    # El solape hace que una idea que cae justo en el corte siga siendo encontrable
    # desde los dos lados.
    it 'solapa el final de un chunk con el principio del siguiente' do
      chunks = trocear('x' * 9000)
      cola = chunks.first.last(100)

      expect(chunks[1]).to start_with(cola)
    end

    it 'no pierde contenido: la unión cubre todo el texto' do
      texto = parrafos(20, 600)

      expect(trocear(texto).join.delete("\n").length).to be >= texto.delete("\n").length
    end

    it 'termina siempre, aunque el texto sea muy largo' do
      expect { Timeout.timeout(5) { trocear('x' * 200_000) } }.not_to raise_error
    end
  end

  # Los mismos que GoogleDocSyncJob: un corpus con chunks de tamaños distintos
  # según la fuente da similitudes que no se pueden comparar, y el motor los
  # mezcla en la misma búsqueda.
  describe 'los números' do
    it 'usa el mismo tamaño y solape que las demás fuentes' do
      expect(described_class::CHUNK_SIZE).to eq(4000)
      expect(described_class::CHUNK_OVERLAP).to eq(400)
    end
  end
end
