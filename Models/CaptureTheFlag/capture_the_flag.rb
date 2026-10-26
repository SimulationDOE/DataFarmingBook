#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'random_variates'

Ygrid = [
  [0.0585,0.0585,0.0585,0.0585,0.0585,0.0585,0.0585,0.0585,0.0585,0.0585,0.0585],
  [0.0585,0.0856,0.1488,0.3231,0.3452,0.3470,0.3476,0.3476,0.3476,0.3476,0.3476],
  [0.0585,0.0858,0.3212,0.3834,0.3858,0.3858,0.3877,0.3890,0.3895,0.3995,0.4195],
  [0.0585,0.1397,0.3768,0.3834,0.4105,0.4277,0.4421,0.4556,0.4572,0.4631,0.4698],
  [0.0585,0.1668,0.3840,0.4150,0.4613,0.4714,0.4775,0.4794,0.4776,0.4827,0.4998],
  [0.0585,0.2390,0.3904,0.4376,0.4764,0.5154,0.5242,0.5368,0.5368,0.5549,0.5729],
  [0.0585,0.2571,0.4015,0.5007,0.6181,0.6903,0.7444,0.7805,0.8290,0.8310,0.8310],
  [0.0585,0.2632,0.4376,0.6722,0.7354,0.8013,0.8412,0.8617,0.8752,0.8766,0.8820],
  [0.0585,0.3550,0.4737,0.7113,0.7636,0.8121,0.8545,0.8895,0.9171,0.9171,0.9171],
  [0.0585,0.4015,0.6181,0.7354,0.7682,0.8184,0.8625,0.8991,0.9280,0.9281,0.9281],
  [0.0585,0.4015,0.6812,0.7444,0.7692,0.8200,0.8649,0.8997,0.9281,0.9281,0.9300]].freeze

# UNIF = RV::Uniform.new(min: -1.0, max: 1.0)

options = {
  :ground_truth => false,
  :stream => false,
}

opt_parse = OptionParser.new do |opts|
  opts.banner = "usage: #{$PROGRAM_NAME} [options] [positional args]\n\nCapture the Flag demo model\n\nOptions:"
  opts.on(
    "-h", "--help",
    "show this help message and exit"
  ) do
    puts
    puts opts
    puts "\nDash-based options are parsed first, any remaining command-line"
    puts "values are interpreted as positional arguments."
    puts "\nPositional arguments:"
    puts "    speed       value in range (0, 1)"
    puts "    stealth     value in range (0, 1)"
    puts "    n_games     number of games to play (n_games > 0)"
    puts "\nIf no positional arguments are provided, you will be"
    puts "prompted interactively to input their values."
    puts
    exit
  end
  opts.on(
    "-g", "--ground_truth",
    TrueClass,
    "report ground truth prob_win (default=no)"
  )
  opts.on(
    "-s", "--stream",
    TrueClass,
    "stream output (default=off)"
  )
  opts.on(
    "-r", "--rnseed SEED",
    Integer,
    "random number seed (optional)"
  ) do |s|
      opts.abort("Seeds must be strictly positive integers") if s < 1
      options[:rnseed] = s
  end

end

opt_parse.parse!(into: options)

def check_0_1(value)
  fail "Value #{value} outside the range [0,1]" unless (value > 0.0 and value < 1.0)
end

speed = (ARGV.shift || (STDERR.print 'Enter speed between 0 and 1: '; gets)).to_f
fail "Speed: #{speed} outside the range [0,1]" unless (0.0..1.0).include?(speed)
stealth = (ARGV.shift || (STDERR.print 'Enter stealth between 0 and 1: '; gets)).to_f
fail "Stealth #{stealth} outside the range [0,1]" unless (0.0..1.0).include?(stealth)
n_games = (ARGV.shift || (STDERR.print 'Enter number of games: '; gets)).to_i
fail "N_games must be a strictly positive integer" unless n_games > 0

# Find the surrounding grid points for each factor.
speed_low = (speed * 10).floor.to_i
speed_up = (speed * 10).ceil.to_i
stealth_low = (stealth * 10).floor.to_i
stealth_up = (stealth * 10).ceil.to_i
x1 = speed * 10
x2 = stealth * 10

# Perform interpolation as needed on the grid.
if (speed_up > speed_low)
  if (stealth_up > stealth_low)
    y1 = Ygrid[speed_low][stealth_low] + ((x1 - speed_low)/(speed_up - speed_low).to_f) * (Ygrid[speed_up][stealth_low] - Ygrid[speed_low][stealth_low])
    y2 = Ygrid[speed_low][stealth_up] + ((x1 - speed_low)/(speed_up - speed_low).to_f) * (Ygrid[speed_up][stealth_up] - Ygrid[speed_low][stealth_up])
    y = y1 + ((x2 - stealth_low)/(stealth_up - stealth_low).to_f) * (y2 - y1)
  else
    y = Ygrid[speed_low][stealth_low] + ((x1 - speed_low)/(speed_up - speed_low).to_f) * (Ygrid[speed_up][stealth_low] - Ygrid[speed_low][stealth_low])
  end
else
  if (stealth_up > stealth_low)
    y = Ygrid[speed_low][stealth_low] + ((x2 - stealth_low)/(stealth_up - stealth_low).to_f) * (Ygrid[speed_low][stealth_up] - Ygrid[speed_low][stealth_low])
  else
    y = Ygrid[speed_low][stealth_low]
  end
end

# Uncomment the following line to modify for explicit variance modification.
# If so, don't forget to uncomment UNIF up above (line 20) and comment line 102.
#
# prop_win = y+(UNIF.next * (((1.0 - speed) * 10) + 1) / 200.0)

# Use the line below for straight Binomial outcomes.
prob_win = y

generator = options.has_key?(:rnseed) ?
        Xoroshiro::Random.new(seed: options[:rnseed]) :
        RV::U_GENERATOR
binom = RV::Binomial.new(p: prob_win, n: 1, rng: generator)
results = Array.new(n_games) { binom.next }

truth = options[:ground_truth] ? "#{'%.4f' % prob_win}," : ''
if options[:stream]
  puts "speed,stealth,#{options[:ground_truth] ? 'prob_win,' : ''}outcome"
  results.each do |result|
    puts "#{speed},#{stealth},#{truth}#{result.zero? ? 'lose' : 'win'}"
  end
else
  puts "speed,stealth,n_games,#{options[:ground_truth] ? 'prob_win,' : ''}games_won"
  puts "#{speed},#{stealth},#{n_games},#{truth}#{results.sum}"
end
