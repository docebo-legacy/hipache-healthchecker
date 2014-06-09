#!/usr/bin/env ruby

require 'bundler/setup'
require 'celluloid/io'
require 'redis'
class HHListener
  include Celluloid::IO
  finalizer :finalize
  def initialize(host, port)
  	puts "*** Starting connect to redis on #{host}:#{port}"
    	#@red = Redis.new(:driver => :celluloid)
    	@dead = Redis.new
	@redis = Redis.new
	async.run
  end

  def finalize
    @red.quit if @red
  end

  def run
	@dead.subscribe(:dead) do |on|
    		on.subscribe do |channel, subscriptions|
      			puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
    		end
		on.message do |channel, message|
			puts "##{channel}: #{message}"
			mark(message.split(";")[0],message.split(";")[2].to_i + 1)
			@dead.unsubscribe if message == "exit"
    		end

    		on.unsubscribe do |channel, subscriptions|
      			puts "Unsubscribed from ##{channel} (#{subscriptions} subscriptions)"
    		end
	end  	
  end
  
  def mark(frontend,backend_id)
	@redis.sadd('dead:' + frontend, backend_id)
  end

end
listener = HHListener.supervise("127.0.0.1", 6379)
trap("INT") { listener.terminate; exit }
sleep
