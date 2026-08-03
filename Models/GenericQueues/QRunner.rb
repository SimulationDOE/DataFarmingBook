#!/usr/bin/env ruby
# frozen_string_literal: true

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

if ARGV.length < 8
  err_msg
else
  inputstr = ARGV.clone
  inputstr.delete_at 7
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
