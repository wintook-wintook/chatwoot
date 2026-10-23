# ================================================================================
# feat/licencias (F4) — LOS NÚMEROS DEL TABLERO DE LICENCIAS
# ================================================================================
#   kpis.paid / demo        licencias activas de pago / en demo
#   kpis.expiring[7|14|30|60]  activas que vencen dentro de N días
#   kpis.expired            cuentas que tuvieron licencia y ninguna está activa
#   kpis.without_license    cuentas sin ninguna licencia (fuera de licencia)
#   kpis.suspended          cuentas suspendidas
#   kpis.conversion         de las cuentas que tuvieron demo, cuántas tuvieron después una de pago
#   expirations             activas que vencen por semana, próximas 60 días (9 semanas)
#   by_plan                 activas por nombre de licencia (la copia del plan), de más a menos
# Cada número sale de una consulta agregada; nada se calcula cuenta por cuenta.
# Plan: docs/licencias_plan_v1.md §9 (F4)
# ================================================================================
class Licenses::Summary
  WINDOWS = [7, 14, 30, 60].freeze
  WEEKS = 9

  def initialize(now: Time.current)
    @now = now
  end

  def call
    { kpis: kpis, expirations: expirations, by_plan: by_plan }
  end

  private

  def activas
    AccountLicense.active
  end

  def kpis
    con_licencia = AccountLicense.select(:account_id)
    {
      paid: activas.paid.count, demo: activas.demo.count,
      expiring: WINDOWS.index_with { |dias| activas.where(expires_at: @now..(@now + dias.days)).count },
      expired: Account.where(id: con_licencia).where.not(id: activas.select(:account_id)).count,
      without_license: Account.where.not(id: con_licencia).count,
      suspended: Account.suspended.count,
      conversion: conversion
    }
  end

  # Cuentas con alguna demo, y cuántas de ellas tienen una de pago emitida después de su primera demo.
  def conversion
    primeras = AccountLicense.demo.group(:account_id).minimum(:created_at)
    convertidas = AccountLicense.paid.where(account_id: primeras.keys).group(:account_id).maximum(:created_at)
                                .count { |cuenta, ultima| ultima > primeras[cuenta] }
    total = primeras.size
    { demo_accounts: total, converted: convertidas, rate: total.zero? ? 0 : ((convertidas * 100.0) / total).round }
  end

  def expirations
    inicio = @now.beginning_of_week
    por_semana = activas.where(expires_at: @now..(@now + 60.days)).pluck(:expires_at)
                        .group_by { |fecha| ((fecha - inicio) / 1.week).floor }
    Array.new(WEEKS) { |i| { week_start: (inicio + i.weeks).to_date.iso8601, count: por_semana.fetch(i, []).size } }
  end

  def by_plan
    activas.group(:name).count.sort_by { |nombre, total| [-total, nombre] }.map { |nombre, total| { name: nombre, count: total } }
  end
end
