#!/usr/bin/env ruby
#
# Run this as: bundle exec examples/echo_server.rb

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
    @red = Redis.new(:host => host, :port => port)
    async.run
  end

  def finalize
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
				p "checking #{backend}"
					begin
					response = check.probe(backend)
					if response == false
						then
							p "#{backend} => DOWN"
							@red.sadd('dead:' + frontend.gsub('frontend:',''),index + 1)
						else
						if response.status.to_s =~ /20\d/ then
							p "#{backend} => #{response.status} => UP"
							@red.srem('dead:' + frontend.gsub('frontend:',''),index + 1)
						else	
							p "#{backend} => #{response.status} => DOWN"
							@red.sadd('dead:' + frontend.gsub('frontend:',''),index + 1)
					end
					end
				end
			end	
		end
	end
  end
end

supervisor = HHCheck.supervise("127.0.0.1", 6379)
trap("INT") { supervisor.terminate; exit }
sleep