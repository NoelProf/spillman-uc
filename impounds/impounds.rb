# NJP Apr2016
ENV['ODBCINI'] = '/etc/odbc.ini'

class Impound < Sinatra::Base
  require 'rubygems'
  require 'date'
  require 'odbc'
  require 'uri'

  set :haml, :format => :html5

  client = ODBC.connect("spillman")

  helpers do 
    def go(row,name)
      obj = row[name]
      if obj.class == ODBC::TimeStamp
        "#{name}=#{obj.month.to_s.rjust(2,'0')}/#{obj.day.to_s.rjust(2,'0')}/#{obj.year} #{obj.hour.to_s.rjust(2,'0')}:#{obj.minute.to_s.rjust(2,'0')}&"
      elsif obj.class == Fixnum
        "#{name}=#{obj}&"
      else
        obj ? "#{name}=#{URI.escape(obj.strip)}&" : ""
      end
    end

    def letter_link(r)
      str = "/pdfer/impound?"
      str += "init=#{@env['REMOTE_USER']}&"
      str << (go r, 'incid')
      str << (go r, 'first')
      str << (go r, 'last')
      str << (go r, 'street')
      str << (go r, 'city')
      str << (go r, 'state')
      str << (go r, 'zip')
      str << (go r, 'impdate')
      str << (go r, 'towdate')
      str << (go r, 'lpnum')
      str << (go r, 'lpst')
      str << (go r, 'year')
      str << (go r, 'make')
      str << (go r, 'model')
      str << (go r, 'vin')
      str << (go r, 'desc')
      str << (go r, 'tow_phone')
      str << (go r, 'tow_address')
      str << (go r, 'tow_csz')
      str << (go r, 'liennam')
      str << (go r, 'lienadd')
      str << (go r, 'liencsz')
      str << (go r, 'reason')
      str << (go r, 't_reason')
    end

    def self_link
      plist = "?" 
      params.each do |p| 
        next if p[0]=='order'
        plist << "#{p[0]}=#{p[1]}&"
      end 
      "impounds"+plist
    end

    def format_cell(h)
      val = h[1]
      if val.class == ODBC::TimeStamp
        "#{val.month.to_s.rjust(2,'0')}/#{val.day.to_s.rjust(2,'0')}/#{val.year} #{val.hour.to_s.rjust(2,'0')}#{val.minute.to_s.rjust(2,'0')}"
      else
        val 
      end 
    end 
  end

  get '/' do
    @title = "PD Impounds"
    @impound_after =  params[:impound_after]||(Time.now.to_date - 60)
    @order =  params[:order]||'i."number" DESC'
    @type =  params[:type]||'any'
    
    def type_cluase
      if @type == 'GGPD'
        " AND TRIM(imptype) NOT IN ('REPO','PPI') "
      elsif @type == 'PPI and REPO'
        " AND TRIM(imptype) IN ('REPO','PPI') "
      elsif @type != 'any'
        " AND imptype = '#{@type}' "
      else
        nil
      end
    end

    if @impound_after.class == String
      if @impound_after.match(/\//)
        @impound_after = Date.strptime(@impound_after,'%m/%d/%Y') rescue Time.now.to_date
      else
        @impound_after = Date.parse(@impound_after) rescue Time.now.to_date
      end
    end

    @sql = %{SELECT 
        i."number",
        lpnum,
        lpst,
        year,
        make,
        model,
        towdate,
        impdate,
        towedby,
        "from" as "towed_from",
        i.imptype,
        i.incid,
        v.vin,
        n.first,
        n.last,
        n.street,
        n.city,
        n.state,
        n.zip,
        w."desc",
        w.street as tow_address,
        w.person1 as tow_phone,
        w.csz as tow_csz,
        i.liennam,
        i.lienadd,
        i.liencsz,
        i.reason,
        d."desc" as t_reason
      FROM vimain i
      JOIN vhmain v ON i.vehicle = v."number"
      JOIN tbwreck w ON w.abbr = i.towedby
      LEFT OUTER JOIN nmmain n ON v.ownerid = n."number"
      LEFT OUTER JOIN vitbityp d ON i.imptype = d."type"
      WHERE (towdate > ? OR impdate > ?)
      #{type_cluase}
      ORDER BY #{@order}
      }

    odbc_date = ODBC::Date.new(@impound_after.to_s)
    odbc_date2 = ODBC::Date.new(@impound_after.to_s)
    @smt = client.run(@sql, odbc_date,odbc_date2)
    @parms = @smt.parameters
    @cols = @smt.columns

    haml :index
  end



  private

end
