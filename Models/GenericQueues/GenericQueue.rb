require 'simplekit'
require 'quickstats'

# Define customers who have fixed transaction times and
# unique identifiers
class Customer
  attr_reader :arrival_time, :service_time, :id

  @@counter = 0

  def initialize(arrival_time:, service_time:)
    @@counter += 1
    @id = @@counter
    @arrival_time = arrival_time
    @service_time = service_time
  end
end

# Demonstration model of an G/G/k queueing system.  There are k servers
# and both the arrival and service processes are generic distributions.
class GGk
  include SimpleKit

  # Constructor - initializes the model parameters.
  # param: arrival_dist - The distribution with which customers arrive to the system.
  # param: service_dist - The distribution with which individual servers serve.
  # param: max_servers - The total number of servers in the system.
  # param: customers - number of customers to process
  def initialize(
    arrival_dist:, service_dist:, max_servers:, customers:, lifo: false, truncate: 0, stream: false
  )
    @max_servers = max_servers
    @max_customers = customers
    @arrival_dist = arrival_dist
    @service_dist = service_dist
    @LIFO = lifo
    @truncate = truncate
    @stream = stream
  end

  # Initialize the model state and schedule any necessary events.
  # Note that this particular model will terminate after the specified
  # number of customers have been through the queue.
  def init
    @num_available_servers = @max_servers
    @queue = []
    @summary_stats = QuickStats.new
    schedule(:arrival, @arrival_dist.next)
  end

  # An arrival event increments the queue length, schedules the next
  # arrival, and schedules a beginService event if a server is available.
  def arrival
    @queue << Customer.new(arrival_time: model_time, service_time: @service_dist.next)
    schedule(:arrival, @arrival_dist.next)
    schedule(:begin_service, 0.0) if @num_available_servers > 0
  end

  # Start service for the next eligible customer in line, removing that
  # customer from the queue and utilizing one of the available servers.
  # An endService will be scheduled.
  def begin_service
    if @LIFO
      customer = @queue.pop
    else
      customer = @queue.shift
    end
    @num_available_servers -= 1
    delay_in_queue = model_time - customer.arrival_time
    puts "#{customer.id},#{"%.4f" % delay_in_queue}" if @stream
    @summary_stats.new_obs delay_in_queue if customer.id > @truncate
    schedule(:end_service, customer.service_time)
  end

  # Frees up an available server, and schedules a beginService if
  # anybody is waiting in line.
  def end_service
    @num_available_servers += 1
    if @queue.empty?
      end_sim if (@summary_stats.n >= @max_customers)
    else
      schedule(:begin_service, 0.0)
    end
  end

  def end_sim
    avg = @summary_stats.avg
    n = @summary_stats.n
    loss = @summary_stats.ssd / n + avg * avg

    puts "#{avg},#{loss},#{n}"
    halt
  end
end
