#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'random_variates'
require_relative 'GenericQueue.rb'

TRI_CONST = 9.0 + Math.sqrt(45.0)

class ShiftedExponential
  include RV::RV_Generator

  def initialize(mean:, offset:, rng: RV::U_GENERATOR)
    @my_exp = RV::Exponential.new(mean: mean, rng: rng)
    @offset = offset
  end

  def next
    @offset + @my_exp.next
  end
end

def pick_distribution(name:, mu:, rng: RV::U_GENERATOR)
  case name
  when 'exp'
    RV::Exponential.new(mean: mu, rng: rng)
  when 'sexp'
    exp_mean = mu / Math.sqrt(3.0)
    exp_offset = mu - exp_mean
    ShiftedExponential.new(mean: exp_mean, offset: exp_offset, rng: rng)
  when 'tri'
    tri_mode = 6.0 * mu / TRI_CONST
    tri_max = 3.0 * mu - tri_mode
    RV::Triangle.new(min: 0, max: tri_max, mode: tri_mode, rng: rng)
  when 'unif'
    RV::Uniform.new(min: 0, max: 2.0 * mu, rng: rng)
  else
    raise "Unknown distribution: '#{name}', should be 'exp', 'sexp' 'tri', or 'unif'\n\tfor exponential, shifted exponential, triangle, or uniform"
  end
end

args = {}
args[:stream] = false

def err_msg
  STDERR.puts
  warn 'Must supply cmd-line arguments for:'
  warn "\n\t#customers\n\ttraffic intensity (0...1)\n\tarrival rate"
  warn "\tarrival dist (exp/sexp/tri/unif)\n\t#servers"
  warn "\tservice dist (exp/sexp/tri/unif)\n\t'fifo' or 'lifo'\n\t#replications"
  warn "\nOptionally, two additional integer-valued cmd-line arguments"
  warn "can be provided for seeding the arrival and service processes.\n"
  STDERR.puts
end

if ARGV.length == 10
  rng1 = Xoroshiro::Random.new(seed: ARGV.pop.to_i)
  rng2 = Xoroshiro::Random.new(seed: ARGV.pop.to_i)
else
  rng1 = RV::U_GENERATOR
  rng2 = RV::U_GENERATOR
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [-h|--help] [filenames...[]"
  opts.on(
      "-s", "--stream",
      args[:stream] = true,
      "Toggle streaming of full output",
  #     action='store_true'
  )
  opts.on(
    "-r", "--rnseeds seed1,seed2",
    Array,
    "Provide six comma-separated integer random number seeds"
  ) do |rnseeds|
    # options[:rnseeds] = rnseeds.map(&:to_i) # Convert each element to Integer
    # pp rnseeds.map
    # pp rnseeds
    options[:rngs] = rnseeds.map do |seed|
      Xoroshiro::Random.new(seed: seed.to_i) # Convert each element to integer to seed rng
    end
  end
end.parse!

# Check if we have exactly six integers

if options[:rngs].nil?
  options[:rngs] = Array.new(6) { Xoroshiro::Random.new }
else
  if options[:rngs].size != 6
    puts "Please provide six comma-separated integers using the -r option,"
    puts "or leave out the -r option to use system-generated seeds"
    exit
  end
end

# parser = argparse.ArgumentParser(
#     prog=program_name,
#     description="Run control for a G/G/k queueing system",
#     # epilog=f"Example: python {program_name} 2.5 2 7.0 50 0.1 green"
# )
# parser.add_argument("nominal_customers", help="Target number of customers to process", type=int)
# parser.add_argument("rho", help="traffic intensity", type=range_checker)
# parser.add_argument("arrival_rate", help="Rate of arrival process", type=float)
# parser.add_argument(
#     "arrival_dist",
#     help="Distribution of arrival process",
#     choices=['exp','sexp','tri','unif']
# )
# parser.add_argument("max_servers", help="Maximum number of servers", type=int)
# parser.add_argument(
#     "service_dist",
#     help="Distribution of service process",
#     choices=['exp','sexp','tri','unif']
# )
# parser.add_argument(
#     "q_discipline",
#     help="Is this a FIFO or LIFO queue?",
#     choices=['fifo','lifo']
# )
# parser.add_argument(
#     "reps",
#     nargs='?',
#     default=1,
#     help="Number of replications to run",
#     type=int
# )
# parser.add_argument(
#     "-w", "--warmup",
#     default=0,
#     help="Amount to truncate for system warmup",
#     type=int
# )
# parser.add_argument(
#     "-s", "--stream",
#     help="Toggle streaming of full output",
#     action='store_true'
# )
# parser.add_argument(
#     "-r", "--rnseeds",
#     nargs=2, default=[],
#     help="Optional pair of seed values for arrival and service processes",
#     type=int
# )
# args = parser.parse_args()

if ARGV.length < 8
  err_msg
else
  inputstr = ARGV.clone
  pp inputstr
  inputstr.delete_at 7
  pp inputstr
  inputs = inputstr.join ','
  args[:customers] = ARGV.shift.to_i
  traffic = ARGV.shift.to_f
  arr_mean = 1.0 / ARGV.shift.to_f
  arr = ARGV.shift.downcase
  args[:max_servers] = ARGV.shift.to_i
  svc_mean = traffic * arr_mean * args[:max_servers]
  svc = ARGV.shift.downcase
  args[:lifo] = case ARGV.shift.downcase
                when 'lifo'
                  true
                when 'fifo'
                  false
                else
                  raise 'Invalid option for lifo/fifo'
  end
  reps = ARGV.shift.to_i

  args[:arrival_dist] = pick_distribution(name: arr, mu: arr_mean, rng: rng1)
  args[:service_dist] = pick_distribution(name: svc, mu: svc_mean, rng: rng2)
  # Instantiate a GGk object and run it.
  print 'nominal #customers,rho,lambda,arrival dist,#servers,service dist,'
  puts 'queue discipline,avg delay,loss,#customers'
  reps.times do
    print inputs + ','
    GGk.new(**args).run
  end
end
