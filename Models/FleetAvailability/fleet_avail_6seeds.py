#!/usr/bin/env python

from functools import partial
import numpy as np
from event_graph_sim import SimpleKit
from adaptive_stats import QuickStats
from argparse import ArgumentParser

# utility to produce 2-arg weibulls
def weib2(gen, alpha, beta):
    return gen(alpha) / beta


# Demonstration model of Fleet Availability

class FleetAvail(SimpleKit):

    def __init__(
        self,
        maxVehicles,
        maxMaintainers,
        breakdownRate,
        maintenanceCycleInDays,
        pStdRepair,
        pStdMaint,
        distributionChoice,
        alpha,
        beta,
        haltTime,
        outputType,
        rngs
    ):
        # The following line is mandatory for all SimpleKit models
        SimpleKit.__init__(self)  # DO NOT REMOVE!!!!
        # super().__init__()

        # model state
        self.dailyStats = QuickStats()
        self.results = []

        # model parameters
        self.maxVehicles = maxVehicles
        self.maxMaintainers = maxMaintainers
        self.breakdownRate = breakdownRate
        self.maintenanceCycleInDays = maintenanceCycleInDays
        self.pStdRepair = pStdRepair
        self.pStdMaint = pStdMaint
        self.repairRate = 1.0   # 1.0 / meanRepairTime
        self.distributionChoice = distributionChoice
        self.haltTime = haltTime
        self.outputType = outputType
        self.rngs = rngs

        self.numAvailableVehicles = self.maxVehicles
        self.numAvailableMechanics = self.maxMaintainers
        self.maintenanceQLength = 0
        self.breakdownQLength = 0

        match(outputType):
            case 's':
                labels = "initial stock,"
                labels += "#maintainers,"
                labels += "breakdown rate,"
                labels += "maintenance cycle,"
                # labels += "repair time,"
                labels += "p(std repair),"
                labels += "p(std maint),"
                # labels += "distribution,"
                labels += "alpha,"
                labels += "beta,"
                labels += "run length"
                labels += ",average availability,"
                labels += "stddev availability,"
                labels += "min,"
                labels += "10th percentile,"
                labels += "20th percentile,"
                labels += "median"
                print(labels)
                print(
                    f"{maxVehicles},{maxMaintainers},{breakdownRate},"
                    + f"{maintenanceCycleInDays},{pStdRepair},{pStdMaint},"
                    + f"{alpha},{beta},{haltTime / 8},",
                    end=""
                )
            case 'f':
                labels = "initial stock,"
                labels += "#maintainers,"
                labels += "breakdown rate,"
                labels += "maintenance cycle,"
                labels += "p(std repair),"
                labels += "p(std maint),"
                labels += "alpha,"
                labels += "beta,"
                labels += "run length"
                print(labels)
                print(
                    f"{maxVehicles},{maxMaintainers},{breakdownRate},"
                    + f"{maintenanceCycleInDays},{pStdRepair},{pStdMaint},"
                    + f"{alpha},{beta},{haltTime / 8}"
                )
                print("\n\nday,availability")

        # RV::Exponential.new(rate: self.breakdownRate, rng: rngs[0])
        self.breakdownDistribution = partial(rngs[0].exponential, scale=1.0/self.breakdownRate)

        # self.stdRepairDistribution = case self.distributionChoice
        match self.distributionChoice:
            case 'e':
                # self.stdRepairDistribution = RV::Exponential.new(rate: self.repairRate, rng: rngs[1])
                self.stdRepairDistribution = partial(rngs[1].exponential, scale=1.0/self.repairRate)
            case 'u':
                # self.stdRepairDistribution = RV::Uniform.new(min: 0, max: 2.0 / self.repairRate, rng: rngs[1])
                self.stdRepairDistribution = partial(rngs[1].uniform, low=0, high=2.0/self.repairRate)
            case 'w':
                # self.stdRepairDistribution = RV::Weibull.new(rate: alpha, k: beta, rng: rngs[1])
                self.stdRepairDistribution = partial(weib2, gen=rngs[1].weibull, alpha=alpha, beta=beta)

        match self.distributionChoice:
            case 'e':
                # self.brokenRepairDistribution = RV::Exponential.new(rate: self.repairRate / 4.0, rng: rngs[2])
                self.brokenRepairDistribution = partial(rngs[2].exponential, scale=4.0/self.repairRate)
            case 'u':
                # self.brokenRepairDistribution = RV::Uniform.new(min: 0, max: 8.0 / self.repairRate, rng: rngs[2])
                self.brokenRepairDistribution = partial(rngs[2].uniform, low=0, high=8.0/self.repairRate)
            case 'w':
                # self.brokenRepairDistribution = RV::Weibull.new(rate: 4.0 * alpha, k: beta, rng: rngs[2])
                self.brokenRepairDistribution = partial(weib2, gen=rngs[2].weibull, alpha=4.0*alpha, beta=beta)

        # self.stdMaintenanceDistribution = RV::Uniform.new(min: 5.5/8, max: 6.5/8, rng: rngs[3])
        self.stdMaintenanceDistribution = partial(rngs[3].uniform, low=5.5/8.0, high=6.5/8.0)


    # Event methods follow...

    def shutDown(self):
        self.results.sort()
        n = len(self.results) + 1
        if self.outputType == 's':
            print(
                f"{self.dailyStats.avg},{self.dailyStats.std_dev},"
                + f"{self.results[0]},{self.results[n // 10]},"
                + f"{self.results[n // 5]},{self.results[n // 2]}"
            )
        elif self.outputType == 'f':
            print(f"{int(self.model_time / 8.0)},{self.numAvailableVehicles}")
        self.halt()

    def dailyReport(self):
        if self.model_time < self.haltTime:
            self.results.append(self.numAvailableVehicles)
            self.dailyStats.new_obs(self.numAvailableVehicles)
            if self.outputType == 'f':
                print(f"{int(self.model_time / 8.0)},{self.numAvailableVehicles}")
        self.schedule(self.dailyReport, 8.0)

    def breakdown(self):
        self.breakdownQLength += 1
        self.numAvailableVehicles -= 1
        if (self.numAvailableMechanics > 0):
            self.schedule(self.beginBreakdownService, 0.0)

    def maintenance(self):
        self.maintenanceQLength += 1
        self.numAvailableVehicles -= 1
        if (self.numAvailableMechanics > 0):
            self.schedule(self.beginMaintenanceService, 0.0)

    def beginMaintenanceService(self):
        self.maintenanceQLength -= 1
        self.numAvailableMechanics -= 1
        if (self.rngs[4].random() <= self.pStdMaint):
            self.schedule(self.endService, self.stdMaintenanceDistribution())
        else:
            self.schedule(self.endService, self.brokenRepairDistribution())

    def beginBreakdownService(self):
        self.breakdownQLength -= 1
        self.numAvailableMechanics -= 1
        if (self.rngs[5].random() <= self.pStdRepair):
            self.schedule(self.endService, self.stdRepairDistribution())
        else:
            self.schedule(self.endService, self.brokenRepairDistribution())

    def endService(self):
        self.numAvailableMechanics += 1
        self.numAvailableVehicles += 1
        if (self.maintenanceQLength > 0):
            self.schedule(self.beginMaintenanceService, 0.0)
        elif (self.breakdownQLength > 0):
            self.schedule(self.beginBreakdownService, 0.0)
        breakdownTime = self.breakdownDistribution()
        if (breakdownTime <= self.maintenanceCycleInDays):
            self.schedule(self.breakdown, breakdownTime)
        else:
            self.schedule(self.maintenance, self.maintenanceCycleInDays)


    # init method kickstarts a simplekit model.  State variables are
    # set to initial values, and some preliminary events get scheduled
    def init(self):
        self.numAvailableVehicles = self.maxVehicles
        self.numAvailableMechanics = self.maxMaintainers
        self.maintenanceQLength = 0
        self.breakdownQLength = 0
        # self.numAvailableVehicles.times do |i|
        for _ in range(self.numAvailableVehicles):
            breakdownTime = self.breakdownDistribution()
            if (breakdownTime <= self.maintenanceCycleInDays):
                self.schedule(self.breakdown, breakdownTime)
            else:
                self.schedule(self.maintenance, self.maintenanceCycleInDays)
        self.schedule(self.shutDown, self.haltTime)
        # STDOUT.puts "DailyAvailabilityReport"
        self.schedule(self.dailyReport, 0.0)


