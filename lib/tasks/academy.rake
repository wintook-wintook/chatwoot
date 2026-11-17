# frozen_string_literal: true

# Academia Kontrolya — revisa config/academy/modules.yml (guías, checks y pantallas que existan).
#   rake academy:check
namespace :academy do
  desc 'Revisa los módulos de la Academia (config/academy/modules.yml)'
  task check: :environment do
    problems = Academy::Catalog.problems
    if problems.empty?
      Academy::Catalog.modules.each { |m| puts "#{m.key.ljust(14)} #{m.title.ljust(28)} #{m.steps.size} pasos" }
      puts 'Academia en orden.'
    else
      puts problems
      abort "#{problems.size} problema(s) en la Academia."
    end
  end
end
