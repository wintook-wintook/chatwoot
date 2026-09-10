# frozen_string_literal: true

# @knowledge_sources
require 'rails_helper'

RSpec.describe Wordpress::Selection do
  # Doble del cliente: devuelve lo que WordPress devolvería, ya normalizado.
  let(:client) { instance_double(WordpressClient) }

  def resultado(ids)
    WordpressClient::Result.new(ok: true, data: ids.map { |id| { id: id } })
  end

  def resolver(config)
    described_class.new(client, config).call
  end

  describe 'la categoría es la regla' do
    it 'trae lo que WordPress devuelve para las categorías elegidas' do
      allow(client).to receive(:titles).with('posts', categories: [3]).and_return(resultado([1, 2]))

      expect(resolver('content_types' => ['posts'], 'categories' => [3])).to eq('posts' => [1, 2])
    end

    # Es lo que espera quien no tocó el filtro, y es lo que hace la API cuando no
    # se le manda `categories`.
    it 'sin categorías elegidas entra todo' do
      allow(client).to receive(:titles).with('posts', categories: []).and_return(resultado([1, 2, 3]))

      expect(resolver('content_types' => ['posts'])).to eq('posts' => [1, 2, 3])
    end

    it 'resuelve cada tipo por separado' do
      allow(client).to receive(:titles).with('posts', categories: []).and_return(resultado([1]))
      allow(client).to receive(:titles).with('pages', categories: []).and_return(resultado([9]))

      expect(resolver('content_types' => %w[posts pages])).to eq('posts' => [1], 'pages' => [9])
    end

    it 'omite un tipo que no tiene nada' do
      allow(client).to receive(:titles).with('posts', categories: []).and_return(resultado([1]))
      allow(client).to receive(:titles).with('pages', categories: []).and_return(resultado([]))

      expect(resolver('content_types' => %w[posts pages])).to eq('posts' => [1])
    end
  end

  describe 'la excepción gana sobre la regla' do
    # Si la categoría volviera a traer lo excluido, deseleccionar no serviría de
    # nada: la próxima sincronización lo traería de vuelta y nadie entendería por qué.
    it 'una entrada excluida no entra aunque su categoría esté elegida' do
      allow(client).to receive(:titles).with('posts', categories: [3]).and_return(resultado([1, 2, 3]))

      expect(resolver('content_types' => ['posts'], 'categories' => [3], 'excluded_ids' => [2]))
        .to eq('posts' => [1, 3])
    end

    it 'una entrada suelta entra aunque su categoría no esté elegida' do
      allow(client).to receive(:titles).with('posts', categories: [3]).and_return(resultado([1]))
      allow(client).to receive(:items).with('posts', ids: [99]).and_return(resultado([99]))

      expect(resolver('content_types' => ['posts'], 'categories' => [3], 'included_ids' => [99]))
        .to eq('posts' => [1, 99])
    end

    it 'excluir gana sobre incluir cuando el mismo id está en las dos listas' do
      allow(client).to receive(:titles).with('posts', categories: []).and_return(resultado([1]))
      allow(client).to receive(:items).with('posts', ids: [7]).and_return(resultado([7]))

      expect(resolver('content_types' => ['posts'], 'included_ids' => [7], 'excluded_ids' => [7]))
        .to eq('posts' => [1])
    end

    # included_ids no dice de qué tipo es cada id: se le pregunta a cada tipo y el
    # que lo reconozca se lo queda.
    it 'no le adjudica a un tipo un id suelto que no es suyo' do
      allow(client).to receive(:titles).with('posts', categories: []).and_return(resultado([1]))
      allow(client).to receive(:items).with('posts', ids: [99]).and_return(resultado([]))

      expect(resolver('content_types' => ['posts'], 'included_ids' => [99])).to eq('posts' => [1])
    end
  end

  # Devolver {} tanto para "no hay nada elegido" como para "no pude preguntar"
  # costó caro: el sincronizador leía el vacío de un sitio caído como "el usuario
  # deseleccionó todo" y borraba el índice entero.
  describe 'cuando el sitio no responde' do
    it 'devuelve nil, que es distinto de "no hay nada elegido"' do
      allow(client).to receive(:titles).and_return(WordpressClient::Result.new(ok: false, error: :forbidden))

      expect(resolver('content_types' => ['posts'])).to be_nil
    end

    it 'también con una caída de red' do
      allow(client).to receive(:titles).and_return(WordpressClient::Result.new(ok: false, error: :unreachable))

      expect(resolver('content_types' => ['posts'])).to be_nil
    end

    # Un sitio sin tienda devuelve 404 en products. Eso NO es que el sitio esté
    # caído: es una respuesta legítima, y lo demás se indexa igual.
    it 'un tipo que el sitio no tiene no invalida la selección' do
      allow(client).to receive(:titles).with('posts', categories: []).and_return(resultado([1]))
      allow(client).to receive(:titles).with('products', categories: [])
                                       .and_return(WordpressClient::Result.new(ok: false, error: :not_found))

      expect(resolver('content_types' => %w[posts products])).to eq('posts' => [1])
    end
  end

  describe '#catalog' do
    # La pantalla usa la MISMA resolución que el sincronizador: si usaran lógicas
    # distintas, podrían decir cosas distintas.
    it 'marca cada ítem según entre o no' do
      allow(client).to receive(:titles).with('posts').and_return(resultado([1, 2, 3]))
      allow(client).to receive(:titles).with('posts', categories: []).and_return(resultado([1, 2, 3]))

      catalogo = described_class.new(client, 'content_types' => ['posts'], 'excluded_ids' => [2]).catalog('posts')

      expect(catalogo.map { |i| [i[:id], i[:selected]] }).to eq([[1, true], [2, false], [3, true]])
    end
  end

  # Cada tipo tiene SU taxonomía, y confundirlas no da error: da un filtro que no
  # filtra. Es el fallo que aparecio al mirar la pantalla con el modelo correcto.
  describe 'cada tipo con su taxonomía' do
    it 'a las ENTRADAS les pasa las categorías del blog' do
      allow(client).to receive(:titles).with('posts', categories: [3]).and_return(resultado([1]))

      resolver('content_types' => ['posts'], 'categories' => [3])

      expect(client).to have_received(:titles).with('posts', categories: [3])
    end

    # Una página no tiene categorías: WordPress ignora el parámetro y devuelve
    # todas. Pasárselo hace creer que se acotó algo que no se acotó.
    it 'a las PÁGINAS no les pasa ninguna categoría, aunque haya elegidas' do
      allow(client).to receive(:titles).with('pages', categories: []).and_return(resultado([9]))

      resolver('content_types' => ['pages'], 'categories' => [3])

      expect(client).to have_received(:titles).with('pages', categories: [])
    end

    # Las de la tienda son otra lista con otros ids: las del blog no filtran nada.
    it 'a los PRODUCTOS les pasa las categorías de la tienda, no las del blog' do
      allow(client).to receive(:titles).with('products', categories: [1028]).and_return(resultado([7]))

      resolver('content_types' => ['products'], 'categories' => [3], 'product_categories' => [1028])

      expect(client).to have_received(:titles).with('products', categories: [1028])
    end

    it 'resuelve los tres tipos a la vez, cada uno con lo suyo' do
      allow(client).to receive(:titles).with('posts', categories: [3]).and_return(resultado([1]))
      allow(client).to receive(:titles).with('pages', categories: []).and_return(resultado([9]))
      allow(client).to receive(:titles).with('products', categories: [1028]).and_return(resultado([7]))

      resultado = resolver('content_types' => %w[posts pages products],
                           'categories' => [3], 'product_categories' => [1028])

      expect(resultado).to eq('posts' => [1], 'pages' => [9], 'products' => [7])
    end
  end
end
