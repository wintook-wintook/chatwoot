# frozen_string_literal: true

# @query_databases (F6) — librería de consultas predefinidas por ERP, con esquemas
# VERIFICADOS en vivo. SAE usa el sufijo de empresa (%{suffix} → CLIE01/FACTF01/...).
# Cada consulta: name, description, sql, params (schema), ai (Modo B). La consulta
# `recordatorio_vencidas` es MASIVA (incluye teléfono) para el Modo A del bot.
module ExternalDb::QueryLibrary
  module_function

  RFC = { 'key' => 'rfc', 'label' => 'RFC del cliente', 'type' => 'string', 'required' => true }.freeze
  DESDE = { 'key' => 'desde', 'label' => 'Fecha desde', 'type' => 'date', 'required' => true }.freeze
  HASTA = { 'key' => 'hasta', 'label' => 'Fecha hasta', 'type' => 'date', 'required' => true }.freeze

  # Devuelve las plantillas (con %{suffix} ya interpolado) para una conexión.
  def for_connection(connection)
    suffix = connection.company_suffix.to_s
    Array(templates[connection.erp_type.to_sym]).map do |t|
      t.merge('sql_template' => format(t['sql_template'], suffix: suffix))
    end
  end

  def templates
    { sae: sae, microsip: microsip, contpaq: contpaq }
  end

  # ---------------- Aspel SAE (Firebird) ----------------
  def sae
    [
      entry('saldo_cliente', 'Saldo total que adeuda un cliente por su RFC',
            'SELECT NOMBRE, SALDO FROM CLIE%<suffix>s WHERE RFC = :rfc', [RFC], ai_enabled: true),
      entry('facturas_vencidas', 'Facturas vencidas de un cliente',
            'SELECT SERIE, FOLIO, FECHA_DOC, FECHA_VEN, IMPORTE FROM FACTF%<suffix>s ' \
            "WHERE RFC = :rfc AND ACT_CXC = 'S' AND FECHA_CANCELA IS NULL AND FECHA_VEN < CURRENT_DATE " \
            'ORDER BY FECHA_VEN', [RFC], ai_enabled: true),
      entry('pagos_periodo', 'Total cobrado en un período',
            'SELECT SUM(IMPORTE) AS COBRADO FROM FACTP%<suffix>s ' \
            'WHERE FECHA_CANCELA IS NULL AND FECHA_DOC >= :desde AND FECHA_DOC < :hasta', [DESDE, HASTA], ai_enabled: true),
      entry('sobre_limite', 'Clientes que exceden su límite de crédito',
            'SELECT CLAVE_CLIENTE, NOMBRE, LIMCRED, SALDO FROM CLIE%<suffix>s ' \
            'WHERE LIMCRED > 0 AND SALDO > LIMCRED', [], ai_enabled: true),
      entry('recordatorio_vencidas', 'MASIVA (Modo A): vencidas con teléfono del cliente',
            'SELECT c.NOMBRE, c.TELEFONO, f.SERIE, f.FOLIO, f.IMPORTE, f.FECHA_VEN ' \
            'FROM FACTF%<suffix>s f JOIN CLIE%<suffix>s c ON c.CLAVE = f.CVE_CLPV ' \
            "WHERE f.ACT_CXC = 'S' AND f.FECHA_CANCELA IS NULL AND f.FECHA_VEN < CURRENT_DATE", [])
    ]
  end

  # ---------------- Microsip (Firebird) ----------------
  def microsip # rubocop:disable Metrics/MethodLength
    [
      entry('saldo_cliente', 'Saldo total que adeuda un cliente por su RFC',
            'SELECT SUM(s.CARGOS_CXC - s.CREDITOS_CXC) AS SALDO FROM SALDOS_CC s ' \
            'JOIN DIRS_CLIENTES d ON d.CLIENTE_ID = s.CLIENTE_ID WHERE d.RFC_CURP = :rfc', [RFC], ai_enabled: true),
      entry('pagos_periodo', 'Total cobrado en un período (abonos)',
            'SELECT SUM(i.IMPORTE) AS COBRADO FROM DOCTOS_CC dc ' \
            'JOIN IMPORTES_DOCTOS_CC i ON i.DOCTO_CC_ID = dc.DOCTO_CC_ID ' \
            "WHERE dc.NATURALEZA_CONCEPTO = 'R' AND dc.CANCELADO = 'N' " \
            'AND dc.FECHA >= :desde AND dc.FECHA < :hasta', [DESDE, HASTA], ai_enabled: true),
      entry('sobre_limite', 'Clientes que exceden su límite de crédito',
            'SELECT c.CLIENTE_ID, c.LIMITE_CREDITO, SUM(s.CARGOS_CXC - s.CREDITOS_CXC) AS SALDO ' \
            'FROM CLIENTES c JOIN SALDOS_CC s ON s.CLIENTE_ID = c.CLIENTE_ID WHERE c.LIMITE_CREDITO > 0 ' \
            'GROUP BY c.CLIENTE_ID, c.LIMITE_CREDITO HAVING SUM(s.CARGOS_CXC - s.CREDITOS_CXC) > c.LIMITE_CREDITO',
            [], ai_enabled: true),
      entry('recordatorio_vencidas', 'MASIVA (Modo A): vencidas con teléfono del cliente',
            'SELECT c.NOMBRE, d.TELEFONO1, dc.FOLIO, v.FECHA_VENCIMIENTO FROM DOCTOS_CC dc ' \
            'JOIN VENCIMIENTOS_CARGOS_CC v ON v.DOCTO_CC_ID = dc.DOCTO_CC_ID ' \
            'JOIN CLIENTES c ON c.CLIENTE_ID = dc.CLIENTE_ID ' \
            'JOIN DIRS_CLIENTES d ON d.CLIENTE_ID = c.CLIENTE_ID ' \
            "WHERE dc.CANCELADO = 'N' AND v.FECHA_VENCIMIENTO < CURRENT_DATE", [])
    ]
  end

  # ---------------- CONTPAQi (SQL Server) ----------------
  def contpaq # rubocop:disable Metrics/MethodLength
    [
      entry('saldo_cliente', 'Saldo total que adeuda un cliente por su RFC',
            'SELECT SUM(CPENDIENTE) AS saldo FROM admDocumentos WHERE CRFC = :rfc AND CCANCELADO = 0',
            [RFC], ai_enabled: true),
      entry('facturas_vencidas', 'Facturas vencidas de un cliente',
            'SELECT CSERIEDOCUMENTO + CAST(CFOLIO AS varchar) AS folio, CFECHA, CFECHAVENCIMIENTO, ' \
            'CTOTAL, CPENDIENTE AS saldo, DATEDIFF(day, CFECHAVENCIMIENTO, GETDATE()) AS dias_vencidos ' \
            'FROM admDocumentos WHERE CRFC = :rfc AND CPENDIENTE > 0 AND CCANCELADO = 0 ' \
            'AND CFECHAVENCIMIENTO < GETDATE() ORDER BY CFECHAVENCIMIENTO', [RFC], ai_enabled: true),
      entry('pagos_periodo', 'Total cobrado en un período (abonos aplicados)',
            'SELECT SUM(CIMPORTEABONO) AS cobrado FROM admAsocCargosAbonos ' \
            'WHERE CFECHAABONOCARGO >= :desde AND CFECHAABONOCARGO < :hasta', [DESDE, HASTA], ai_enabled: true),
      entry('sobre_limite', 'Clientes que exceden su límite de crédito',
            'SELECT cl.CRAZONSOCIAL, cl.CLIMITECREDITOCLIENTE, SUM(d.CPENDIENTE) AS saldo ' \
            'FROM admClientes cl JOIN admDocumentos d ON d.CIDCLIENTEPROVEEDOR = cl.CIDCLIENTEPROVEEDOR ' \
            'WHERE cl.CLIMITECREDITOCLIENTE > 0 AND d.CCANCELADO = 0 ' \
            'GROUP BY cl.CRAZONSOCIAL, cl.CLIMITECREDITOCLIENTE ' \
            'HAVING SUM(d.CPENDIENTE) > cl.CLIMITECREDITOCLIENTE', [], ai_enabled: true),
      entry('recordatorio_vencidas', 'MASIVA (Modo A): vencidas con teléfono del cliente',
            'SELECT cl.CRAZONSOCIAL, cl.CCON1TEL, d.CSERIEDOCUMENTO, d.CFOLIO, d.CPENDIENTE, d.CFECHAVENCIMIENTO ' \
            'FROM admDocumentos d JOIN admClientes cl ON cl.CIDCLIENTEPROVEEDOR = d.CIDCLIENTEPROVEEDOR ' \
            'WHERE d.CPENDIENTE > 0 AND d.CCANCELADO = 0 AND d.CFECHAVENCIMIENTO < GETDATE()', [])
    ]
  end

  def entry(name, description, sql, params, ai_enabled: false)
    { 'name' => name, 'description' => description, 'sql_template' => sql,
      'params_schema' => params, 'ai_enabled' => ai_enabled }
  end
end
