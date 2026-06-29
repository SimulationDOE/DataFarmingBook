#!/usr/bin/env ruby

begin
  require 'simplekit'
  require 'quickstats'
  require 'random_variates'
  require 'optparse'
rescue LoadError => e
  missing = e.message.split[-1]
  STDERR.puts "\nERROR:  " + e.message
  STDERR.puts "\n\tRun the command \"gem install #{missing}\" to fix this."
  STDERR.puts "\t(This may require administrative privileges on Windows or"
  STDERR.puts "\tuse of the \"sudo\" command on OS X or linux.)"
  STDERR.puts
  exit
end


# Demonstration model of Fleet Availability

class FleetAvail
  include SimpleKit

  # model state
  attr_reader  :numAvailableVehicles,
    :numAvailableMechanics,
    :maintenanceQLength,
    :breakdownQLength

  # model parameters
  attr_reader  :maxVehicles,
    :maxMaintainers,
    :breakdownRate,
    :maintenanceCycleInDays,
    :repairRate,
    :haltTime,
    :outputType

  # the actual model implementation...

  # Constructor initializes the model parameters.
  def initialize(maxVehicles, maxMaintainers, breakdownRate,
                 maintenanceCycleInDays, pStdRepair,
                 pStdMaint, distributionChoice, alpha, beta, haltTime,
                 outputType, rngs)
    @maxVehicles = maxVehicles
    @maxMaintainers = maxMaintainers
    @breakdownRate = breakdownRate
    @maintenanceCycleInDays = maintenanceCycleInDays
    @pStdRepair = pStdRepair
    @pStdMaint = pStdMaint
    # @repairRate = 1.0 / meanRepairTime
    @distributionChoice = distributionChoice
    @haltTime = haltTime
    @outputType = outputType
    @rngs = rngs

    if (outputType == 's')
      STDOUT.printf "initial stock,"
      STDOUT.printf "#maintainers,"
      STDOUT.printf "breakdown rate,"
      STDOUT.printf "maintenance cycle,"
      # STDOUT.printf "repair time,"
      STDOUT.printf "p(std repair),"
      STDOUT.printf "p(std maint),"
      # STDOUT.printf "distribution,"
      STDOUT.printf "alpha,"
      STDOUT.printf "beta,"
      STDOUT.printf "run length"
      STDOUT.printf ",average availability,"
      STDOUT.printf "stddev availability,"
      STDOUT.printf "min,"
      STDOUT.printf "10th percentile,"
      STDOUT.printf "20th percentile,"
      STDOUT.printf "median\n"
      STDOUT.printf "%d,%d,%f,%d,%f,%f,%f,%f,%d", maxVehicles, maxMaintainers,
        breakdownRate, maintenanceCycleInDays, pStdRepair, pStdMaint,
        # distributionChoice,
        alpha, beta, haltTime / 8
    end

    if (outputType == 'f')
      STDOUT.printf "initial stock,"
      STDOUT.printf "#maintainers,"
      STDOUT.printf "breakdown rate,"
      STDOUT.printf "maintenance cycle,"
      STDOUT.printf "p(std repair),"
      STDOUT.printf "p(std maint),"
      STDOUT.printf "alpha,"
      STDOUT.printf "beta,"
      STDOUT.printf "run length"
      STDOUT.printf "%d,%d,%f,%d,%f,%f,%f,%f,%d", maxVehicles, maxMaintainers,
        breakdownRate, maintenanceCycleInDays, pStdRepair, pStdMaint,
        # distributionChoice,
        alpha, beta, haltTime / 8
      STDOUT.print "\n\nday,availability\n"
    end


    @breakdownDistribution = 
      RV::Exponential.new(rate: @breakdownRate, rng: rngs[0])

    @stdRepairDistribution = case @distributionChoice
    when 'e'
      RV::Exponential.new(rate: @repairRate, rng: rngs[1])
    when 'u'
      RV::Uniform.new(min: 0, max: 2.0 / @repairRate, rng: rngs[1])
    when 'w'
      RV::Weibull.new(rate: alpha, k: beta, rng: rngs[1])
    end

    @brokenRepairDistribution = case @distributionChoice
    when 'e'
      RV::Exponential.new(rate: @repairRate / 4.0, rng: rngs[2])
    when 'u'
      RV::Uniform.new(min: 0, max: 8.0 / @repairRate, rng: rngs[2])
    when 'w'
      RV::Weibull.new(rate: 4.0 * alpha, k: beta, rng: rngs[2])
    end

    @stdMaintenanceDistribution = RV::Uniform.new(min: 5.5/8, max: 6.5/8, rng: rngs[3])


  end

  # init method kickstarts a simplekit model.  State variables are
  # set to initial values, and some preliminary events get scheduled
  def init
    @dailyStats = QuickStats.new
    @results = []
    @numAvailableVehicles = @maxVehicles
    @numAvailableMechanics = @maxMaintainers
    @maintenanceQLength = 0
    @breakdownQLength = 0
    @numAvailableVehicles.times do |i|
      breakdownTime = @breakdownDistribution.next
      if (breakdownTime <= @maintenanceCycleInDays)
        schedule(:breakdown, breakdownTime)
      else
        schedule(:maintenance, @maintenanceCycleInDays)
      end
    end
    schedule(:shutDown, @haltTime)
    # STDOUT.puts "DailyAvailabilityReport"
    schedule(:dailyReport, 0.0)
  end

  # Event methods follow...

  def shutDown
    @results.sort!
    n = @results.length + 1
    if outputType == 's'
      STDOUT.printf ",%f,%f,%d,%d,%d,%d\n", @dailyStats.avg, @dailyStats.std_dev,
        @results[0], @results[0.1 * n], @results[0.2 * n], @results[0.5 * n]
    elsif outputType == 'f'
      STDOUT.printf "%d,%d\n", (model_time / 8.0).to_i, @numAvailableVehicles
    end
    halt
  end

  def dailyReport
    if model_time < @haltTime
      @results << @numAvailableVehicles
      @dailyStats.new_obs(@numAvailableVehicles)
      STDOUT.printf "%d,%d\n", (model_time / 8.0).to_i, @numAvailableVehicles if outputType == 'f'
    end
    schedule(:dailyReport, 8.0)
  end

  def breakdown
    @breakdownQLength += 1
    @numAvailableVehicles -= 1
    schedule(:beginBreakdownService, 0.0) if (@numAvailableMechanics > 0)
  end

  def maintenance
    @maintenanceQLength += 1
    @numAvailableVehicles -= 1
    schedule(:beginMaintenanceService, 0.0) if (@numAvailableMechanics > 0)
  end

  def beginMaintenanceService
    @maintenanceQLength -= 1
    @numAvailableMechanics -= 1
    if (@rngs[4].rand <= @pStdMaint)
      schedule(:endService, @stdMaintenanceDistribution.next)
    else
      schedule(:endService, @brokenRepairDistribution.next)
    end
  end

  def beginBreakdownService
    @breakdownQLength -= 1
    @numAvailableMechanics -= 1
    if (@rngs[5].rand <= @pStdRepair)
      schedule(:endService, @stdRepairDistribution.next)
    else
      schedule(:endService, @brokenRepairDistribution.next)
    end
  end

  def endService
    @numAvailableMechanics += 1
    @numAvailableVehicles += 1
    if (@maintenanceQLength > 0)
      schedule(:beginMaintenanceService, 0.0)
    else
      schedule(:beginBreakdownService, 0.0) if (@breakdownQLength > 0)
    end
    breakdownTime = @breakdownDistribution.next
    if (breakdownTime <= @maintenanceCycleInDays)
      schedule(:breakdown, breakdownTime)
    else
      schedule(:maintenance, @maintenanceCycleInDays)
    end
  end
