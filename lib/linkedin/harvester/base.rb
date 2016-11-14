require "linkedin/harvester/version"
require 'watir-webdriver'
require 'pry'
require 'nokogiri'
require 'csv'
require 'io/console'


module Linkedin::Harvester
  class Base
    def initialize(opts)
      @email = opts[:email]
      @query = opts[:query]
      @password = opts[:password]
    end


    def run!
      if @password.nil?
        print 'Password:'
        @password = STDIN.noecho(&:gets).chomp
      end

      b = Watir::Browser.new :phantomjs

      b.goto "https://www.linkedin.com"

      #if File.exist? 'cookies.yml'
      #  b.cookies.load 'cookies.yml'
      #  b.goto "https://www.linkedin.com"
      #else
      b.form(class: 'login-form ')

      b.form(class: 'login-form').text_field(name: 'session_key').set @email
      b.form(class: 'login-form').text_field(name: 'session_password').set @password

      b.form(class: 'login-form ').submit
      b.cookies.save 'cookies.yml'
      #end

      b.form(id: 'global-search').text_field(id: 'main-search-box').set @query
      b.form(id: 'global-search').submit

      b.ol(id: 'results').wait_until_present

      b.ol(id: 'results').li(class:'people').wait_until_present
      employees = []
      while b.div(id: 'results-pagination').li(class: 'next').a(rel: 'next').exist?
        #ol = b.ol(id: 'results')

        html = Nokogiri::HTML(b.html)
        ol = html.xpath("//ol[@id='results']")
        lis = ol.xpath("//li[contains(@class, 'people')]")
        lis.each do |lihtml|
          name = nil
          link = nil
          role = nil
          work_key = nil
          work = nil
          li = Nokogiri::HTML(lihtml.inner_html)
          name = li.xpath("//h3/a").text
          link = li.xpath("//h3/a").map{|link| link['href'] }
          role = li.xpath("//div[contains(@class, 'description')]").text
          work_key = li.xpath("//dl[contains(@class, 'snippet')]/dt").text
          work = li.xpath("//dl[contains(@class, 'snippet')]/dd").text
          employees << {
            name: name.to_s,
            link: link.to_s,
            role: role.to_s,
            snippet_key: work_key.to_s,
            snippet_value: work.to_s
          }
        end

        puts employees.size.to_s+'...'
        b.div(id: 'results-pagination').li(class: 'next').a(rel: 'next').click rescue nil
        b.ol(id: 'results').li(class:'people').wait_until_present
      end

      employees.uniq!{|person| person[:name] }

      CSV.open('employees.csv', 'w') do |csv|
        employees.each do |person|
          csv << person.values
        end
      end
    end

  end
end
