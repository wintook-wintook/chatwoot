# frozen_string_literal: true

require 'rails_helper'
require 'open3'

# Dali — guías viejas: su código (sources) cambió después del último commit de la guía.
RSpec.describe Assistant::GuideFreshness do
  let(:root) { Pathname.new(Dir.mktmpdir) }
  let(:guide) do
    Assistant::Guides::Guide.new(key: 'contratos', title: 'Contratos', areas: [], keywords: ['x'], pages: [], body: 'x',
                                 sources: ['app/contracts/*.vue'], reviewed: nil)
  end

  after { FileUtils.remove_entry(root) }

  def git(*args, date: '2026-11-01T10:00:00+00:00')
    env = { 'GIT_AUTHOR_DATE' => date, 'GIT_COMMITTER_DATE' => date }
    _out, status = Open3.capture2(env, 'git', '-C', root.to_s, *args)
    raise "git #{args.join(' ')}" unless status.success?
  end

  def commit(path, text, date:, message: path)
    file = root.join(path)
    FileUtils.mkdir_p(file.dirname)
    File.write(file, text)
    git('add', path, date: date)
    git('-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-qm', message, date: date)
  end

  before do
    git('init', '-q')
    commit('app/contracts/List.vue', 'v1', date: '2026-11-01T10:00:00+00:00')
    commit('app/contracts/List.vue_20261101', 'respaldo', date: '2026-11-01T10:00:00+00:00')
    commit('config/assistant/guides/contratos.md', 'guía', date: '2026-11-02T10:00:00+00:00')
    allow(Assistant::Guides).to receive(:all).and_return([guide])
  end

  it 'al día si el código no cambió después de la guía (ignora respaldos)' do
    result = described_class.new(root: root).call
    expect(result[:fresh].map { |r| r.guide.key }).to eq(['contratos'])
    expect(result[:fresh].first.files).to eq(['app/contracts/List.vue'])
  end

  it 'vieja si el código tiene un commit más nuevo, con la lista de commits' do
    commit('app/contracts/List.vue', 'v2', date: '2026-11-03T10:00:00+00:00', message: 'feat: nuevo campo')
    report = described_class.new(root: root).call[:stale].first
    expect(report.guide.key).to eq('contratos')
    expect(report.commits.first).to include('feat: nuevo campo')
  end

  it 'vieja si el código tiene cambios sin commit' do
    File.write(root.join('app/contracts/List.vue'), 'v3')
    expect(described_class.new(root: root).call[:stale].first.dirty).to eq(['app/contracts/List.vue'])
  end

  it 'las guías sin sources van aparte' do
    guide.sources = []
    expect(described_class.new(root: root).call[:without_sources]).to eq([guide])
  end
end
