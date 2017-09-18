#!/home/it/noelp/.rvm/wrappers/ruby-2.2.1@spillman/ruby
#!/usr/bin/env rvm 2.2.1@spillman do ruby
#!/usr/local/rvm/wrappers/ruby-2.1.5@spillman/ruby
# NJP Apr2016
ENV['ODBCINI'] = '/etc/odbc.ini'

require 'rubygems'
require '/var/www/html/spillman/quick_cgi.rb'
require 'odbc'
require 'date'

#HS_DISTS = %{ ('005W','006W','006X', '019X') }  

def check_internal

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
  @start_date= params['start_date'][0]||Date.today.to_date.to_s
  @end_date= params['end_date'][0]||Date.today.to_date.to_s
  @order=params['order'][0]||nil
  title "ABC Report : "+@start_date+ (@end_date ? " to #{@end_date}" : "")
  client = ODBC.connect("spillman")
  sql = %{
SELECT 
LEFT(a.la,3) as dist,
count(distinct i."number") as cnt
FROM lwmain i 
JOIN lwoffs o ON i."number" = o."number"
JOIN gbaddr a ON i.geoaddr = a."number"
WHERE (offcode 
IN ('AS01', 'AS02', 'AS03', 'AS05', 'AS06', 'AS07', 'AS08', 'AS09', 'AS10', 
'AS11', 'BUR1', 'BUR2', 'BUR3', 'BUR4', 'BUR5', 'BUR6', 'BUR7', 'HOMI', 
'HOMJ', 'HOMN', 'RA01', 'RA02', 'RFBK', 'RFBU', 'RFCS', 'RFGS', 'RFMC',
'RFRE', 'RFST', 'RKBK', 'RKBU', 'RKCS', 'RKGS', 'RKMC', 'RKRE', 'RKST',
'ROBK', 'ROBU', 'ROCS', 'ROGS', 'ROMC', 'RORE', 'ROST', 'RSBK', 'RSBU',
'RSCS', 'RSGS', 'RSMC', 'RSRE', 'RSST', 'STO1', 'STO2', 'STO3', 'STO4',
'TPBC', 'TPBD', 'TPCM', 'TPMV', 'TPOT', 'TPPB', 'TPPK', 'TPPS', 'TPSH',
'TPVP')
OR i.dispos IN ('CJI','CJP','CAI','CAP')
)
AND i.dtrepor BETWEEN ?  AND ? 
GROUP BY LEFT(a.la,3)
    }
  
  if @order
    sql += %{ ORDER BY #{@order} }
  else
    sql += %{ ORDER BY dist }
  end

  @sql = sql 
  @smt = client.run(sql,@start_date,@end_date)
  render(:haml=>'haml/abc_report.haml')
end


puts content

