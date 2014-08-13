# encoding: utf-8
require 'yaml'
require 'date'
libpath = File.dirname __FILE__

require File.join libpath, 'HashTransform.rb'
require File.join libpath, 'Euro.rb'

require File.join libpath, 'projectFileReader.rb'
require File.join libpath, 'rfc5322_regex.rb'
require File.join libpath, 'texwriter.rb'
require File.join libpath, 'shell.rb'

## TODO requirements and validity
## TODO open, YAML::parse, [transform, ] read_all, generate, validate
## TODO statemachine!!
# http://www.zenspider.com/Languages/Ruby/QuickRef.html
class InvoiceProject
  attr_reader :PROJECT_PATH, :PROJECT_FOLDER,
    :raw_data,
    :STATUS,    :ERRORS,
    :SETTINGS,  :DEFAULTS

  attr_writer :raw_data, :DEFAULTS

  include TexWriter
  include Filters
  include Shell
  include ProjectFileReader

  @@known_keys= [
    :format,    :lang,      :created,
    :client,    :event,     :manager,
    :offer,     :invoice,
    :messages,  :products,  :hours
  ]

  @@dynamic_keys=[
    :client_addressing,
    :hours_time,
    :hours_total,
    :event_date,
    :event_prettydate,
    :caterers,
    :offer_number,
    :offer_costs,    :offer_taxes,   :offer_total,   :offer_final,
    :invoice_costs,  :invoice_taxes, :invoice_total, :invoice_final,
    :invoice_longnumber,
  ]

  def initialize(project_path = nil, settings = $SETTINGS, name = nil)
    @SETTINGS = settings
    @STATUS   = :ok # :ok, :canceled, :unparsable
    @ERRORS   = []
    @data     = {}
    @DEFAULTS = {}
    @DEFAULTS = @SETTINGS['defaults'] if @SETTINGS['defaults']

    @DEFAULTS['format'] = '1.0.0'

    open(project_path, name) unless project_path.nil?
  end

  ## open given .yml and parse into @raw_data
  def open(project_path, name = nil)
    #puts "opening \"#{project_path}\""
    raise "already opened another project" unless @PROJECT_PATH.nil?
    @PROJECT_PATH   = project_path
    @PROJECT_FOLDER = File.split(project_path)[0]

    error "FILE \"#{project_path}\" does not exist!" unless File.exists?(project_path)

    ## setting the name
    if name.nil?
      @data[:name]  = File.basename File.split(@PROJECT_PATH)[0]
    else
      error "FILE \"#{project_path}\" does not exist!"
    end

    ## opening the project file
    begin
      @raw_data        = YAML::load(File.open(project_path))
    rescue SyntaxError => error
      warn "error parsing #{project_path}"
      puts error
      @STATUS = :unparsable
      return false
    else
      @data[:valid] = true # at least for the moment
      @STATUS = :valid
      @data[:project_path]  = project_path
    end

    #load format and transform or not
    @data[:format] = @raw_data['format'] ? @raw_data['format'] : "1.0.0"
    if @data[:format] < "2.4.0"
      @raw_data = import_100 @raw_data
    end

    prepare_data()
    return true
  end

  def path
    @PROJECT_PATH
  end

  ## currently only from 1.0.0 to 2.4.0 Format
  def import_100 hash
    rules = [
      { old:"client",       new:"client/fullname"   },
      { old:"address",      new:"client/address"    },
      { old:"email",        new:"client/email"      },
      { old:"event",        new:"event/name"        },
      { old:"location",     new:"event/location"    },
      { old:"description",  new:"event/description" }, #trim
      { old:"manumber",     new:"offer/number"      },
      { old:"anumber",      new:"offer/appendix"    },
      { old:"rnumber",      new:"invoice/number"    },
      { old:"payed_date",   new:"invoice/payed_date"},
      { old:"invoice_date", new:"invoice/date"      },
      { old:"signature",    new:"manager"           }, #trim
      #{ old:"hours/time",  new:"hours/total"       },
    ]
    ht = HashTransform.new :rules => rules, :original_hash => hash
    new_hash = ht.transform()
    new_hash[ 'created' ] = "01.01.0000"

    date = strpdates(hash['date'])
    new_hash.set("event/dates/0/begin", date[0])
    new_hash.set("event/dates/0/end",   date[1]) unless date[1].nil?
    new_hash.set("event/dates/0/time/begin", new_hash.get("time"))     if date[1].nil?
    new_hash.set("event/dates/0/time/end",   new_hash.get("time_end")) if date[1].nil?

    new_hash['manager']= new_hash['manager'].lines.to_a[1] if new_hash['manager'].lines.to_a.length > 1

    if new_hash.get("client/fullname").words.class == Array
      new_hash.set("client/title",     new_hash.get("client/fullname").lines.to_a[0].strip)
      new_hash.set("client/last_name", new_hash.get("client/fullname").lines.to_a[1].strip)
      new_hash.set("client/fullname",  new_hash.get("client/fullname").gsub("\n",' ').strip)
    else
      fail_at :client_fullname
    end
    new_hash.set("offer/date", Date.today)
    new_hash.set("invoice/date", Date.today)

    return hash
  end


  def prepare_data
    @@known_keys.each {|key| read key }
    @@dynamic_keys.each {|key|
      value = apply_generator key, @data
      @data.set key, value, ?_, true # symbols = true
    }
  end

  def validate choice = :invoice
    (invalidators = { # self explaiatory ain't it? :D
      #:invoice   => [:invoice_number, :products, :manager, :caterers],
      :invoice   => [:invoice_number, :products, :manager,],
      :archive   => [:invoice_number, :products, :manager, :invoice_payed_date, :archive],
      :offer     => [:offer_number]
    }[choice] & @ERRORS).length==0
  end

  def to_s
    name
  end

  def to_yaml
    @raw_data.to_yaml
  end


  def name
    @data[:canceled] ? "CANCELED: #{@data[:name]}" : @data[:name]
    @data[:name]
  end

  def date
    @data[:event][:date] if @data[:event]
  end

  #getters for path_through_document
  #getting path['through']['document']
  def data key = nil
    return @data if key.nil?
    return @data.get key
  end

  def export_filename choice, ext=""
    offer_number   = data 'offer/number'
    invoice_number = data 'invoice/number'
    name = data 'name'
    date = data('event/date').strftime "%Y-%m-%d"

    ext.prepend '.' unless ext.length > 0 and ext.start_with? '.'

    if choice == :invoice
      "#{invoice_number} #{name} #{date}#{ext}"
    elsif choice == :offer
      "#{offer_number} #{name}#{ext}"
    else
      return false
    end
  end
