class Game
  attr_reader :character_number
  attr_reader :turn_direction
  attr_reader :attack_direction
  attr_reader :characters
  attr_reader :chronicles

  def initialize(character_number, witches_percentage: 0, turn_direction: -1, attack_direction: -1)
    raise ArgumentError.new("this game is not fun - character_number must be greater than 1") if character_number <= 1
    @character_number = character_number.to_i
    # validate and store directions
    @turn_direction = valid_direction(turn_direction)
    @attack_direction = valid_direction(attack_direction)
    # validate witches percentage
    @witches_percentage = witches_percentage.to_f.clamp(0, 100)
    # generate a list of characters
    @characters = new_character_list(
      Witch => @witches_percentage / 100.0,
      Knight => (100 - @witches_percentage) / 100.0,
    )
    # grant the right of move to the first characte
    @current_acting_character_index = alive_character_ids.first
    # initialize the moves counter
    @chronicles = []
  end

  def finished?
    # is there more than one character left alive?
    alive_character_ids.size == 1
  end

  def play!
    while !finished?
      next_move!
    end
    winner
  end

  def winner
    raise "The game needs to be played first" unless finished?
    @characters[alive_character_ids.last]
  end

  def current_acting_character
    @characters[@current_acting_character_index]
  end

  private

  def valid_direction(direction)
    return 1 if direction > 0
    return -1 if direction < 0
    return 0
  end

  def new_character_list(desired_ratio)
    desired_ratio.reject!{|_, value| value == 0}
    tally = desired_ratio.transform_values { |_| 0}

    Array.new(@character_number) do |i|
      next_character_class = character_class_from_ratio(desired_ratio, tally)
      tally[next_character_class] += 1
      next_character_class.new(tally[next_character_class])
    end
  end

  def character_class_from_ratio(desired_ratio, current_tally)
    sum = hash_total(current_tally)
    current_ratio = tally_to_ratio(current_tally)
    pending_ratio = desired_ratio.merge(current_ratio) { |_, old_value, new_value| old_value - new_value }
    pending_ratio.max_by{|_, value| value}.first
  end

  def tally_to_ratio(tally)
    sum = hash_total(tally)
    if sum > 0
      return tally.transform_values { |value| value.to_f / sum }
    else
      return tally.transform_values { |_| 0 }
    end
  end

  def hash_total(hash)
    hash.values.sum
  end

  def next_move!
    attacker = current_acting_character
    target = closest_alive_character(@attack_direction)

    # roll the dice
    dice = rand(1..6)

    chronicles_entry = {
      current_acting_character_index: @current_acting_character_index,
      current_acting_character: attacker.name,
      text: ["#{current_acting_character.name} is active"],
      dice: dice,
      target: target.name,
    }

    # do the damage
    damage_part = make_damage(target, dice)
    chronicles_entry.merge! damage_part

    chronicles_entry[:text] << "#{attacker.name} attacks #{target.name} with #{chronicles_entry[:damage]} damage"
    if chronicles_entry[:target_dead]
      chronicles_entry[:text] << "#{target.name} is dead"
    else
      chronicles_entry[:text] << "#{target.name} has #{target.energy} energy left now"
    end

    puts chronicles_entry[:text].join("\n")
    @chronicles << chronicles_entry

    advance_turn!

    chronicles_entry
  end

  def make_damage(target, amount)
    scroll_entry_part = {}
    attacker = current_acting_character
    scroll_entry_part[:damage] = current_acting_character.make_damage(target, amount)
    if target.dead?
      scroll_entry_part[:target_dead] = true
    end

    scroll_entry_part
  end

  def advance_turn!
    if @turn_direction == 0
      @current_acting_character_index = alive_character_ids.excluding(@current_acting_character_index).sample
    else
      # advance the turn to the closest alive character
      @current_acting_character_index = closest_alive_character_id(@turn_direction)
    end
  end

  def alive_character_ids
    @characters.enum_for(:each_with_index).select{|character, index| character.alive?}.map{|character, id| id}
  end

  def closest_alive_character_id(direction = 1)
    direction = random_direction if direction == 0
    # from the alive character ids choose the next or previous
    new_id_index = (alive_character_ids.find_index(@current_acting_character_index) + direction) % alive_character_ids.size
    # that was an index in array of indexes, too meta
    alive_character_ids[new_id_index]
  end

  # returns 1 or -1 at random
  def random_direction
    (rand(0..1) * 2) - 1
  end

  def closest_alive_character(direction)
    @characters[closest_alive_character_id(direction)]
  end
end
