#!/usr/bin/env python

import argparse
from math import ceil, floor
from os.path import basename

import numpy as np

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
  [0.0585,0.4015,0.6812,0.7444,0.7692,0.8200,0.8649,0.8997,0.9281,0.9281,0.9300]]

# The following is for if you want non-binomial variances for robust analysis
#
# rng = np.random.default_rng()
# UNIF = rng.uniform(low=-1.0, high=1.0)

if "__main__" == __name__:
    program_name = basename(__file__)

    def check_0_1(value):
        try:
            f_value = float(value)
        except ValueError:
            raise argparse.ArgumentTypeError(f"'{value}' is not a valid number.")

        # Define your boundaries here
        if f_value < 0.0 or f_value > 1.0:
            raise argparse.ArgumentTypeError(f"{value} is out of bounds. Must be between 0.0 and 1.0.")
        return f_value

    def check_positive_int(value):
        try:
            i_value = int(value)
        except ValueError:
            raise argparse.ArgumentTypeError(f"'{value}' is not a valid integer.")

        # Define your boundaries here
        if i_value < 1:
            raise argparse.ArgumentTypeError(f"{value} is out of bounds. Must be strictly positive.")
        return i_value

    parser = argparse.ArgumentParser(
        prog=program_name,
        description="Capture the Flag demo model",
        epilog = "\nIf no positional arguments are provided, you will be prompted interactively to input their values.\n"

    )
    parser.add_argument(
        "speed",
        nargs='?',
        default=None,
        help="average normalized team speed (0 = min, 1 = max)",
        type=check_0_1
    )
    parser.add_argument(
        "stealth",
        nargs='?',
        default=None,
        help="average normalized team stealth (0 = min, 1 = max)",
        type=check_0_1
    )
    parser.add_argument(
        "n_games",
        nargs='?',
        default=None,
        help="number of games to run",
        type=check_positive_int
    )
    parser.add_argument(
        "-s", "--stream",
        help="stream output (default=off)",
        action='store_true'
    )
    parser.add_argument(
        "-g", "--ground_truth",
        help="report ground truth prob_win (default=no)",
        action='store_true'
    )
    parser.add_argument(
        "-r", "--rnseed",
        default=None,
        help="random number seed (optional)",
        type=int
    )
    options = parser.parse_args()

    if None == options.speed:
        speed = check_0_1(input("Enter speed between 0 and 1: "))
    else:
        speed = options.speed
    if None == options.stealth:
        stealth = check_0_1(input("Enter stealth between 0 and 1: "))
    else:
        stealth = options.stealth
    if None == options.n_games:
        n_games = check_positive_int(input("Enter number of games to play: "))
    else:
        n_games = options.n_games

    rng = np.random.default_rng(options.rnseed)

    # Find the surrounding grid points for each factor.
    speed_low = floor(speed * 10)
    speed_up = ceil(speed * 10)
    stealth_low = floor(stealth * 10)
    stealth_up = ceil(stealth * 10)
    x1 = speed * 10
    x2 = stealth * 10

    # Perform interpolation as needed on the grid.
    if (speed_up > speed_low):
      if (stealth_up > stealth_low):
        y1 = Ygrid[speed_low][stealth_low] + ((x1 - speed_low)/float(speed_up - speed_low)) * (Ygrid[speed_up][stealth_low] - Ygrid[speed_low][stealth_low])
        y2 = Ygrid[speed_low][stealth_up] + ((x1 - speed_low)/float(speed_up - speed_low)) * (Ygrid[speed_up][stealth_up] - Ygrid[speed_low][stealth_up])
        y = y1 + ((x2 - stealth_low)/float(stealth_up - stealth_low)) * (y2 - y1)
      else:
        y = Ygrid[speed_low][stealth_low] + ((x1 - speed_low)/float(speed_up - speed_low)) * (Ygrid[speed_up][stealth_low] - Ygrid[speed_low][stealth_low])
    else:
      if (stealth_up > stealth_low):
        y = Ygrid[speed_low][stealth_low] + ((x2 - stealth_low)/float(stealth_up - stealth_low)) * (Ygrid[speed_low][stealth_up] - Ygrid[speed_low][stealth_low])
      else:
        y = Ygrid[speed_low][stealth_low]

    # Uncomment the following line to modify for explicit variance modification.
    # If so, don't forget to uncomment UNIF segment up above (lines 24-25) and comment line 140.
    #
    # prob_win = y+(UNIF.next * (((1.0 - speed) * 10) + 1) / 200.0) # This is ruby version

    # Use the line below for straight Binomial outcomes.
    prob_win = y

    results = rng.binomial(p=prob_win, n=1, size=n_games)

    truth = f"{prob_win:.4f}," if options.ground_truth else ''
    if options.stream:
      print(f"speed,stealth,{'prob_win,' if options.ground_truth else ''}outcome")
      for result in results:
        print(f"{speed},{stealth},{truth}{'lose' if 0 == result else 'win'}")
    else:
      result = results.sum()
      print(f"speed,stealth,n_games,{'prob_win,' if options.ground_truth else ''}games_won")
      print(f"{speed},{stealth},{n_games},{truth}{result}")