end

class InvoiceProduct
  attr_reader :name, :hash, :tax, :valid, :returned,
    :total_invoice, :cost_offer, :cost_invoice, :cost_offer, :tax_invoice, :tax_offer,
    :price

  def initialize(hash, tax_value = $SETTINGS['defaults']['tax'])
    @hash      = hash
    @name      = hash[:name]
    @price     = hash[:price]
    @amount    = hash[:amount]
    @tax_value = tax_value
    fail "TAX MUST NOT BE > 1" if @tax_value > 1


    @valid = true
    calculate() unless hash.nil?
  end

  def to_s
    "#{@amount}|#{@sold} #{@name}, #{@price} cost (#{@cost_offer}|#{@cost_invoice}) total(#{@total_offer}|#{@total_invoice}) "
  end

  def calculate()
    return false if @hash.nil?
    @valid    = false unless @hash[:sold].nil? or @hash[:returned].nil?
    @valid    = false unless @hash[:amount] and @hash[:price]
    @sold     = @hash[:sold]
    @price    = @hash[:price].to_euro
    @amount   = @hash[:amount]
    @returned = @hash[:returned]

    if @sold
      @returned = @amount - @sold
    elsif @returned
      @sold = @amount - @returned
    else
      @sold = @amount
      @returned = 0
    end

    @hash[:cost_offer]   = @cost_offer   = (@price * @amount).to_euro
    @hash[:cost_invoice] = @cost_invoice = (@price * @sold).to_euro

    @hash[:tax_offer]    = @tax_offer    = (@cost_offer   * @tax_value)
    @hash[:tax_invoice]  = @tax_invoice  = (@cost_invoice * @tax_value)

    @hash[:total_offer]    = @total_offer    = (@cost_offer   + @tax_offer)
    @hash[:total_invoice]  = @total_invoice  = (@cost_invoice + @tax_invoice)
    self.freeze
  end

  def amount choice
    return @sold   if choice == :invoice
    return @amount if choice == :offer
    return -1
  end

  def cost choice
    return @cost_invoice if choice == :invoice
    return @cost_offer   if choice == :offer
    return -1.to_euro
  end
end
