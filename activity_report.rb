#!/home/it/noelp/.rvm/wrappers/ruby-2.2.1@spillman/ruby
#!/usr/bin/env rvm 2.2.1@spillman do ruby
#!/usr/local/rvm/wrappers/ruby-2.1.5@spillman/ruby
# NJP Apr2016
ENV['ODBCINI'] = '/etc/odbc.ini'

require 'rubygems'
require '/var/www/html/spillman/quick_cgi.rb'
require 'odbc'
require 'date'

# Pacifica : 033Z
# Rancho: 061X, 061Z
# Bolsa: 086X, 086Z
# Lake: 111Z
# Grove: 124W,124X
# Santiago: 146W, 146X
HS_DISTS = %{ ('033Z','061X','061Z','086X','086Z','111Z','124W','124X','146W','146X') }

def format_cell(val)
  if val.class == ODBC::TimeStamp
    "#{val.month}/#{val.day} #{val.hour.to_s.rjust(2,'0')}#{val.minute.to_s.rjust(2,'0')}"
  else
    val
  end
end

def self_link
  plist = "?"
  params.each do |p|
    next if p[0]=='order'
    plist << "#{p[0]}=#{p[1][0]}&"
  end
  "activity_report.rb"+plist
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

#content = QuickCGI::Generator.generate(:admin_email => 'noelp@ci.garden-grove.ca.us', :layout => 'haml/layout.html.haml') do
content = QuickCGI::Generator.generate(:layout => 'haml/layout.html.haml') do
  check_internal
  #@start_date= params['start_date'][0]||(Date.today.to_date - 30).to_s
  @start_date= params['start_date'][0]||Date.today.to_date.to_s
  @end_date= params['end_date'][0]||Date.today.to_date.to_s
  @beat= params['beat'][0]||'any'
  @ccodes= params['ccodes'][0]||'reports'
  @order=params['order'][0]||nil
  title "Activity Report : "+@start_date+ (@end_date ? " to #{@end_date}" : "")
  client = ODBC.connect("spillman")
  sql = %{
  SELECT
  l."number" as dr,
  t.narratv as nar,
  s.statute,
  z."desc" as beat,
  locatn,
  address,
  dtrepor,
  ocurdt1,
  --ocurdt2,
  l.ccode,
  n."desc" as nature
  FROM lwmain l
  LEFT OUTER JOIN lwoffs s ON l."number" = s."number"
  LEFT OUTER JOIN lwnarr t ON l."number" = t."number"
  JOIN tbzones z ON l.locatn = z.abbr
  JOIN tbnatur n ON l.nature = n.abbr
    }

  if 'reports' == @ccodes 
    sql += %{ WHERE ccode IN ('6X','7X','8X') }
  else
    sql += %{ WHERE 1 = 1 }
  end

  if @end_date.nil? || @end_date.empty?
    sql += %{ AND CAST(l.dtrepor as date) = '#{@start_date}' }
  else
    sql += %{ AND CAST(l.dtrepor as date) BETWEEN '#{@start_date}' AND '#{@end_date}' }
  end

  if 'Resort' == @beat
    sql += %{ AND (l.locatn like '142%' OR l.locatn like '143%') }
  elsif 'High Schools' == @beat
    sql += %{ AND l.locatn in #{HS_DISTS} }
  elsif 'any' != @beat 
    sql += %{ AND z."desc" = '#{@beat}' }
  end
  
  if @order
    sql += %{ ORDER BY #{@order} }
  else
    sql += %{ ORDER BY statute, dr desc }
  end

  @sql = sql 
  @smt = client.prepare(sql)
  @smt.execute
  render(:haml=>'haml/activity_report.haml')
end


puts content

