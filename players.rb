# Represents a player at a poker table; has a table, hole cards, chips, an id
class Player
  attr_accessor :hole_cards, :chips, :bet; attr_reader :folded, :player_id

  def initialize(id, table)
    @table       = table # The table this player is sitting at
    @player_id   = id # Identifier for the player
    @hole_cards  = [] # Two cards that the player is dealt
    @folded      = false # Whether player has folded this hand
    @chips       = 50 # Number of chips the player has
    @bet         = 0 # The player's chips in to this round
  end

  # Fold; throw away player cards and withdraw from play for current hand
  def fold_hand
    @folded = true
    (padding,pronoun) = self.is_a?(User) ? [28,"You"] : [32,"Player ##{player_id+1}"]
    puts "\n%#{padding}s\n" % "#{pronoun} folded."
    @bet = "---"
  end

  # Check; pass on betting for this round; only allowed if no bets have been placed this round
  def check_bet
    (padding,pronoun) = self.is_a?(User) ? [29,"You"] : [32,"Player ##{player_id+1}"]
    puts "\n%#{padding}s\n" % "#{pronoun} checked."
  end

  # Call; match the current bet so far for this round
  def call_bet
    call_amount = @table.current_bet
    (padding,pronoun) = self.is_a?(User) ? [30,"You"] : [33,"Player ##{player_id+1}"]
    puts "\n%#{padding}s\n" % "#{pronoun} called $#{call_amount}."
    @table.add_player_bet(self, call_amount)
  end

  # Raise; match the current bet and then some; for Bot class only;
  def raise_bet(amount)
    puts "\n%33s\n" % "Player ##{player_id+1} raised $#{amount}."
    @table.add_player_bet(self, @table.current_bet + amount)
  end

  # Called at end of a hand; resets bet and folded, keeps chips
  def reset_self
    @hole_cards = []
    @folded     = false
    @bet        = 0
  end
end


# A User is a Player, with a little extra
class User < Player
  # During users turn, prompts for an action, verifies it, executes it
  def prompt_user
    # Prompt user for bets, fold, check
    print "\n%86s" % "Hole Cards: [ #{@table.show_hand(@hole_cards)} ]" +
          "\n\n%16s" % "%-12s" % "Chips: $#{@chips}" +
          "\n\n\n%42s" % "What will you do? (#{@table.current_bet == 0 ? "check" : "call"}/raise/fold): "
    case gets.chomp
    when 'check' then @table.current_bet == 0 ? check_bet : prompt_user
    when 'call','c' then @table.current_bet == 0 ? check_bet : call_bet
    when 'raise','r' then raise_bet
    when 'fold','f' then fold_hand
    else prompt_user # Invalid input, restart the prompt
    end
  end

  # Raise action for User class; interacts with User using prompts
  def raise_bet
    print "\n\n%31s" % "Amount to raise: $"
    amount = gets.chomp.to_i
    # Don't allow player to bet less than $1 or more than they have
    prompt_user if amount < 1 or amount > @chips
    puts "\n%21s\n" % "%-15s" % "You raised $#{amount}."
    @table.add_player_bet(self, @table.current_bet + amount)
  end
end


# A Bot is a Player, with a little extra
class Bot < Player
  # Decide what action to take during each turn
  def determine_action # preflop is based solely off of hole cards
    if @table.curr_round == 'preflop'
      case rank_starting_hand
      when -1 then fold_hand # Didn't get playable hand
      when 1 then raise_bet(16)
      when 2..5 then raise_bet(8)
      when 6..10 then raise_bet(6)
      when 11..15 then raise_bet(4)
      when 16..20 then raise_bet(2)
      when 21 then @table.current_bet == 0 ? check_bet : call_bet
      else puts "ERROR: #{rank_starting_hand.nil?}"
      end
    else # Decide what to do during all other betting rounds
      case @table.get_best_hand(self).first
      when 1..2 then raise_bet(@chips) # Royal or straight flush; All-in
      when 3..15 then raise_bet(8) # Four of a kind (quads)
      when 16..183 then raise_bet(6) # Full house
      when 184 then raise_bet(2) # Standard flush
      # Standard straight, three of a kind (trips), two pair or one pair
      when 185..364 then @table.current_bet == 0 ? check_bet : call_bet
      when 365..378 then fold_hand # Hand not worth playing; fold
      else puts "ERROR: #{@table.get_best_hand(self).first}"
      end
    end
  end

  # Ranks the starting hand (hole cards) of the AI players
  def rank_starting_hand
    sorted_hand = @hole_cards.sort_by { |card| card.rank } # [4,2] => [2,4]

    # Shorthand variables for two cards in hand
    (first,second) = [sorted_hand[0],sorted_hand[1]]

    suited    = first.suit == second.suit # True if cards have same suit
    paired    = first.rank == second.rank # True if cards have same rank
    connected = first.rank + 1 == second.rank # True if cards have consecutive ranks

    # Check for playable hands and return their rank
    # (Some of these checks aren't necessary but are included for readibility)
    case first.rank
    when 8 then return 14 if paired # Pocket Eights
    when 9 then return 9 if paired # Pocket Nines
    when 10
      return 6 if paired # Pocket Tens
      return 20 if second.rank == 12 and suited # Queen-Ten Suited
      return 16 if second.rank == 13 and suited # King-Ten Suited
      return 12 if second.rank == 14 and suited # Ace-Ten Suited
    when 11
      return 4 if paired # Pocket Jacks
      return 17 if second.rank == 12 and suited # Queen-Jack Suited
      return 15 if second.rank == 13 and suited # King-Jack Suited
      if second.rank == 14
        return suited ? 10 : 18 # Ace-Jack Suited/Offsuit
      end
    when 12
      return 3 if paired # Pocket Queens
      if second.rank == 13
        return suited ? 11 : 19 # King-Queen Suited/Offsuit
      elsif second.rank == 14
        return suited ? 8 : 13 # Ace-Queen Suited/Offsuit
      end
    when 13
      return 2 if paired # Pocket Kings
      if second.rank == 14
        return suited ? 5 : 7 # Ace-King Suited/Offsuit
      end
    when 14 then return 1 if paired # Pocket Aces
    end
    # Still played if the hand is suited, paired, or connected, otherwise not played
    return (suited or paired or connected) ? 21 : -1
  end
end
