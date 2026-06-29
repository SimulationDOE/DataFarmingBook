#!/usr/bin/env ruby -w
require 'random_variates'

#notes: launch_to_land_distance is measured from gummy's position
#d1 is horizontal distance from base of books to gummy's position
#d2 is horizontal distance from gummy's position to base of catapult
G = 32.2 * 12

def gummylaunch(bookheight = 2.5, books = 2, position = 7,  v_mean = 50, v_cv = 0.05, color = 'green', n = 1)
  puts 'bookheight,books,position,color,v_mean,v_sd,d1,d2,d3,launch_to_land_distance'
  v_sd = v_mean * v_cv
  gauss = RV::Normal.new(mu: v_mean, sigma: v_sd )
  n.times do
    v = gauss.next # this is velocity if launched from position 11.0
    v *= (position - 2.0 / 9.0) # adjust velocity based on position
    v_sq = v * v
    theta = Math::PI / 2.0 - Math.asin(books * bookheight / 11.5)
    distance = v_sq * (
      1.0 + Math.sqrt(
        1.0 + (
          2.0 * G * books * bookheight * (position / 11.0) / (
            v_sq * Math.sin(theta)**2
          )
        )
      )
    ) * Math.sin(2.0 * theta) / (2.0 * G)
    book_to_launch = (11.5 - position) * Math.sin(theta)
    d2 = ( position) * Math.sin(theta)
    d3 = distance - d2
    puts "#{bookheight},#{books},#{position},#{color},#{"%0.2f" % v_mean},#{"%0.2f" % v_sd},#{"%0.2f" % book_to_launch},#{"%0.2f" % d2},#{"%0.2f" % d3},#{"%0.2f" % distance}"
  end
end

if ARGV.length == 6
  gummylaunch(ARGV[0].to_f, ARGV[1].to_i, ARGV[2].to_f, ARGV[3].to_f, ARGV[4].to_f, ARGV[5])
else
  STDERR.puts "\nMust supply six command-line arguments:\n"
  STDERR.puts "\tHeight of a single book (double)"
  STDERR.puts "\tNumber of books (integer)"
  STDERR.puts "\tPosition on ruler, in inches (double)"
  STDERR.puts "\tMean velocity (double)"
  STDERR.puts "\tCV velocity, between 0.01 and 0.1 (double)"
  STDERR.puts "\tGummy bear color (single word, such as blue or unknown)"
  STDERR.puts "\tExample:  \n"
  STDERR.puts "\t   ruby gummies.rb 2.5 2 7.0 50 0.1 green\n"
  #gummylaunch
end
