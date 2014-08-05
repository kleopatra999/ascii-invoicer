# encoding: utf-8
require 'ostruct'
require 'fileutils'
require File.dirname(__FILE__) + '/spec_helper'

$SETTINGS = YAML::load(File.open(File.join File.dirname(__FILE__), "../default-settings.yml"))

describe InvoiceProject do
  # it loads yml files
  # it matches addresses correctly
  # it sums up correctly
  # it detects duplicate entries
  
  class FilterClass
  end
  before :context do
    @settings = $SETTINGS
    @settings['script_path'] = "."
    @test_project_path = File.join File.dirname(__FILE__), "test_projects"

    @projects = {}
    @project_paths = {}

    Dir.glob(File.join @test_project_path, "*.yml" ).map{|name| @project_paths[File.basename(name, '.yml')] = name}

    #puts "before context"
  end

  before :example do
    #puts "before example"
    @p_old = InvoiceProject.new @settings
    @project       = InvoiceProject.new @settings
    @p_old.open @project_paths['alright']
    @p_250 = InvoiceProject.new @settings
    @p_250.open @project_paths['alright_250']

    @filter = FilterClass.new
    @filter.extend Filters

    @project       = InvoiceProject.new @settings
    @project2      = InvoiceProject.new @settings
    @project3      = InvoiceProject.new @settings
    @project4      = InvoiceProject.new @settings
    @project5      = InvoiceProject.new @settings
  end

  after :example do
  end

  describe "#initialize" do
  end

  describe "#open" do
    it "loads project file" do
      expect(File).to exist @project_paths['alright']
      project  = InvoiceProject.new @settings
      expect(project.open @project_paths['alright']).to be_truthy
    end

    it "refuses to load a second project file" do
      expect(File).to exist @project_paths['alright']
      @project.open @project_paths['alright']
      expect{@project.open(@project_paths['alright'])}.to raise_exception
    end
  end

  describe "#strpdates" do
    it "reads single dates" do
      dates = @filter.strpdates("17.07.2013")
      expect(dates).to be_an_instance_of Array
      expect(dates[0]).to be_an_instance_of Date
      expect(dates[0]).to be == Date.new(2013,07,17)
    end

    it "reads pairs of dates" do
      dates = @filter.strpdates("17-18.07.2013")
      expect(dates).to be_an_instance_of Array
      expect(dates[0]).to be_an_instance_of Date
      expect(dates[0]).to be == Date.new(2013,07,17)
      expect(dates[1]).to be_an_instance_of Date
      expect(dates[1]).to be == Date.new(2013,07,18)
    end
  end

  describe "#validate" do
    it "distinguishes between old and new format" do
      #expect(true).to be false
    end

    it "validates email addresses" do
      expect(@p_old.read :email).to eq "john.doe@example.com"
      #expect(@p_250.read :email).to eq "john.doe@example.com"

      @project.raw_data = {'email' => "john.doe@com"}
      expect(@project.read :email).to be_truthy

      @project2.raw_data = {'email' => "john.doeexample.com"}
      expect(@project2.read :email).to be_falsey

      @project3.raw_data = {'email' => "john.doe@@example.com"}
      expect(@project3.read :email).to be_falsey

      @project4.raw_data = {'email' => ".@.com"}
      expect(@project4.read :email).to be_falsey

      @project5.raw_data =  {'email' => "john.doe@example.com"}
      expect(@project5.read :email).to be_truthy
    end

    it "validates the date" do
      expect(@p_old.read :date).to be_truthy
      @p_old.read :date
      expect(@p_old.data[:date]).to eq Date.new(2013,7,20)

      @project2.open @project_paths['missing_date']
      expect(@project2.read :date).to be_falsey

      @project3.open @project_paths['broken_date']
      expect(@project3.read :date).to be_falsey
    end

    it "validates date ranges" do
      @project2.open @project_paths['date_range']
      expect(@project2.read :date).to be_truthy
      @project2.read :date
      @project2.read :date_end, :read_date,:end
      expect(@project2.data[:date]).to     eq Date.new(2013,7,20)
      expect(@project2.data[:date_end]).to eq Date.new(2013,7,26)

      @project3.open @project_paths['date_range2']
      expect(@project3.read :date).to be_truthy
      @project3.read :date
      @project3.read :date_end, :read_date,:end
      expect(@project3.data[:date]).to     eq Date.new(2013,7,20)
      expect(@project3.data[:date_end]).to eq Date.new(2013,7,26)

      @project4.open @project_paths['date_range3']
      expect(@project4.read :date).to be_truthy
      @project4.read :date
      @project4.read :date_end, :read_date,:end
      expect(@project4.data[:date]).to     eq Date.new(2013,7,20)
      expect(@project4.data[:date_end]).to eq Date.new(2013,7,26)

      @project5.open @project_paths['date_range_blank_end']
      expect(@project5.read :date).to be_truthy
      @project5.read :date
      @project5.read :date_end, :read_date,:end
      expect(@project5.data[:date]).to     eq Date.new(2014,7,04)
      expect(@project5.data[:date_end]).to eq Date.new(2014,7,04)
    end

    it "validates numbers" do
      @p_old.read :offer_number
      @p_old.read :invoice_number
      @p_old.read :invoice_number_long
      expect(@p_old.data[:offer_number]).to eq Date.today.strftime("A%Y%m%d-1")
      expect(@p_old.data[:invoice_number]).to eq "R027"
      expect(@p_old.data[:invoice_number_long]).to eq "R2013-027"
    end

    it "validates client" do
      expect(@p_old.read(:client)).to be_truthy
      expect(@p_old.data[:client][:last_name]).to  eq 'Doe'
      expect(@p_old.data[:client][:addressing]).to eq 'Sehr geehrter Herr Doe'

      #expect(@p_250.read(:client)).to be_truthy
      #expect(@p_250.data[:client][:last_name]).to  eq 'Doe'
      #expect(@p_250.data[:client][:addressing]).to eq 'Sehr geehrter Herr Doe'
    end

    it "validates missing client" do
      @project.open @project_paths['missing_client']
    end

    it "validates long client" do
      @project.open @project_paths[ 'client_long_title' ]
      expect(@project.read(:client)).to be_truthy
      @project.data[:client]
      expect(@project.data[:client][:last_name]).to eq 'Doe'
      expect(@project.data[:client][:addressing]).to eq 'Sehr geehrter Professor Dr. Dr. Doe'

      @project2.open @project_paths[ 'client_long_title2' ]
      expect(@project2.read(:client)).to be_truthy
      expect(@project2.data[:client][:last_name]).to eq 'Doe'
      expect(@project2.data[:client][:addressing]).to eq 'Sehr geehrte Frau Professor Dr. Dr. Doe'

      @project3.open @project_paths[ 'client_long_title3' ]
      expect(@project3.read(:client)).to be_truthy
      expect(@project3.data[:client][:last_name]).to eq 'Doe'
      expect(@project3.data[:client][:addressing]).to eq 'Sehr geehrter Herr Professor Dr. Dr. Doe'

      @project4.open @project_paths[ 'client_female' ]
      expect(@project4.read(:client)).to be_truthy
      expect(@project4.data[:client][:last_name]).to eq 'Doe'
      expect(@project4.data[:client][:addressing]).to eq 'Sehr geehrte Frau Doe'
    end

    it "validates description" do
      # TODO implement
      expect(@project.open @project_paths['described'])
      expect(@project.read(:description)).to be_truthy
      #expect(@project.data[:description]).to eq "test\ntest"
      expect(@project.data[:description]).to eq "Hi there, this is what we're going to do:\nFirst we will pack our swimsuites, then we will go to Freiberger Straße\nand then we will äëïöü!\n\nDanke"
    end

    #it "passes a canceled catering" do
    #  # TODO implement
    #  expect(false).to eq true
    #end

    #it "validates time" do
    #  # TODO implement
    #  expect(false).to eq true
    #end

    it "validates caterer" do
      # TODO implement
      expect(@p_old.read(:caterers)).to be_truthy

      expect(@p_old.data[:caterers][0]).to eq "Name"
      expect(@p_old.data[:caterers][1]).to eq "Name2"

      expect(@p_old.read(:hours)).to be_truthy
      expect(@p_old.data[:hours][:caterers]['Name' ]).to eq 5
      expect(@p_old.data[:hours][:caterers]['Name2']).to eq 2.6

      expect(@p_old.data[:hours][:time]).to eq @p_old.data[:hours][:time_each]

      #name = "no_caterers"
      #@project2.open @project_paths[name]

    end

    it "validates manager" do
      expect(@p_old.read(:manager)).to be_truthy
      expect(@p_old.data[:manager]).to eq 'Manager Bob'

      @project2.open @project_paths['signature_long']
      expect(@project2.read(:manager)).to be_truthy
      expect(@project2.data[:manager]).to eq 'Hendrik Sollich'
    end

    it "validates signature" do
      expect(@p_old.read(:signature)).to be_truthy
      expect(@p_old.data[:signature]).to eq 'Mit freundlichen Grüßen'

      @project2.open @project_paths['signature_long']
      expect(@project2.read(:signature)).to be_truthy
      expect(@project2.data[:signature]).to eq "Yours Truely\nHendrik Sollich"
    end

    it "validates hours" do
      expect(@p_old.read(:hours)).to be_truthy

      @project2.open @project_paths['hours_missmatching']
      expect(@project2.read(:hours)).to be_truthy

      @project3.open @project_paths['hours_simple']
      expect(@project3.read(:hours)).to be_truthy

      @project4.open @project_paths['hours_missing']
      expect(@project4.read(:hours)).to be_falsey

      @project5.open @project_paths['hours_missing_salary']
      expect(@project5.read(:hours)).to be_falsey
    end

    it "validates products" do
      expect(@p_old.read(:products)).to be_truthy

      @project2.open @project_paths['products_missing']
      expect(@project2.read(:products)).to be {}

      @project3.open @project_paths['products_empty']
      expect(@project3.read(:products)).to be_falsey

      @project4.open @project_paths['products_soldandreturned']
      expect(@project4.read(:products)).to be_falsey

      ## cant be tested because YAML::load already eliminates the duplicate
      #@project5.open @project_paths['products_name_twice']
      #@project5.read(:products)).to be_falsey
    end

    [:list, :offer, :invoice].each { |type|
      it "validates for #{type.to_s}" do
        
        project       = InvoiceProject.new @settings
        project.open @project_paths['alright']
        project.validate type
        puts project.errors unless@p_old.valid_for[type]
        expect(project.valid_for[type]).to be true
      end
    }


    #it "sums up products" do
    #  @project.open @project_paths['alright']
    #  expect(@project.read(:products)).to be_truthy
    #  @project.read :products
    #  #pp @project.data['products']
    #  expect(@project.get_cost(:offer)).to    eq 50.14
    #  expect(@project.get_cost(:invoice)).to  eq 31.55
    #  expect(@project.data[:products]['sums']['offered_tax']).to  eq 59.67
    #  expect(@project.data[:products]['sums']['invoiced_tax']).to eq 37.54
    #end

    ##it "validates for invoices" do
    ##  # Rechnungsnummer
    ##end

    ##it "validates for offers" do
    ##end

  end

end
