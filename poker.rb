# Represents a standard playing card; can give rank, suit, and pretty string
class Card
  attr_reader :rank, :suit

  def initialize(rank, suit)
    @rank = rank # 2..14
    @suit = suit # :H, :C, :S, :D
  end

  def printable_card
    # Colored hearts/diamonds red, clubs/spades black
    printable_suits = {
      H: "\e[5;31m♥ \e[0m",
      C: "\e[5;30m♣ \e[0m",
      S: "\e[5;30m♠ \e[0m",
      D: "\e[5;31m♦ \e[0m"
    }
    # Print A instead of 14, K instead of 13, etc.
    def printable_ranks(rank)
      case rank
      when 2..10 then rank
      when 11 then 'J'
      when 12 then 'Q'
      when 13 then 'K'
      when 14 then 'A'
      else puts "ERROR: trouble in printable_ranks"
      end
    end
    # Return string for card with a white background, to be printed by caller
    "\e[5;30;47m%2s%1s\e[0m" % [printable_ranks(@rank), printable_suits[@suit]]
  end
end


# Represents a standard 52 deck of cards; can shuffle itself, draw cards
class Deck
  def initialize
    # For each rank, create a card of each suit (makes standard 52 card deck)
    @cards = [2,3,4,5,6,7,8,9,10,11,12,13,14].map {
      |r| [Card.new(r,:H),Card.new(r,:C),Card.new(r,:S),Card.new(r,:D)]
    }.flatten(1) # [[1,2],[3,4]] => [1,2,3,4]
  end

  # Draw an amount of cards from the top of the deck
  def draw_cards(amount)
    @cards.pop(amount)
  end

  # Shuffle the deck 3 times
  def shuffle
    @cards = @cards.shuffle.shuffle.shuffle
  end
end


