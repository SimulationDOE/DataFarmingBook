#!/usr/bin/env python3

"""Program to parse arguments to control runs of queueing models"""

# Group 1: Standard library imports (built into Python)
import argparse
import math
from functools import partial
from os.path import basename
from sys import argv

# Group 2: Third-party imports (installed via pip/poetry)
import numpy as np

# Group 3: Local application/library-specific imports
import GenericQueue

TRI_CONST = 9.0 + math.sqrt(45.0)

def ShiftedExponential(rng, mu=1.0, offset=0.0):
    return offset + rng.exponential(scale=mu)

def pick_distribution(rng, name='exp', mu=1.0):
    match name:
        case 'exp':
            return partial(rng.exponential, scale=mu)
        case 'sexp':
            exp_mean = mu / math.sqrt(3.0)
            exp_offset = mu - exp_mean
            return partial(
                ShiftedExponential, rng, mu=exp_mean, offset=exp_offset
            )
        case 'tri':
            tri_mode = 6.0 * mu / TRI_CONST
            tri_max = 3.0 * mu - tri_mode
            return partial(rng.triangular, left=0, mode=tri_mode, right=tri_max)
        case 'unif':
            return partial(rng.uniform, low=0, high=2.0 * mu)
        case _:
            print("Theoretically this cannot happen!")  # Wildcard / Default case


def range_checker(value):
    try:
        f_value = float(value)
    except ValueError:
        raise argparse.ArgumentTypeError(f"'{value}' is not a valid number.")

    # Define your boundaries here
    if f_value <= 0.0 or f_value >= 1.0:
        raise argparse.ArgumentTypeError(f"{value} is out of bounds. Must be between 0.0 and 1.0.")
    return f_value

if "__main__" == __name__:
    program_name = basename(__file__)
    inputs = f"{','.join(map(str, argv[1:8]))}"

    parser = argparse.ArgumentParser(
        prog=program_name,
        description="Run control for a G/G/k queueing system",
        # epilog=f"Example: python {program_name} 2.5 2 7.0 50 0.1 green"
    )
    parser.add_argument("nominal_customers", help="Target number of customers to process", type=int)
    parser.add_argument("rho", help="traffic intensity", type=range_checker)
    parser.add_argument("arrival_rate", help="Arrival process rate", type=float)
    parser.add_argument(
        "arrival_dist",
        help="Interarrival time distribution",
        choices=['exp','sexp','tri','unif']
    )
    parser.add_argument("max_servers", help="Maximum number of servers", type=int)
    parser.add_argument(
        "service_dist",
        help="Service time distribution",
        choices=['exp','sexp','tri','unif']
    )
    parser.add_argument(
        "q_discipline",
        help="Is this a FIFO or LIFO queue?",
        choices=['fifo','lifo']
    )
    parser.add_argument(
        "reps",
        nargs='?',
        default=1,
        help="Number of replications to run",
        type=int
    )
    parser.add_argument(
        "-t", "--truncate",
        default=0,
        help="Amount to truncate for system warmup",
        type=int
    )
    parser.add_argument(
        "-s", "--stream",
        help="Toggle streaming of full output",
        action='store_true'
    )
    parser.add_argument(
        "-r", "--rnseeds",
        nargs=2, default=[],
        help="Optional pair of seed values for arrival and service processes",
        type=int
    )
    args = parser.parse_args()

    s1 = s2 = None
    if len(args.rnseeds) == 2:
        print(f"Random number seeds provided: {args.rnseeds}")
        s1 = args.rnseeds[0]
        s2 = args.rnseeds[1]

    rng1 = np.random.default_rng(s1)
    rng2 = np.random.default_rng(s2)

    arr_mean = 1.0 / args.arrival_rate
    svc_mean = args.rho * arr_mean * args.max_servers

    arv = pick_distribution(rng1, name=args.arrival_dist, mu=arr_mean)
    svc = pick_distribution(rng2, name=args.service_dist, mu=svc_mean)

    print(
        'nominal#customers,rho,lambda,arrival_dist,' +
        '#servers,service_dist,queue_discipline',
        end=''
    )

    if args.stream:
        print(inputs)
    else:
        print(',avg_delay,avg_loss,#customers')

    for rep in range(args.reps):
        if args.stream:
            if args.reps > 1:
                print(f"\nrep_{rep + 1}")
            else:
                print()
            print('customer_id,delay', end='')
        else:
            print(inputs, end='')
        # Instantiate a GGk object and run it.
        GenericQueue.GGk(
            arrival_dist = arv,
            service_dist=svc,
            max_servers=args.max_servers,
            customers=args.nominal_customers,
            lifo=(args.q_discipline=="lifo"),
            truncate=args.truncate,
            stream=args.stream
        ).run()
