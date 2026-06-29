#!/usr/bin/env ruby
# frozen_string_literal: true

require 'simplekit'
require 'random_variates'

# Simple stochastic DES model of Pandemic infection propagation
class Pandemic
  include SimpleKit

  # Constructor - initializes the model parameters. Units are days.
  def initialize(
    initial_population,
    initial_infected,
    avg_new_per_infected,
    intervention_day,
    trans_ratio_reduction
  )
    @initial_population = initial_population
    @initial_infected = initial_infected
    @mean_contacts = 10
    @intervention_day = intervention_day
    min_gestation = 2
    max__gestation = 21
    mode__gestation = 7
    @friend_pool_dist = RV::Poisson.new(rate: @mean_contacts)
    @contagious_dist =
      RV::Triangle.new(min: min_gestation, max: max__gestation, mode: mode__gestation)
    @startup_dist = RV::Uniform.new(min: min_gestation, max: max__gestation)
    min_removal_t = 6
    max_removal_t = 24
    mode_removal_t = 16
    @removal_dist =
      RV::Triangle.new(min: min_removal_t, max: max_removal_t, mode: mode_removal_t)
    avg_duration = (min_removal_t + max_removal_t + mode_removal_t) / 3.0
    rate = avg_new_per_infected / avg_duration / @mean_contacts
    intervention_rate = (1.0 - trans_ratio_reduction) * rate
    @infection_dist = RV::Exponential.new(rate: rate)
    @intervention_dist = RV::Exponential.new(rate: intervention_rate)
    @report_threshold = 10_000
  end

  # Initialize the model state and schedule any necessary events.
  def init
    @susceptibles = @initial_population - @initial_infected
    @total_infected = @initial_infected
    @contagious_pool = 0
    @currently_infected = @initial_infected
    @initial_infected.times do
      schedule(:infectious, @startup_dist.next)
    end
    schedule(:intervention, @intervention_day)
  end

  # An exposed event increments the number of infecteds, reduces the number
  # of susceptibles, and schedules when this patient will become contagious.
  def exposed
    @susceptibles -= 1
    @total_infected += 1
    @currently_infected += 1
    if @susceptibles.zero?
      schedule(:end_sim, 0)
    else
      schedule(:infectious, @contagious_dist.next)
    end
  end

  # Upon becoming infectious, we generate a patient's pool of potential
  # exposures.  For each potential, generate when the exposure would
  # occur and schedule the new exposure unless the current patient
  # becomes non-infectious before that time.
  def infectious
    @contagious_pool += 1
    contact_rate = @mean_contacts * @susceptibles.to_f / @initial_population
    if contact_rate > 0.0
      @friend_pool_dist.rate = contact_rate
      num_potentials = [@friend_pool_dist.next, @susceptibles].min
      duration = @removal_dist.next
      schedule(:removal, duration)
      # Could also generate secondary and tertiary pools with different pool
      # sizes and rates of infection, but since that would be a superposition
      # of Poissons it can be accomodated via changing the rate above.
      num_potentials.times do
        time_to_infection = @infection_dist.next
        schedule(:exposed, time_to_infection) unless time_to_infection > duration
      end
    else
      schedule(:end_sim, 0)
    end
  end

  # Patient is removed from the active pool due to recovery or death.
  def removal
    @contagious_pool -= 1
    @currently_infected -= 1
    schedule(:end_sim, 0) if @currently_infected.zero?
  end

  # Intervention changes the infection rate
  def intervention
    @infection_dist = @intervention_dist
  end

  # A report mechanism which dumps the invoking event, time, and values
  # of the state variables to the console.  This report is used when
  # the population is smaller.
  def end_sim
    printf "%.2f,%d,%d\n", model_time, @total_infected, @susceptibles
    halt
  end
end

if $PROGRAM_NAME == __FILE__
  def error_msg
    STDERR.print "\n  Correct usage:\n\n"
    STDERR.print "      ruby #{$PROGRAM_NAME} <# replications> <population size> \\\n"
    STDERR.print "\t<initial # infected> <per capita avg transmission ratio> \\\n"
    STDERR.print "\t<intervention start day> \\\n"
    STDERR.print "\t<proportion reduction in transmission ratio>\n\n"
    STDERR.print ''
    STDERR.print "  Example:\n\n"
    STDERR.print "      ruby #{$PROGRAM_NAME} 10 100_000 1 1.4 100 0.2\n\n"
    exit
  end

  replications = 10
  population = 100_000
  initial_infected = 1
  transmission_ratio = 1.4
  intervention_day = 100
  trans_ratio_reduction = 0.2

  case ARGV.length
  when 6
    # Instantiate an epidemic model with a particular parameterization and run it.
    replications = ARGV.shift.to_i
    population = ARGV.shift.to_i
    initial_infected = ARGV.shift.to_i
    transmission_ratio = ARGV.shift.to_f
    intervention_day = ARGV.shift.to_i
    trans_ratio_reduction = ARGV.shift.to_f
  when 1
    error_msg unless '--default' == ARGV.shift
  else
    error_msg
  end

  print 'Population,Initial Infected,Transmission Ratio,'
  print 'Intervention Start Day,Transmission Ratio Reduction,'
  puts 'Duration,Infected,Uninfected'
  replications.times do
    print "#{population},#{initial_infected},#{transmission_ratio},"
    print "#{intervention_day},#{trans_ratio_reduction},"
    Pandemic.new(population, initial_infected, transmission_ratio,
              intervention_day, trans_ratio_reduction).run
  end
end