# Represents a poker table; has players, community cards, a deck, and a pot
class Table
  attr_reader :curr_round, :current_bet; attr_writer :players

  def initialize(min_bet)
    @rounds          = ['preflop','flop','turn','river','showdown']
    @curr_round      = 'preflop' # Keeps track of round of game
    @community_cards = [] # Cards that are shared between all the players
    @players         = [] # Players sitting at the table
    @has_dealer_coin = nil # Keeps track of player rotation
    @active_player   = nil # Player who's turn is currently happening
    @deck            = Deck.new # The deck for the current hand
    @pot             = 0 # The sum of all bets made during this hand
    @minimum_bet     = min_bet # Minimum bet for active_player
    @current_bet     = min_bet # Starts at minimum_bet (changes often)
  end


  # GAME LOOP METHOD---

  def game_loop
    setup_preflop # Initial setup for first round of game
    left_of_dealer = next_player(@has_dealer_coin) # Locate player to left of dealer
    early_win      = false # If all but one player folded, they win by default
    while @curr_round != 'showdown' # Same loop until final round
      round_over = false # Loop control for rounds
      deal_cards # Deal any cards that should be dealt for this round
      # All players play from left of big blind to dealer for first round
      while round_over == false
        unless @active_player.folded # Skip folded players
          print_table # Print new table state for user
          # Prompt user to take an action if player is user, or make bot player take an action
          @active_player.is_a?(User) ? @active_player.prompt_user : @active_player.determine_action
          gets # Pause after every player action, so user can control the pace
        end
        if @players.one? { |player| player.folded == false } # If early win, break out of loop
          early_win = true
          break
        end
        @active_player = next_player(@active_player) # Next player's turn
        # End round when we make it all the way around the table
        round_over = true if @active_player == left_of_dealer
      end
      break if early_win
      next_round # Move on to next round
    end
    early_win ? handle_early_win : handle_showdown
    handle_hand_over
  end


  # ROUND HANDLING METHODS---

  # Special setup for the first round of a hand
  def setup_preflop
    # Shuffle the deck
    @deck.shuffle
    # Assign dealer coin
    @has_dealer_coin = @has_dealer_coin.nil? ? @players[0] : next_player(@has_dealer_coin)
    # Forced small & big blind bets
    small_blind_better = next_player(@has_dealer_coin)
    big_blind_better   = next_player(small_blind_better)
    add_player_bet(small_blind_better, @current_bet / 2) # Player forced to bet $1
    add_player_bet(big_blind_better, @current_bet) # Player forced to bet $2
    # Set player to big blind better's left as first to play
    @active_player = next_player(big_blind_better)
  end

  # Increments current round, resets current bet, resets player bets
  def next_round
    @curr_round  = @rounds[@rounds.index(@curr_round) + 1]
    @current_bet = 0
    @players.each { |player| player.bet = 0 unless player.folded }
  end

  # The final round of a hand, players in game show their hands and player with best hand wins
  def handle_showdown
    print get_divider + "\n\n%27s\n" % "SHOWDOWN" # Divider for readibility
    # Get all players that haven't folded
    players_in_hand = @players.filter { |player| !player.folded }
    showdown_hands  = players_in_hand.map { |player| get_best_hand(player) }
    # Show all player's hands to the user
    showdown_hands.each.with_index {
      |score__hand,i| print "\n\n%168s" % "Player ##{players_in_hand[i].player_id+1}: [ #{show_hand(score__hand[1])} ]"
    }
    final_standing  = {} # Holds final scores/hands of each player
    # Output: { score: [player,hand], score: [player,hand], ... }
    showdown_hands.each.with_index do |v,i|
      final_standing.has_key?(v.first) ?
        final_standing[v.first].push([players_in_hand[i], v.last])
        : final_standing[v.first] = [[players_in_hand[i], v.last]]
    end
    # Get best score among all players still in the game
    best_score = final_standing.keys.min
    # Check for ties; if best_score is shared, break the tie
    if final_standing[best_score].count == 1 # No tie
      winning_player = final_standing[best_score][0][0]
    else
      tie_winner     = tie_breaker(best_score,final_standing[best_score])
      winning_player = players_in_hand.select { |player| player.player_id == tie_winner }.first
    end
    unless winning_player.nil? # winning_player only nil if tie occurred and the pot was split
      print winning_player.is_a?(User) ? "\n\n\n%33s\n" % "You won the hand!!!"
        : "\n\n\n%36s\n" % "Player ##{winning_player.player_id+1} wins the hand!!!"
      winning_player.chips += @pot # Give winner the chips they won
    end
    @pot = 0
  end


  # SPECIAL CASE HANDLING METHODS---

  #
  def handle_early_win
    winning_player = @players.find { |player| player.folded == false }
    print get_divider + (winning_player.is_a?(User) ? "\n\n%33s\n" % "You won by default!"
      : "\n\n%36s\n" % "Player ##{winning_player.player_id+1} wins by default!")
    winning_player.chips += @pot # Give winner the chips they won
    @pot = 0
  end

  # I/O: winning score : [[player_id,hand],...] => player_id or nil
  def tie_breaker(score,tied_players)
    ids   = tied_players.map { |player__hand| player__hand.first.player_id } # Get each players id
    hands = tied_players.map { |player__hand| player__hand.last } # Get each players hand
    # Determine what kind of hand it is and react accordingly
    case score
    when 1,2,16..183,185..194 # Royal/straight flushes, full houses, or straights
      split_pot(ids) # Ties of these hands can't be broken, split up the pot
    when 3..15,184,195..377 # Quads, flushes, trips, two pairs, and one pairs
      kicker_scores = hands.map { |hand| hand.collect { |card| card.rank**card.rank }.sum }
      kickers_max   = kicker_scores.max
      if kicker_scores.one?(kickers_max) # Tie broken, one winner decided
        return ids[kicker_scores.find_index(kickers_max)]
      else # Tie couldn't be broken, split up the pot
        winners = ids.keep_if.with_index { |id,i| kicker_scores[i] == kickers_max }
        split_pot(winners)
      end
    else puts "ERROR: Trouble in tie_breaker" # Shouldn't be here
    end
  end

  # Split the pot up evenly between 'tied' players
  def split_pot(tied)
    player_amt = tied.length # Num of players pot is being split between
    # Rounds up to nearest evenly divisible int from @pot and splits it into even portions
    split_amt  = (@pot + player_amt - (@pot % player_amt)) / player_amt
    # Give each player their share (table pot zeroed out in handle_showdown)
    @players.filter {
      |player| tied.include?(player.player_id)
    }.each {
      |player| player.chips += split_amt
    }
    print "\n\n\n%30s\n\n%30s\n\n" % [
      "It's a TIE!!!",
      "%-60s" % "Players #{tied.collect { |id| "##{id+1}" }.join(", ")} tied and will split the pot!"
    ]
  end


  # PLAYER HANDLING METHODS---

  # Add a player's bet amount to the pot
  def add_player_bet(player, amount)
    # Check if player has enough chips to place requested bet
    verified_amount = player.chips < amount ? player.chips : amount
    @pot += verified_amount
    player.chips -= verified_amount
    player.bet = verified_amount
    @current_bet = verified_amount if verified_amount > @current_bet
  end

  # I/O: Active player at the table => Player to the given player's left
  def next_player(curr_player)
    curr_player_id = curr_player.player_id
    @players[curr_player_id == 5 ? 0 : curr_player_id + 1]
  end


  # HAND CHECKING METHODS---

  # I/O: The player who's best hand will be found => [score, hand]
  def get_best_hand(player)
    best_hand = [378] # Starts 1 lower than lowest rank

    get_possible_hands(player).each do |hand|
      # Check for royal flush, straight flush, and standard flush
      case check_hand_flushes(hand)
      when 'royal flush' then best_hand = [1, hand] # Best possible hand
      when 'straight flush' then best_hand = compare_hands(2,best_hand,hand) # 2nd best possible hand
      when 'flush' then best_hand = compare_hands(184,best_hand,hand) # 5th best, ranked fairly low
      end
      # Check for straights, get back best possible straight
      straight_rank = check_hand_straights(hand) # 6th best hand
      best_hand = [straight_rank, hand] unless straight_rank == -1 or best_hand.first <= straight_rank
      # Check for quads, full houses, trips, two pairs, and one pairs
      match_score = check_hand_matches(hand) # 3rd, 4th, 7th, 8th, 9th best hands
      if match_score != -1 then best_hand = compare_hands(match_score,best_hand,hand)
      else # Get high card, as that is all the hand has to offer
        high_card_rank = check_high_card(hand) # 10th best hand
        best_hand = compare_hands(high_card_rank,best_hand,hand)
      end
    end
    return best_hand # [score, hand]
  end

  # Compare the hand score of 'new_hand' to that of 'curr_hand';
  # Replace 'curr_hand' with 'new_hand' if it's better;
  # If they have the same score, compare the kicker cards;
  # Higher kicker cards == better hand; always choose better kickers
  def compare_hands(score,curr_hand,new_hand)
    if curr_hand.first > score then return [score, new_hand] # new_hand has a better base score
    elsif curr_hand.first == score # curr_hand and new_hand have same base score
      # Compare the overall "highness" of the cards of two hands
      # [2♥,2♦,4♦,4♠,13♣] : [8♣,2♥,2♦,4♦,4♠] => [4,4,16,16,169] : [64,4,4,16,16] => 209 : 104 => 1
      kick_comp = new_hand.collect { |card| card.rank**2 }.sum <=> curr_hand.last.collect { |card| card.rank**2 }.sum
      return [score, new_hand] if kick_comp == 1 # new_hand has better kickers
    end
    curr_hand # If new_hand score wasn't better, return curr_hand
  end

  # I/O: a player's hand => a string from ['none','royal flush','straight flush']
  def check_hand_flushes(hand)
    # Flush checking is far less complex, so do it first
    if hand.uniq { |card| card.suit } == 1 # All one suit means hand is a flush
      case check_hand_straight(hand)
      when -1 then return 'flush' # Hand wasn't royal or straight, but still a flush
      when 1 then return 'royal flush' # A royal flush! 1 in 649,740!
      when 2..10 then return 'straight flush' # A straight flush! 1 in 72,192!
      else puts "ERROR: Trouble in check_hand_special_flush"
      end
    end
  end

  # I/O: a player's hand => -1 (no straight) or 1..10 (rank of straight, 1 being best)
  def check_hand_straights(hand)
    # [4♦,2♥,13♣,3♦,6♠] => [2♥,3♦,4♦,6♠,13♣]
    sorted_hand = hand.sort_by { |card| card.rank }
    # [2♥,3♦,4♦,6♠,13♣] => [2,3,4,6,13]
    hand_ranks  = sorted_hand.map { |card| card.rank }

    # Check the hand for all possible straights (Brute force for now)
    case hand_ranks
    when [2,3,4,5,14] then return 194 # Worst straight (wheel)
    when [2,3,4,5,6] then return 193 # 9th best straight
    when [3,4,5,6,7] then return 192 # 8th best straight
    when [4,5,6,7,8] then return 191 # 7th best straight
    when [5,6,7,8,9] then return 190 # 6th best straight
    when [6,7,8,9,10] then return 189 # 5th best straight
    when [7,8,9,10,11] then return 188 # 4th best straight
    when [8,9,10,11,12] then return 187 # 3rd best straight
    when [9,10,11,12,13] then return 186 # 2nd best straight
    when [10,11,12,13,14] then return 185 # Best straight (broadway)
    else return -1 # No straights
    end
  end

  # Check a hand for 4 of a kind, full house, three of a kind, two pair, and pair
  # OUTPUT: rank of match -1 (no matching cards), 3..15 (quads), 16..183 (full houses),
  #   195..207 (trips), 208..351 (two pair), or 352..364 (one pair)
  def check_hand_matches(hand)
    # Check for four of a kind (quads)
    quads = get_rank_grouped_hand(hand, 4)
    return (quads.keys.first - 17).abs unless quads.empty? # Quads
    # Check for three of a kind (trips)
    trips = get_rank_grouped_hand(hand, 3)
    unless trips.empty?
      # Check for a further pair (full house)
      pair_check = get_rank_grouped_hand(hand.filter{ |card| card.rank != trips.keys.first }, 2)
      # If the other two cards are a pair, return full house, otherwise just return trips
      if pair_check.empty?
        return (trips.keys.first - 209).abs
      else
        trips_rank = trips.keys.first # Below is a scoring equation I'd have a hard time explaining, but it works
        full_house_score = ((trips_rank * 13) + (pair_check.keys.first - (trips_rank == 14 ? 13 : 14)) - 198).abs
        return full_house_score # Full house
      end
    end
    # Check for pairs
    pairs = get_rank_grouped_hand(hand, 2)
    case pairs.count
    when 2 # Two pair
      pair1_rank = pairs.keys[0]
      pair2_rank = pairs.keys[1] # Below is another inexplicable scoring equation
      two_pair_score = ((pair1_rank * 12) + pair2_rank - 389).abs
      return two_pair_score
    when 1 then return (pairs.keys.first - 366).abs # One pair
    when 0 then return -1 # No matched rank cards in hand
    else puts "ERROR: Trouble in check_hand_dups"
    end
  end

  # Check for lowest scoring hand
  # OUTPUT: A hand score 365..377 (365 is best)
  def check_high_card(hand)
    return (hand.sort_by { |card| card.rank }.last.rank - 379).abs
  end


  # UTILITY METHODS---

  # Display the table with color-coded player info, bets, etc.
  def print_table
    player_info = @players.map do |player|
      [ # User number is green; Opponent numbers are red; Active player bg is dark red; Folded player number replaced with 'F'
        "\e[1;#{player == @active_player ? 41 : 40};#{player.is_a?(User) ? 32 : 31}m#{player.folded ? " F " : " " + (player.player_id+1).to_s + " "}\e[0m",
        player.bet # Total amount player has bet this hand; --- if player folded
      ]
    end
    # Determines padding around community cards area of the table
    comm_card_padding = case @curr_round when 'preflop'; "24" when 'flop'; "11" when 'turn'; "6" else "1" end
    player_bet_area   = "\e[4;34;43m%3s\e[0m" # Bet area has a yellow bg

    table_string  = get_divider + "\n\n%26s\n" % "POT: $#{@pot}"
    #            1                  2
    table_string += "\n%28s%35s\n" % [player_info[0].first, player_info[1].first]
    #    [[[[[[[  6][[[[[[[]]]]]]][  2]]]]]]]
    table_string += "%69s" % "/[[[[#{player_bet_area}][[[[[[[[]]]]]]]][#{player_bet_area}]]]]\\\n" % [player_info[0].last, player_info[1].last]
    table_string += "%42s" % (("-" * 36) + "\n")
    #  6 [ 12][----COMMUNITY CARDS-----][---] F
    table_string += "%18s(#{player_bet_area}]|\e[4;30;42m %1s\e[4;30;42m%-#{comm_card_padding}s\e[0m|[#{player_bet_area})%15s\n" % [
      player_info[5].first,
      player_info[5].last,
      show_hand(@community_cards, "\e[4;30;42m \e[0m"),
      " ",
      player_info[2].last,
      player_info[2].first
    ]
    table_string += "%42s" % (("-" * 36) + "\n")
    #    [[[[[[[---][[[[[[[]]]]]]][  9]]]]]]]
    table_string += "%69s" % "\\[[[[#{player_bet_area}][[[[[[[[]]]]]]]][#{player_bet_area}]]]]/\n" % [player_info[4].last, player_info[3].last]
    #            F                  4
    table_string += "%28s%35s\n\n" % [player_info[4].first, player_info[3].first]
    print table_string # Display the complete table to the user
  end

  #
  def deal_cards
    case @curr_round
    when 'preflop' # Deal 2 cards to each player (their hole cards)
      @players.each { |player| player.hole_cards.concat(@deck.draw_cards(2)) }
    when 'flop'
      burned_card = @deck.draw_cards(1) # Burn one card
      @community_cards.concat(@deck.draw_cards(3)) # Three cards drawn for flop
    when 'turn','river'
      burned_card = @deck.draw_cards(1) # Burn one card
      @community_cards.concat(@deck.draw_cards(1)) # One card drawn for turn/river
    end # No cards dealt during showdown
  end

  # Reset the pot, cards, and deck for this table at the end of each hand
  def reset_table
    @curr_round      = 'preflop'
    @community_cards = []
    @deck            = Deck.new
    @pot             = 0
    @current_bet     = @minimum_bet
    @players.each { |player| player.reset_self }
  end

  # After a hand is done, allows player to start another hand if they have chips left
  def handle_hand_over
    user = @players.select { |player| player.is_a?(User) }.first # Get user
    # If user has no chips, their game is over; end game
    if user.chips <= 0
      return print "\n\n%38s\n" % "You're out of chips! Game over..."
    end
    # Prompt user if they want to play another hand
    print get_divider + "\n\n%32s" % "Play again? (y/n): "
    case gets.chomp
    when "y", "yes"
      reset_table # Reset table, deck, etc.
      game_loop # Start another hand
    when "n", "no"
      print get_divider + "\n\n%32s\n\n%34s\n\n\n%33s\n\n" % [
        "%-17s" % "Total Chips: $#{user.chips}",
        "%-19s" % "Net Winnings: #{user.chips - 50 < 0 ? "-$#{(user.chips - 50).abs}" : "$#{user.chips - 50}" }",
        "Thanks for playing!"
      ]
    else handle_hand_over # Re-prompt if user gives invalid input
    end
  end

  # Get all possible 5-card hands that can be made with hole cards and available community cards
  # OUTPUT: an array of 5-card hands => [[10♦,2♥,3♦,8♥,5♦],[2♥,13♦,4♣,5♦,6♣],...]
  def get_possible_hands(player)
    (player.hole_cards + @community_cards).combination(5).to_a
  end

  # INPUT: the hand to examine, the target amount to search for (4, 3, or 2)
  # OUTPUT: a hash containing matches => { 2=>[2♦,2♥], 10=>[10♥,10♣] }
  def get_rank_grouped_hand(hand, target)
    hand.sort {
      |a,b| b.rank <=> a.rank # [3♦,7♣,4♦,4♥,3♥] => [7♣,4♦,4♥,3♦,3♥]
    }.group_by {
      |card| card.rank # [7♣,4♦,4♥,3♦,3♥] => {7=>[7♣], 4=>[4♦,4♥], 3=>[3♦,3♥]}
    }.filter {
      |k,v| v.count == target # If 'target' == 2: {7=>[7♣], 4=>[4♦,4♥], 3=>[3♦,3♥]} => {4=>[4♦,4♥], 3=>[3♦,3♥]}
    }
  end

  # Show a player's hand to the user
  def show_hand(hand, sep=" ")
    hand.map { |card| card.printable_card }.join(sep)
  end

  # A visual divider for info written to screen
  def get_divider
    "\n" + ("-" * 46)
  end
