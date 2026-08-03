"""Stochastic DES model of generic queues."""

# from functools import partial
# from sys import argv, stderr

# import numpy as np
from event_graph_sim import SimpleKit
from adaptive_stats import QuickStats
from collections import deque

class Customer:
    """Define customers with fixed transaction times and unique identifiers"""
    counter = 0

    def __init__(self, arrival_time=0.0, service_time=0.0):
        Customer.counter += 1
        self.__id = Customer.counter
        self.__arrival_time = arrival_time
        self.__service_time = service_time

    @property
    def arrival_time(self):
        return self.__arrival_time

    @property
    def service_time(self):
        return self.__service_time

    @property
    def id(self):
        return self.__id


class GGk(SimpleKit):
    """
    Demonstration model of an G/G/k queueing system.  There are k servers
    and both the arrival and service processes are generic distributions.
    """

    def __init__(
        self,
        arrival_dist,
        service_dist,
        max_servers,
        customers,
        lifo=False,
        truncate=0,
        stream=False
    ):
        """
        Constructor - initializes the model parameters.
        param: arrival_dist - The distribution with which customers arrive to the system.
        param: service_dist - The distribution with which individual servers serve.
        param: max_servers - The total number of servers in the system.
        param: customers - number of customers to process
        """

        # The following line is mandatory for all SimpleKit models
        SimpleKit.__init__(self)  # DO NOT REMOVE!!!!

        self.__max_servers = max_servers
        self.__max_customers = customers
        self.__arrival_dist = arrival_dist
        self.__service_dist = service_dist
        self.__LIFO = lifo
        self.__truncate = truncate
        self.__stream = stream

    def init(self):
        """
        Initialize the model state and schedule any necessary events.
        Note that this particular model will terminate after the specified
        number of customers have been through the queue.
        """
        self.__num_available_servers = self.__max_servers
        self.__deque = deque()
        self.__summary_stats = QuickStats()
        self.schedule(self.arrival, self.__arrival_dist())

    def arrival(self):
        """
        An arrival event increments the queue length, schedules the next
        arrival, and schedules a beginService event if a server is available.
        """
        self.__deque.append(
            Customer(arrival_time=self.model_time, service_time=self.__service_dist())
        )
        self.schedule(self.arrival, self.__arrival_dist())
        if self.__num_available_servers > 0:
            self.schedule(self.begin_service, 0.0)

    def begin_service(self):
        """
        Start service for the next eligible customer in line, removing that
        customer from the queue and utilizing one of the available servers.
        An endService will be scheduled.
        """
        customer = self.__deque.pop() if self.__LIFO else self.__deque.popleft()
        self.__num_available_servers -= 1
        delay_in_queue = self.model_time - customer.arrival_time
        if self.__stream:
            if customer.id == 1:
                print("")
            if customer.id > self.__truncate:
                print(f"{customer.id},{delay_in_queue:.4f}")
        if customer.id > self.__truncate:
            self.__summary_stats.new_obs(delay_in_queue)
        self.schedule(self.end_service, customer.service_time)

    def end_service(self):
        """
        Frees up an available server, and schedules a beginService if
        anybody is waiting in line.
        """
        self.__num_available_servers += 1
        if len(self.__deque) > 0:
            self.schedule(self.begin_service, 0.0)
        elif self.__summary_stats.n >= self.__max_customers:
            self.end_sim()

    def end_sim(self):
        """Print end-state summary stats and terminate the run"""
        if not self.__stream:
            avg = self.__summary_stats.avg
            n = self.__summary_stats.n
            loss = self.__summary_stats.ssd / n + avg * avg
            print(f",{avg},{loss},{n}")
        self.halt()