end


def err_msg
  STDERR.puts
  warn "\nMust supply ten command-line arguments:\n"
  warn "\tInitial Stock level (int)"
  warn "\t#Maintenance personnel (int)"
  warn "\tNormal breakdown rate (double)"
  warn "\tMaintenance cycle length (int)"
  warn "\tProportion needing std repair"
  warn "\tProportion receiving std maintenance"
  # warn "\tMaintenance distribution choice [e|u|s|t]"
  warn "\tAlpha and Beta for Repair Distribution (double) (double)"
  warn "\tNumber of days to run (int)"
  warn "\tOutput type: f=full, s=summary (f/s)"
  # warn "\tOptionally, an integer can be provided for seeding the simulation"
  # warn "\nExample 1: ruby #{File.basename($0)} 50 2 0.01 90 0.8 0.95 0.2 1.5 50 s \n"
  # warn "\nExample 2: ruby #{File.basename($0)} 50 2 0.01 90 0.8 0.95 0.2 1.5 50 f 9876543\n"
  STDERR.puts
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [-h|--help] [filenames...[]"
  opts.on("-r", "--rnseeds seed1,seed2,seed3,seed4,seed5,seed6", Array, "Provide six comma-separated integer random number seeds") do |rnseeds|
    # options[:rnseeds] = rnseeds.map(&:to_i) # Convert each element to Integer
   pp rnseeds.map
   pp rnseeds
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

if ARGV.length != 10
  err_msg
else
  # Run model based on command-line arguments...
  maxVehicles = ARGV[0].to_i
  maxMaintainers = ARGV[1].to_i
  breakdownRate = ARGV[2].to_f
  maintenanceCycleInDays = ARGV[3].to_i
  pStdRepair = ARGV[4].to_f
  pStdMaint = ARGV[5].to_f
  # distributionChoice = ARGV[5].split('')[0].downcase
  alpha = ARGV[6].to_f
  beta = ARGV[7].to_f
  haltTimeInDays = ARGV[8].to_i
  outputType = ARGV[9].downcase
  FleetAvail.new(maxVehicles, maxMaintainers, breakdownRate, maintenanceCycleInDays,
                 pStdRepair, pStdMaint, 'w', alpha, beta, 8.0 * haltTimeInDays, outputType, options[:rngs]).run
end
