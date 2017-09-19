#!/home/it/noelp/.rvm/wrappers/ruby-2.2.1@spillman/ruby
#!/usr/local/rvm/wrappers/ruby-2.1.5@spillman/ruby
#!/usr/bin/env rvm 2.2.1@spillman do ruby
ENV['ODBCINI'] = '/etc/odbc.ini'

require 'rubygems'
require '/var/www/html/spillman/quick_cgi.rb'
require 'odbc'
require 'date'

def format_cell(val)
  if val.class == ODBC::TimeStamp
    "#{val.month}/#{val.day}/#{val.year} #{val.hour.to_s.rjust(2,'0')}#{val.minute.to_s.rjust(2,'0')}"
  else
    val
  end
end

def check_internal
  @addr = ENV['HTTP_X_FORWARDED_FOR']||ENV['HTTP_CLIENT_IP']||ENV['REMOTE_ADDR']
  if @addr.match(/^204\.27\.239./)
    @internal = true
  elsif @addr.match(/^10\.204./)
    @internal = true
  elsif @addr.match(/^198\.245\.206\.7$/)
    @internal = true
  else
    @internal = false
  end
end

content = QuickCGI::Generator.generate(:layout => 'haml/layout.html.haml') do
  check_internal
  #@start_date= params['start_date'][0]||(Date.today.to_date - 30).to_s
  @start_date= params['start_date'][0]||Date.today.to_date.to_s
  @end_date= params['end_date'][0]||Date.today.to_date.to_s
  @ccodes= params['ccodes'][0]||'reports'
  @circ=params['circ'][0]||nil
  if @circ
    @circ = @circ[0,6]
    if @circ == 'any'
      @circ = nil
    end
  end
  @order=params['order'][0]||nil
  title "Circumstance Report : "+@start_date+ (@end_date ? " to #{@end_date}" : "")
  client = ODBC.connect("spillman")
  sql = %{
  SELECT
  DISTINCT
  l."number" as dr,
  z."desc" as beat,
  locatn,
  address,
  dtrepor,
  ocurdt1,
  l.ccode
  FROM lwmain l
  LEFT OUTER JOIN lwccirc c ON c."number" = l."number"
  JOIN tbzones z ON l.locatn = z.abbr
    }

  # fetch multi-values into hash by dr
  # statutes ranked by tboff action code
  sql_statute = %{
  SELECT
  DISTINCT
  l."number" as dr,
  s.statute,
  t.action
  FROM lwmain l
  LEFT OUTER JOIN lwoffs s ON l."number" = s."number"
  JOIN tblaw b ON b.abbr = s.statute
  JOIN tboff t ON t.abbr = b.offense
  LEFT OUTER JOIN lwccirc c ON c."number" = l."number"
  }

  sql_circ = %{
  SELECT
  DISTINCT
  l."number" as dr,
  c.ccode as circ
  FROM lwmain l
  LEFT OUTER JOIN lwccirc c ON c."number" = l."number"
  }

  clause = String.new
  if 'reports' == @ccodes 
    clause += %{ WHERE l.ccode IN ('6X','7X','8X') }
  else
    clause += %{ WHERE 1 = 1 }
  end

  if @end_date.nil? || @end_date.empty?
    clause += %{ AND CAST(l.dtrepor as date) = '#{@start_date}' }
  else
    clause += %{ AND CAST(l.dtrepor as date) BETWEEN '#{@start_date}' AND '#{@end_date}' }
  end

  if @circ
    clause += %{ AND c.ccode like '#{@circ}%' }
  end

  sql += clause
  sql_statute += clause
  sql_statute += %{ ORDER BY t.action DESC }
  sql_circ += clause

  if @order
    sql += %{ ORDER BY #{@order} }
  else
    sql += %{ ORDER BY dr desc }
  end

  # statutes
  @statutes = Hash.new
  statutes = client.prepare(sql_statute)
  statutes.execute
  while row = statutes.fetch do
    if @statutes[row[0]]
      @statutes[row[0]] << row[1]
    else
      @statutes[row[0]] = [row[1]]
    end
  end

  # circs
  @circs = Hash.new
  circs = client.prepare(sql_circ)
  circs.execute
  while row = circs.fetch do
    if @circs[row[0]]
      @circs[row[0]] << row[1]
    else
      @circs[row[0]] = [row[1]]
    end
  end

  @sql = sql 
  @smt = client.prepare(sql)
  @smt.execute
  render(:haml=>'haml/circ_report.haml')
end


puts content

