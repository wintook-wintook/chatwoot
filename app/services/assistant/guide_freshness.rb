# frozen_string_literal: true

# Asistente (Dali) — ¿qué guías quedaron viejas? Cada guía dice en `sources` el código que
# explica (globs). Si alguno de esos archivos tiene un commit más nuevo que el último commit
# de la guía (o cambios sin commit), la guía puede estar desactualizada.
#
#   rake assistant:guides:stale              # antes de cada PR
#
# Qué hacer con una guía marcada: actualizar el texto o, si sigue bien, cambiar su
# `reviewed:` a la fecha de hoy. En los dos casos el commit de la guía la pone al día.
# Usa git: es para desarrollo, no corre en el servidor.
class Assistant::GuideFreshness
  Report = Struct.new(:guide, :files, :guide_at, :commits, :dirty, keyword_init: true) do
    def stale? = commits.any? || dirty.any?
  end

  def initialize(root: Rails.root)
    @root = root.to_s
  end

  # Las guías sin `sources` no se pueden revisar: van aparte.
  def call
    guides = Assistant::Guides.all
    reports = guides.select { |g| g.sources.any? }.map { |guide| report_for(guide) }
    { stale: reports.select(&:stale?), fresh: reports.reject(&:stale?), without_sources: guides.select { |g| g.sources.empty? } }
  end

  # Los archivos (en git) que cubren los globs de la guía, sin respaldos (archivo_YYYYMMDD).
  def files_for(guide)
    guide.sources.flat_map { |glob| Dir.glob(glob, base: @root) }.uniq.select { |f| tracked.include?(f) }.sort
  end

  private

  def report_for(guide)
    files = files_for(guide)
    guide_file = "config/assistant/guides/#{guide.key}.md"
    guide_at = git('log', '-1', '--format=%cI', '--', guide_file).strip.presence
    commits = guide_at && files.any? ? commits_since(guide_at, files) : []
    Report.new(guide: guide, files: files, guide_at: guide_at, commits: commits, dirty: files & modified)
  end

  # Los commits del código después del de la guía (el mismo commit que tocó los dos no cuenta).
  def commits_since(time, files)
    since = Time.iso8601(time)
    git('log', '--no-merges', "--since=#{time}", '--format=%cI %h %cs %s', '--', *files).lines.filter_map do |line|
      at, rest = line.strip.split(' ', 2)
      rest if at && Time.iso8601(at) > since
    end
  end

  def tracked = @tracked ||= git('ls-files').lines.to_set(&:strip)

  def modified = @modified ||= git('diff', '--name-only', 'HEAD').lines.map(&:strip)

  def git(*args)
    out, status = Open3.capture2('git', '-C', @root, *args)
    status.success? ? out : ''
  end
end
