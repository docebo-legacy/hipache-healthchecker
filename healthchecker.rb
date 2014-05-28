#!/usr/bin/env ruby

require 'bundler/setup'
require 'celluloid/io'
require 'redis'
require 'addressable/uri'

class Checker
  def probe(host,port)
    begin
  	 Timeout.timeout(10) { TCPSocket.new(host, port).close }	
		  rescue SystemCallError, Timeout::Error # ECONNREFUSED, etc
			false
    		  rescue Exception => e
			p "qua"
      			warn "#{e.class.name}"
      			false
		end
	end
end

class HHCheck
  include Celluloid::IO
  finalizer :finalize
  def initialize(host, port)
    puts "*** Starting connect to redis on #{host}:#{port}"
    @red = Redis.new(:host => host, :port => port)
    async.run
  end

  def finalize
    @red.quit if @red
  end

  def run
	loop { async.healthcheck; sleep 2 }
  end

  def healthcheck()
	f = @red.keys('frontend:*')
	f.each do |frontend|
		b = @red.lrange(frontend,'1','-1')
			b.each_with_index do |backend, index|
				begin
					check = Checker.new
					p "checking #{frontend.gsub('frontend:','')} #{backend}"
					response = check.probe(Addressable::URI.parse(backend).host,Addressable::URI.parse(backend).port)
					if response == false then
						p "#{frontend} #{backend} morto"
						@red.sadd('dead:' + frontend.gsub('frontend:',''),index + 1)
    						else
						p "#{frontend} #{backend} alive'n'kickin'"
					end
					rescue DeadActorError
    				end
			end
	end    
  end
end

supervisor = HHCheck.supervise("127.0.0.1", 6379)
trap("INT") { supervisor.terminate; exit }
sleep