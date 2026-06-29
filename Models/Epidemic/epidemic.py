"""Simple stochastic DES model of Pandemic infection propagation."""

from functools import partial
from sys import argv, stderr

import numpy as np
from event_graph_sim import SimpleKit


class Pandemic(SimpleKit):
    def __init__(
        self,
        initial_population,
        initial_infected,
        avg_new_per_infected,
        intervention_day,
        trans_ratio_reduction,
    ):
        """Constructor - initializes the model parameters. Units are days."""

        # The following line is mandatory for all SimpleKit models
        SimpleKit.__init__(self)  # DO NOT REMOVE!!!!

        self.initial_population = initial_population
        self.initial_infected = initial_infected
        self.intervention_day = intervention_day

        rng = np.random.default_rng()

        self.mean_contacts = 10.0
        self.friend_pool_dist = partial(rng.poisson, lam=self.mean_contacts)
        min_gestation = 2.0
        max_gestation = 21.0
        mode_gestation = 7.0
        self.contagious_dist = partial(
            rng.triangular, left=min_gestation, mode=mode_gestation, right=max_gestation
        )
        self.startup_dist = partial(rng.uniform, low=min_gestation, high=max_gestation)
        min_removal_t = 6.0
        max_removal_t = 24.0
        mode_removal_t = 16.0
        self.removal_dist = partial(
            rng.triangular, left=min_removal_t, mode=mode_removal_t, right=max_removal_t
        )
        avg_duration = (min_removal_t + max_removal_t + mode_removal_t) / 3.0
        rate = float(avg_new_per_infected) / avg_duration / self.mean_contacts
        intervention_rate = (1.0 - trans_ratio_reduction) * rate
        # NumPy exponential scale is inverse of rate
        self.infection_dist = partial(rng.exponential, scale=1.0 / rate)
        self.intervention_dist = partial(rng.exponential, scale=1.0 / intervention_rate)
        # self.report_threshold = 10_000

    def init(self):
        """Initialize the model state and schedule any necessary events."""
        self.susceptibles = self.initial_population - self.initial_infected
        self.total_infected = self.initial_infected
        self.contagious_pool = 0
        self.currently_infected = self.initial_infected
        for _ in range(self.initial_infected):
            self.schedule(self.infectious, self.startup_dist())
        self.schedule(self.intervention, self.intervention_day)

    def exposed(self):
        """
        Exposed event:
            increments the number of infecteds,
            reduces the number # of susceptibles, and
            schedules when this patient will become contagious.
        """
        self.susceptibles -= 1
        self.total_infected += 1
        self.currently_infected += 1
        if self.susceptibles == 0:
            self.schedule(self.end_sim, 0)
        else:
            self.schedule(self.infectious, self.contagious_dist())

    def infectious(self):
        """
        Upon becoming infectious we generate a patient's pool of potential exposures.

          For each potential, generate when the exposure would
          occur and schedule the new exposure unless the current patient
          becomes non-infectious before that time.
        """
        self.contagious_pool += 1
        contact_rate = (
            float(self.mean_contacts)
            * float(self.susceptibles)
            / float(self.initial_population)
        )
        if contact_rate > 0.0:
            # self.friend_pool_dist.rate = contact_rate
            num_potentials = min(
                self.friend_pool_dist(lam=contact_rate), self.susceptibles
            )
            duration = self.removal_dist()
            self.schedule(self.removal, duration)
            # Could also generate secondary and tertiary pools with different pool
            # sizes and rates of infection, but since that would be a superposition
            # of Poissons it can be accomodated via changing the rate above.
            for _ in range(num_potentials):
                time_to_infection = self.infection_dist()
                if time_to_infection <= duration:
                    self.schedule(self.exposed, time_to_infection)
        else:
            self.schedule(self.end_sim, 0)

    # Patient is removed from the active pool due to recovery or death.
    def removal(self):
        self.contagious_pool -= 1
        self.currently_infected -= 1
        if 0 == self.currently_infected:
            self.schedule(self.end_sim, 0)

    def intervention(self):
        """Intervention changes the infection rate"""
        self.infection_dist = self.intervention_dist

    def end_sim(self):
        """A report and halt mechanism."""
        # print("%.2f,%d,%d\n", self.model_time, self.total_infected, self.susceptibles)
        print(f"{self.model_time:.2f},{self.total_infected},{self.susceptibles}")
        self.halt()


if "__main__" == __name__:

    def error_msg():
        print("\n  Correct usage:\n", file=stderr)
        print(
            f"      python {argv[0]} <# replications> <population size> \\",
            file=stderr,
        )
        print(
            "\t<initial # infected> <per capita avg transmission ratio> \\",
            file=stderr,
        )
        print("\t<intervention start day> \\", file=stderr)
        print("\t<proportion reduction in transmission ratio>\n", file=stderr)
        print("  Example:\n", file=stderr)
        print(f"      python {argv[0]} 10 100_000 1 1.4 100 0.2\n", file=stderr)
        exit()

    replications = 10
    population = 100_000
    initial_infected = 1
    transmission_ratio = 1.4
    intervention_day = 100
    trans_ratio_reduction = 0.2
    match len(argv):
        case 7:
            # Instantiate an epidemic model with a particular parameterization and run it.
            # print(argv)   # debug - confirm argument values
            replications = int(argv[1])
            population = int(argv[2])
            initial_infected = int(argv[3])
            transmission_ratio = float(argv[4])
            intervention_day = int(argv[5])
            trans_ratio_reduction = float(argv[6])
        case 2:
            if "--default" != argv[1]:
                error_msg()
        case _:
            error_msg()

    print(
        "Population,Initial Infected,Transmission Ratio,"
        + "Intervention Start Day,Transmission Ratio Reduction,"
        + "Duration,Infected,Uninfected"
    )
    for _ in range(replications):
        print(
            f"{population},{initial_infected},{transmission_ratio},"
            + f"{intervention_day},{trans_ratio_reduction},",
            end="",
        )
        Pandemic(
            population,
            initial_infected,
            transmission_ratio,
            intervention_day,
            trans_ratio_reduction,
        ).run()
