require 'yaml'
require 'erb'

module Hangman
  class Board
    @@miss_chance = 6

    def initialize(word)
      @word_arr = word.upcase.split('')
      @guess_arr = @word_arr.map { |_| nil }
      @miss_arr = []
    end

    def word_formatted
      @word_arr.join(' ')
    end

    def finish?
      @word_arr == @guess_arr
    end

    def remaining_miss_chance
      @@miss_chance - @miss_arr.length
    end

    def guess(char)
      if finish?
        raise CustomError.new('word was already guessed correctly')
      elsif remaining_miss_chance <= 0
        raise CustomError.new('mas was already hanged')
      end

      char = validate_guess(char)
      correct_positions = get_correct_positions(char)

      if correct_positions.empty?
        @miss_arr << char
      else
        correct_positions.each do |pos|
          @guess_arr[pos] = char
        end
      end
    end

    def to_s
      printed_guess = @guess_arr.map do |obj|
        obj.nil? ? '_' : obj
      end.join(' ')

      "#{File.read("txts/states/#{@miss_arr.length}.txt")}\n" +
      "Word: #{printed_guess}\n" +
      "Misses: #{@miss_arr.join(',')}"
    end

    private

    def get_correct_positions(char)
      correct_positions = []
      @word_arr.each_with_index do |obj, i|
        correct_positions << i if obj == char
      end
      correct_positions
    end

    def validate_guess(char)
      unless char.match? /^[a-z]$/i
        raise CustomError.new('a guess must be a single letter')
      end

      char.upcase!

      if @guess_arr.include?(char) || @miss_arr.include?(char)
        raise CustomError.new("a guess of #{char} was already made")
      end

      char
    end
  end

  class GameManager
    def initialize
      @save_manager = SaveManager.new
      @board = nil
      note_template = ERB.new(File.read('txts/note.erb'))
      puts note_template.result(binding)
      puts ''
    end

    def play
      unless @save_manager.get_saves.empty?
        print 'Would you like to load a save file? [Y/n] '
        response = gets.chomp.upcase
        if response == 'Y'
          puts ''
          @board = @save_manager.load_file
        end
        puts ''
      end

      @board = Board.new(GameManager.get_word) if @board.nil?

      until @board.finish? || @board.remaining_miss_chance <= 0
        begin
          # puts "[DEBUG] #{@board.word_formatted}"
          puts @board
          puts "Remaining  miss chances: #{@board.remaining_miss_chance}"
          print 'Make your guess: '
          respond_to_input(gets.chomp)
        rescue CustomError => e
          puts e
          puts 'Try again...'
          puts ''
          retry
        end

        puts ''
      end

      if @board.finish?
        puts @board
        puts 'Game Over! You Win!'
      elsif @board.remaining_miss_chance <= 0
        puts @board
        puts 'Game Over! You Lose!'
        puts "The word was #{@board.word_formatted}"
      end
    end

    private

    def respond_to_input(input)
      if input.match? /^-save/
        @save_manager.save_file(input, @board)
      else
        @board.guess(input)
      end
    end

    def self.get_word
      File.readlines('txts/5desk.txt').map do |line|
        line.chomp
      end.select do |line|
        (5..12).cover? line.length
      end.sample
    end
  end

  class SaveManager
    def initialize
      @dir = File.join(Dir.home, 'onagova_saves')
      Dir.mkdir(@dir) unless Dir.exist? @dir

      @dir = File.join(@dir, 'hangman')
      Dir.mkdir(@dir) unless Dir.exist? @dir
    end

    def save_file(command, obj)
      arg = SaveManager.get_arg(command)
      fname = File.join(@dir, "#{arg}.sv")
      File.open(fname, 'w') do |file|
        file.puts YAML.dump(obj)
      end
      puts "Saved to #{fname}"
    end

    def load_file
      saves = get_saves.sort
      load_index = nil

      loop do
        puts 'Please select a save file to load'
        saves.each_with_index do |fname, i|
          puts "#{i + 1}) #{File.basename(fname)}"
        end

        selection = gets.chomp
        match_data = selection.match /^\d+$/

        if match_data.nil?
          puts 'Selection must be a positive number'
          puts 'Try again...'
          puts ''
        elsif !(1..saves.length).cover?(selection.to_i)
          puts 'Selection out of bounds'
          puts 'Try again...'
          puts ''
        else
          load_index = match_data[0].to_i - 1
          break
        end
      end

      fname = saves[load_index]
      puts "Loaded from #{fname}"
      YAML.load(File.read(fname))
    end

    def get_saves
      svfiles = File.join(@dir, '*.sv')
      Dir.glob(svfiles)
    end

    private

    def self.get_arg(command)
      match_data = command.match /(-save) (.+)/
      if match_data.nil?
        raise CustomError.new('invalid save command')
      end
      match_data[2]
    end
  end

  class CustomError < StandardError
    def initialize(msg='blank error')
      super("[HANGMAN ERROR] #{msg}")
    end
  end
end

Hangman::GameManager.new.play
