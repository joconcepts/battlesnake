require 'sinatra'
require 'json'
require 'matrix'

set :port, ARGV[0] || 8080
set :bind, ARGV[1] || '0.0.0.0'

HEADS = %w[bendr dead fang pixel regular safe sand-worm shades smile tongue]
TAILS = %w[block-bum curled fat-rattle freckled pixel regular round-bum skinny small-rattle]
COLORS = %w[#000000 #ff0000 #00ff00 #0000ff]

class Game
  attr_accessor :game_id, :width, :height, :foods, :snakes, :me

  def initialize
  end

  def parse(data)
    self.game_id = data[:id]
    self.width = data[:width]
    self.height = data[:height]

    @foods = data[:food][:data].map do |food|
      Food.new(x: food[:x], y: food[:y])
    end

    @snakes = data[:snakes][:data].map do |snake|
      Snake.new(snake)
    end

    @me = @snakes.find do |snake|
      snake.id == data[:you][:id]
    end
  end

  def turn
    :up if next_step.nil?
    next_step.direction
  end

  private

  def nearest_food
    self.foods.sort_by do |fruit|
      self.me.head.distance(fruit)
    end.first
  end

  def possible_steps(start_x:, start_y:)
    [
      [start_x, start_y-1, :up],    #NORTH
      [start_x+1, start_y, :right], #EAST
      [start_x, start_y+1, :down],  #SOUTH
      [start_x-1, start_y, :left]   #WEST
    ].map do |p_x,p_y,dir|
      point = Point.new(x: p_x, y: p_y)
      point.direction = dir
      point
    end
  end

  def next_step(start_x: self.me.head.x, start_y: self.me.head.y)
    food = nearest_food
    possible = possible_steps(start_x: start_x, start_y: start_y)

    possible.reject! do |point|
      x, y = point.x, point.y
      x < 0 || x > self.width - 1 || y < 0 || y > self.height - 1
    end

    possible.reject! do |point|
      step2 = possible_steps(start_x: point.x, start_y: point.y)
      collision_check_snakes(point) || step2.reject do |point_2|
        collision_check_snakes(point_2)
      end.none?
    end
    possible.sort_by do |point|
      point.distance(food)
    end.first
  end

  def collision_check_snakes(point)
    self.snakes.select do |snake|
      snake.body.select do |body_point|
        body_point == point
      end.any?
    end.any?
  end
end

class Point
  attr_accessor :direction
  attr_reader :x, :y, :vector

  def initialize(x:, y:)
    @x, @y = x, y
    @vector = Vector[@x,@y]
  end

  def distance(other)
    (other.vector - self.vector).magnitude
  end

  def ==(other)
    self.vector == other.vector
  end

  def print
    puts "x: #{@x} - y: #{@y} -> #{self.direction}"
  end
end

class Food < Point ; end

class Snake
  attr_accessor :health, :id, :length, :body

  def initialize(args)
    @health, @id, @length = args[:health], args[:id], args[:length]
    @body = args[:body][:data].map do |point|
      Point.new(x: point[:x], y: point[:y])
    end
  end

  def head
    self.body.first
  end
end

game = Game.new

post '/start' do
  content_type :json
  {
    "color": COLORS.sample,
    "secondary_color": COLORS.sample,
    "head_url": "http://placecage.com/c/100/100",
    "taunt": "jonas",
    "head_type": HEADS.sample,
    "tail_type": TAILS.sample
  }.to_json
end

post '/move' do
  content_type :json
  data = JSON.parse(request.body.read, symbolize_names: true)
  game.parse(data)
  {
    move: p(game.turn)
  }.to_json
end
