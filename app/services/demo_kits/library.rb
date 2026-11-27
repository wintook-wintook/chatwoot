# frozen_string_literal: true

# Ajustes › Demostraciones — las demos que trae Kontrolya (config/demo_kits/*.json, armadas con DemoKits::Exporter) y
# el resumen de un kit (lo que va a crear y los lugares de personas y bandejas que hay que elegir al importar).
module DemoKits::Library
  DIR = Rails.root.join('config/demo_kits')

  module_function

  def all = Dir[DIR.join('*.json')].map { |path| entry(File.basename(path, '.json')) }

  def entry(key) = { key: key, name: load(key)['name'], description: load(key)['description'], summary: summary(load(key)) }

  def load(key)
    path = DIR.join("#{key.to_s.gsub(/[^a-z0-9_-]/i, '')}.json")
    raise ActiveRecord::RecordNotFound, 'Demo no encontrada' unless File.exist?(path)

    JSON.parse(File.read(path))
  end

  def summary(data)
    catalog = data['catalog'].to_h
    { agents: Array(data['agents']).map { |a| { name: a['name'], kind: a['kind'] } },
      categories: Array(catalog['categories']).size, items: Array(catalog['items']).size,
      people: Array(data['people']), inboxes: Array(data['inboxes']).map { |i| i.slice('ref', 'name', 'channel') } }
  end
end
