# frozen_string_literal: true

# Academia Kontrolya — los módulos de config/academy/modules.yml.
#   Academy::Catalog.modules          → todos, en orden
#   Academy::Catalog.for(grant)       → los que ve ese rol (por sus áreas)
#   Academy::Catalog.problems         → lo que está mal en el archivo (rake academy:check)
module Academy::Catalog
  FILE = Rails.root.join('config/academy/modules.yml')
  KINDS = %w[lesson exercise].freeze
  PRACTICE_PAGES = %w[practice_contact practice_case].freeze

  Step = Struct.new(:key, :kind, :title, :text, :guide, :page, :check, :needs, :hint, keyword_init: true) do
    def lesson? = kind == 'lesson'
    def exercise? = kind == 'exercise'
  end

  Mod = Struct.new(:key, :title, :summary, :areas, :steps, keyword_init: true) do
    def visible_to?(grant) = areas.empty? || areas.any? { |area| grant.allowed?(area) }
    def step(key) = steps.find { |s| s.key == key.to_s }
  end

  module_function

  def modules
    return load_modules if Rails.env.development?

    @modules ||= load_modules
  end

  def for(grant) = modules.select { |m| m.visible_to?(grant) }

  def find(key) = modules.find { |m| m.key == key.to_s }

  def load_modules
    YAML.safe_load(File.read(FILE)).fetch('modules').map do |raw|
      steps = raw.fetch('steps').map { |s| Step.new(**s.slice(*Step.members.map(&:to_s)).symbolize_keys) }
      Mod.new(key: raw['key'], title: raw['title'], summary: raw['summary'], areas: Array(raw['areas']), steps: steps)
    end
  end

  # Cada problema como texto; vacío = el archivo está bien.
  def problems
    keys = modules.map(&:key)
    list = keys.tally.select { |_k, n| n > 1 }.keys.map { |k| "módulo repetido: #{k}" }
    modules.each { |mod| list.concat(module_problems(mod)) }
    list
  end

  def module_problems(mod)
    list = (mod.areas - AccessRole::AREAS).map { |a| "#{mod.key}: área desconocida #{a}" }
    list << "#{mod.key}: pasos repetidos" if mod.steps.map(&:key).uniq.size != mod.steps.size
    mod.steps.each { |step| list.concat(step_problems(mod, step)) }
    list
  end

  def step_problems(mod, step)
    where = "#{mod.key}/#{step.key}"
    return ["#{where}: kind debe ser lesson o exercise"] unless KINDS.include?(step.kind)
    return lesson_problems(where, step) if step.lesson?

    {
      "check #{step.check} no existe en Academy::Checks" => Academy::Checks::CHECKS.exclude?(step.check),
      "page #{step.page} no existe" => step.page && !valid_page?(step.page),
      "needs #{step.needs} no existe" => step.needs && PRACTICE_PAGES.exclude?(step.needs)
    }.select { |_text, bad| bad }.keys.map { |text| "#{where}: #{text}" }
  end

  def lesson_problems(where, step)
    Assistant::Guides.all.any? { |g| g.key == step.guide } ? [] : ["#{where}: guía #{step.guide} no existe"]
  end

  def valid_page?(page) = PRACTICE_PAGES.include?(page) || Assistant::Pages::SCREENS.key?(page)
end