if "__main__" == __name__:
    parser = ArgumentParser()
    parser.add_argument("maxVehicles", help="Initial Stock level", type=int)
    parser.add_argument("maxMaintainers", help="#Maintenance personnel", type=int)
    parser.add_argument("breakdownRate", help="Normal breakdown rate", type=float)
    parser.add_argument("maintenanceCycleDays", help="Maintenance cycle length (days)", type=int)
    parser.add_argument("pStdRepair", help="Proportion needing std repair", type=float)
    parser.add_argument("pStdMaint", help="Proportion receiving std maintenance", type=float)
    parser.add_argument("alpha", help="Alpha for Weibull Repair Distribution", type=float)
    parser.add_argument("beta", help="Beta for Weibull Repair Distribution", type=float)
    parser.add_argument("haltTimeInDays", help="Number of days to run", type=int)
    parser.add_argument("outputType", help="Output type: f=full, s=summary", choices=['f','s'])
    parser.add_argument("-r", "--rnseeds", nargs=6, default=[], help="Optional list of 6 seed values", type=int)
    args = parser.parse_args()

    # options = {}
    # OptionParser.new do |opts|
    #   opts.banner = "Usage: #{$PROGRAM_NAME} [-h|--help] [filenames...[]"
    #   opts.on("-r", "--rnseeds seed1,seed2,seed3,seed4,seed5,seed6", Array, "Provide six comma-separated integer random number seeds") do |rnseeds|
    #     # options[:rnseeds] = rnseeds.map(&:to_i) # Convert each element to Integer
    #    pp rnseeds.map
    #    pp rnseeds
    #     options[:rngs] = rnseeds.map do |seed|
    #       Xoroshiro::Random.new(seed: seed.to_i) # Convert each element to integer to seed rng
    #     end
    #   end
    # end.parse!

    # Check if we have exactly six integers

    # if options[:rngs].nil?:
    #     options[:rngs] = Array.new(6) { Xoroshiro::Random.new }
    # elif options[:rngs].size != 6:
    #     puts "Please provide six comma-separated integers using the -r option,"
    #     puts "or leave out the -r option to use system-generated seeds"
    #     sys.exit()

    # if ARGV.length != 10:
    #   err_msg
    # else:
    #   # Run model based on command-line arguments...
    #   maxVehicles = ARGV[0].to_i
    #   maxMaintainers = ARGV[1].to_i
    #   breakdownRate = ARGV[2].to_f
    #   maintenanceCycleInDays = ARGV[3].to_i
    #   pStdRepair = ARGV[4].to_f
    #   pStdMaint = ARGV[5].to_f
    #   # distributionChoice = ARGV[5].split('')[0].downcase
    #   alpha = ARGV[6].to_f
    #   beta = ARGV[7].to_f
    #   haltTimeInDays = ARGV[8].to_i
    #   outputType = ARGV[9].downcase

    if len(args.rnseeds) == 0:
        rngs = [np.random.default_rng() for _ in range(6)]
    else:
        rngs = [np.random.default_rng(seed=s) for s in args.rnseeds]

    # print(rngs)
    # exit()

    FleetAvail(
          args.maxVehicles,
          args.maxMaintainers,
          args.breakdownRate,
          args.maintenanceCycleDays,
          args.pStdRepair,
          args.pStdMaint,
          'w',
          args.alpha,
          args.beta,
          args.haltTimeInDays * 8.0,
          args.outputType,
          rngs
    ).run()
