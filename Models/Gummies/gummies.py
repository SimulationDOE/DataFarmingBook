import numpy as np
import argparse
import math
from os.path import basename

#notes: launch_to_land_distance is measured from gummy's position
#d1 is horizontal distance from base of books to gummy's position
#d2 is horizontal distance from gummy's position to base of catapult
G = 32.2 * 12

def gummylaunch(
    book_height = 2.5,
    book_qty = 2,
    position = 7,
    v_mean = 50,
    v_cv = 0.05,
    color = 'green',
    reps = 1
):
    print('book_height,book_qty,position,color,v_mean,v_sd,d1,d2,d3,launch_to_land_distance')
    v_sd = v_mean * v_cv
    rng = np.random.default_rng()
    for _ in range(reps):
        v = rng.normal(loc=v_mean, scale=v_sd)
        v *= (position - 2.0 / 9.0) # adjust velocity based on position
        v_sq = v * v
        theta = math.pi / 2.0 - math.asin(book_qty * book_height / 11.5)
        distance = v_sq * (
            1.0 + math.sqrt(
                1.0 + (
                    2.0 * G * book_qty * book_height * (position / 11.0) / (
                        v_sq * math.sin(theta)**2
                    )
                )
            )
        ) * math.sin(2.0 * theta) / (2.0 * G)
        book_to_launch = (11.5 - position) * math.sin(theta)
        d2 = position * math.sin(theta)
        d3 = distance - d2
        print(
            f"{book_height},{book_qty},{position},{color}," +
            f"{v_mean:.2f},{v_sd:.2f},{book_to_launch:.2f}," +
            f"{d2:.2f},{d3:.2f},{distance:.2f}"
        )

def range_checker(value):
    try:
        f_value = float(value)
    except ValueError:
        raise argparse.ArgumentTypeError(f"'{value}' is not a valid number.")

    # Define your boundaries here
    if f_value < 0.01 or f_value > 0.1:
        raise argparse.ArgumentTypeError(f"{value} is out of bounds. Must be between 0.01 and 0.10.")
    return f_value

if "__main__" == __name__:
    program_name = basename(__file__)

    parser = argparse.ArgumentParser(
        prog=program_name,
        description="calculate gummie bear trajectories based on setup conditions",
        epilog=f"Example: python {program_name} 2.5 2 7.0 50 0.1 green"
    )
    parser.add_argument("book_height", help="Height of a single book", type=float)
    parser.add_argument("book_qty", help="Number of books", type=int)
    parser.add_argument("position", help="Position on ruler (inches)", type=float)
    parser.add_argument("v_mean", help="Mean velocity", type=float)
    parser.add_argument("v_cv", help="CV velocity", type=range_checker)
    parser.add_argument("color", help="Proportion receiving std maintenance")
    parser.add_argument("-r", "--reps", default=1, type=int,
        help="Number of replications - optional, default=1")
    args = parser.parse_args()

    gummylaunch(
        args.book_height,
        args.book_qty,
        args.position,
        args.v_mean,
        args.v_cv,
        args.color,
        args.reps
    )
