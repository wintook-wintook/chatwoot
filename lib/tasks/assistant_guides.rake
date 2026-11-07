# frozen_string_literal: true

# Asistente (Dali) — guías de uso (config/assistant/guides) y preguntas sin respuesta.
#
#   rake assistant:guide_gaps                         # pendientes, de la más repetida a la menos
#   rake assistant:guide_gaps STATUS=resolved LIMIT=100 ACCOUNT=1 REASON=not_covered
#   rake assistant:guide_gaps:resolve IDS=4,7 NOTE='guía agenda: cómo cambiar el responsable'
#   rake assistant:guide_gaps:discard IDS=9 NOTE='es del negocio del cliente'
#   rake assistant:guides:check                       # las guías completas y su búsqueda
#   rake assistant:guides:portal ACCOUNT=1            # crea el Centro de ayuda global (una vez)
#   rake assistant:guides:publish                     # guías → artículos del Centro de ayuda (en cada deploy)
namespace :assistant do
  desc 'Preguntas que Dali no supo contestar (STATUS, REASON, ACCOUNT, LIMIT)'
  task guide_gaps: :environment do
    status = ENV.fetch('STATUS', 'pending')
    scope = AssistantGuideGap.where(status: status).includes(:account).by_relevance.limit(ENV.fetch('LIMIT', 50).to_i)
    scope = scope.where(reason: ENV['REASON']) if ENV['REASON'].present?
    scope = scope.where(account_id: ENV['ACCOUNT']) if ENV['ACCOUNT'].present?
    gaps = scope.to_a
    puts "#{gaps.size} preguntas (#{status}); total por estado: #{AssistantGuideGap.group(:status).count}"
    gaps.each do |gap|
      puts '-' * 80
      puts "##{gap.id} · #{gap.occurrences}× · #{gap.reason} · #{gap.account&.name} (#{gap.account_id}) · " \
           "#{gap.last_asked_at.to_date} · pantalla=#{gap.page || '-'} · guía=#{gap.guide_key || '-'}"
      puts "  P: #{gap.question}"
      puts "  R: #{gap.answer.to_s.squish.truncate(300)}" if gap.answer.present?
      puts "  Nota: #{gap.resolution_note}" if gap.resolution_note.present?
    end
  end
end

# IDS=1,2,3 → [1, 2, 3]
assistant_gap_ids = lambda do
  ids = ENV.fetch('IDS', '').split(',').map(&:to_i).select(&:positive?)
  abort 'Falta IDS=1,2,3' if ids.empty?
  ids
end

namespace :assistant do
  namespace :guide_gaps do
    desc 'Marca preguntas como resueltas (IDS, NOTE)'
    task resolve: :environment do
      ids = assistant_gap_ids.call
      AssistantGuideGap.where(id: ids).find_each { |gap| gap.resolve!(ENV.fetch('NOTE', nil)) }
      puts "Resueltas: #{ids.join(', ')}"
    end

    desc 'Descarta preguntas que no son de la plataforma (IDS, NOTE)'
    task discard: :environment do
      ids = assistant_gap_ids.call
      AssistantGuideGap.where(id: ids).find_each { |gap| gap.discard!(ENV.fetch('NOTE', nil)) }
      puts "Descartadas: #{ids.join(', ')}"
    end
  end
end

namespace :assistant do
  namespace :guides do
    desc 'Revisa las guías de uso (cabecera, áreas, pantallas) y lista sus claves'
    task check: :environment do
      problems = Assistant::Guides.broken_files.map { |file| "cabecera inválida en #{file}" }
      Assistant::Guides.all.each do |guide|
        problems << "#{guide.key}: falta title o keywords" if guide.title.blank? || guide.keywords.empty?
        problems << "#{guide.key}: áreas desconocidas #{guide.areas - AccessRole::AREAS}" if (guide.areas - AccessRole::AREAS).any?
        unknown = guide.pages - Assistant::Pages::MAP.keys
        problems << "#{guide.key}: pantallas desconocidas #{unknown}" if unknown.any?
        puts "#{guide.key.ljust(20)} #{guide.title} [#{guide.areas.join(', ').presence || 'todos'}] #{guide.body.size} car."
      end
      missing = AccessRole::AREAS - Assistant::Guides.all.flat_map(&:areas)
      problems << "áreas sin guía: #{missing}" if missing.any?
      abort(problems.join("\n")) if problems.any?
      puts 'Guías en orden.'
    end
  end
end

namespace :assistant do
  namespace :guides do
    desc 'Crea el Centro de ayuda global de Kontrolya en la cuenta ACCOUNT (slug PLATFORM_HELP_PORTAL_SLUG, «ayuda»)'
    task portal: :environment do
      abort 'Falta ACCOUNT=<id de la cuenta de Kontrolya>' if ENV['ACCOUNT'].blank?
      portal = Assistant::GuidePublisher.create_portal!(account: Account.find(ENV.fetch('ACCOUNT', nil)),
                                                        name: ENV.fetch('NAME', 'Ayuda Kontrolya'))
      puts "Portal «#{portal.name}» (#{portal.slug}) en la cuenta #{portal.account_id}: /hc/#{portal.slug}/es"
    end

    desc 'Publica las guías como artículos del Centro de ayuda global (crea, actualiza y archiva)'
    task publish: :environment do
      unless Assistant::GuidePublisher.portal
        puts "Sin portal «#{Assistant::GuidePublisher.portal_slug}»: nada que publicar (rake assistant:guides:portal ACCOUNT=…)"
        next
      end
      result = Assistant::GuidePublisher.new.call
      puts "Nuevas: #{result.created.size} · actualizadas: #{result.updated.size} · " \
           "sin cambios: #{result.unchanged.size} · archivadas: #{result.archived.size}"
      puts "  nuevas: #{result.created.join(', ')}" if result.created.any?
      puts "  actualizadas: #{result.updated.join(', ')}" if result.updated.any?
      puts "  archivadas: #{result.archived.join(', ')}" if result.archived.any?
    end
  end
end
