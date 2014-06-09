#!/usr/bin/env ruby

require 'bundler/setup'
require 'celluloid/io'
require 'http'
require 'redis'
class Checker
	begin
		def probe(url)
    		begin
		Timeout.timeout(10) { HTTP.get(url, :socket_class => Celluloid::IO::TCPSocket) }
		rescue Errno::EHOSTUNREACH, SystemCallError, Timeout::Error # ECONNREFUSED, etc
		       false
    		rescue SocketError => e                # DNS, unknown host
      			warn "#{e}"
      		      false
    		rescue Exception => e
      			warn "#{e.class.name} #{e}"
      		      false
    		end

  		end
	end
end


class HHCheck
  include Celluloid::IO
  finalizer :finalize
  def initialize(host, port)
    puts "*** Starting connect to redis on #{host}:#{port}"
    @red = Redis.new(:driver => :celluloid)
    async.run
  end

  def finalize
    @red.quit if @red
  end

  def run
	loop { async.healthcheck; sleep 10 }
  end

  def healthcheck()
	f = @red.keys('frontend:*')
	f.each do |frontend|
		b = @red.lrange(frontend,'0','-1')
			b.drop(1).each_with_index do |backend, index|
				begin
				check = Checker.new
				p "checking #{backend}"
					begin
					response = check.probe(backend)
					if response == false
						then
							p "#{backend} => DOWN"
							@red.publish('dead',frontend.gsub('frontend:','') + ';' + backend + ";" + index.to_s + ";" + b.size.to_s )
						else
						if response.status.to_s =~ /20\d/ then
							p "#{backend} => #{response.status} => UP"
							@red.srem('dead:' + frontend.gsub('frontend:',''),index)
						else	
							p "#{backend} => #{response.status} => DOWN"
							@red.publish('dead',frontend.gsub('frontend:','') + ';' + backend + ";" + index.to_s + ";" + b.size.to_s )
					end
					end
				end
			end	
		end
	end
  end
end
healthcheck = HHCheck.supervise("127.0.0.1", 6379)
trap("INT") { healthcheck.terminate; exit }
sleep