end


# Represents a player at a poker table; has a table, hole cards, chips, and an id
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


# EXPLANATION OF GAME PHASES:

  # Preflop
    # 1. choose players for dealer, small blind, and big blind; force bets
    # 2. players (starting from left of BB) either call, fold, or raise
    # 3. Once dealer plays, move on to next round

  # Flop
    # Burn one card
    # 3 cards are dealt face up on table

  # Postflop
    # Starting from dealer's  left, players either call, check, raise, fold
    # Players cannot check after a bet has been made

  # Turn
    # Burn one card
    # One more card is dealt face down on the table

  # Postturn
    # Starting from dealer's  left, players either call, check, raise, fold
    # Players cannot check after a bet has been made

  # River
    # Burn one card
    # One final card is dealt face down on the table

  # Postriver
    # Starting from dealer's  left, players either call, check, raise, fold
    # Players cannot check after a bet has been made

  # Showdown
    # All players show their hand
    # Player with best hand wins the pot

# MISCELLANEOUS RULES

  # Player number is green
  # Opponent numbers are dark red
  # Active player bg is red
  # Dealer coin starts at player 1 (user)
  # Rotate to left after each game
  # If dealer is 1, 2 == small blind, 3 == big blind
  # All 3 shift to the left after each game

  # Minimum bet: $2
  #   - small blind: $1
  #   - big blind: $2
  # Call: $2


# Table / Player setup
game_table = Table.new(2) # Set minimum bet for table
game_table.players = [
  User.new(0, game_table),
  Bot.new(1, game_table),
  Bot.new(2, game_table),
  Bot.new(3, game_table),
  Bot.new(4, game_table),
  Bot.new(5, game_table)
]

# Game loop call
game_table.game_loop
