#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'random_variates'
require_relative 'GenericQueue.rb'

DISTRIBUTIONS = %w[exp sexp tri unif]
Q_DISCIPLINE = %w[fifo lifo]

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

TRI_CONST = 9.0 + Math.sqrt(45.0)

def pick_distribution(name:, mu:, rng: RV::U_GENERATOR)
  fail "Unknown distribution: '#{name}'" unless DISTRIBUTIONS.include?(name)
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
    fail "This should never happen!"
  end
end

USAGE =
  "usage: #{$PROGRAM_NAME} [-h] [-w WARMUP] [-s] [-r SEED1,SEED2]\n" +
  "                  nominal_customers rho arrival_rate arrival_dist\n" +
  "                  max_servers service_dist q_discipline [reps]\n\n"

options = {
  :lifo => false,
  :stream => false,
  :truncate => 0,
}

opt_parse = OptionParser.new do |opts|
  # opts.banner = "Usage: #{$PROGRAM_NAME} [-h|--help] [filenames...[]"
  opts.banner =
  USAGE +
  "Run control for a G/G/k queueing system\n\n" +
  "positional arguments:
    nominal_customers     Target number of customers to process
    rho                   Traffic intensity (0 < rho < 1)
    arrival_rate          Arrival process rate
    interarrival_dist     Interarrival time distribution {exp|sexp|tri|unif}
    max_servers           Maximum number of servers
    service_dist          Service time distribution {exp|sexp|tri|unif}
    q_discipline          Queueing discipline {fifo,lifo}
    [reps]                Replications (optional, default=1) \n\n" +
  "options:"
  opts.on(
    "-r", "--rnseeds SEED1,SEED2",
    Array,
    "Seed values for arrival/service processes"
  ) do |rnseeds|
      opts.abort "Two seed values are required" if rnseeds.size != 2
      # options[:rnseeds] = rnseeds.map(&:to_i) # Convert each element to Integer
      # opts.abort("Seeds must be strictly positive integers") if options[:rnseeds].any? {|x| x < 1}
      # options[:rnseeds]
      rnseeds.map!(&:to_i) # Convert each element to Integer
      opts.abort("Seeds must be strictly positive integers") if rnseeds.any? {|x| x < 1}
      puts "Random number seeds provided: #{rnseeds.inspect}"
      rnseeds
  end
  opts.on(
    "-s", "--stream",
    TrueClass,
    "Toggle streaming of full output"
  )
  opts.on(
    "-t AMT", "--truncate",
    Integer,
    "Amount to truncate for system warmup"
  ) do |value|
      v = value.to_i
      opts.abort "Truncation amount must be positive" if v < 0
      v
  end
end

opt_parse.parse!(into: options)

unless [7,8].include? ARGV.length
  opt_parse.parse %[--help]
else
  reps = (ARGV.length == 7) ? 1 : ARGV.pop.to_i
  fail 'Number of reps must be strictly positive' if reps < 1
  inputs = ARGV.join ','
  options[:customers] = ARGV.shift.to_i
  fail 'Target number of customers must be strictly positive' if options[:customers] < 1
  rho = ARGV.shift.to_f
  fail 'Traffic intensity must be in range 0 < rho < 1' unless (rho > 0.0 && rho < 1.0)
  arr_rate = ARGV.shift.to_f
  fail 'Arrival rate must be strictly positive' unless arr_rate > 0.0
  arr_mean = 1.0 / arr_rate
  arr = ARGV.shift.downcase
  options[:max_servers] = ARGV.shift.to_i
  svc_mean = rho * arr_mean * options[:max_servers]
  svc = ARGV.shift.downcase
  q_disc = ARGV.shift.downcase
  fail 'Invalid option for queue discipline (lifo/fifo)' unless Q_DISCIPLINE.include? q_disc
  options[:lifo] = true if 'lifo' === q_disc
  if options.has_key? :rnseeds
    seed1, seed2 = options.delete(:rnseeds)
    rng1 = Xoroshiro::Random.new(seed: seed1)
    rng2 = Xoroshiro::Random.new(seed: seed2)
  else
    rng1 = RV::U_GENERATOR
    rng2 = RV::U_GENERATOR
  end
  options[:arrival_dist] = pick_distribution(name: arr, mu: arr_mean, rng: rng1)
  options[:service_dist] = pick_distribution(name: svc, mu: svc_mean, rng: rng2)

  print 'nominal#customers,rho,lambda,arrival_dist,' +
    '#servers,service_dist,queue_discipline'
  if options[:stream]
    puts inputs
  else
    puts ',avg_delay,avg_loss,#customers'
  end

  reps.times do |rep|
    if options[:stream]
      if reps > 1
        puts "\nrep_#{rep+1}"
      else
        puts
      end
      puts 'customer_id,delay'
    else
      print(inputs + ',')
    end
    # Instantiate a GGk object and run it.
    GGk.new(**options).run
  end
end
