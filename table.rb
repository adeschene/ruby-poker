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
    # Assign dealer coin to random player if first hand, otherwise player to dealer's left
    @has_dealer_coin = @has_dealer_coin.nil? ? @players.sample : next_player(@has_dealer_coin)
    # Forced small & big blind bets
    small_blind_better = next_player(@has_dealer_coin)
    big_blind_better   = next_player(small_blind_better)
    add_player_bet(small_blind_better, @current_bet / 2) # Player forced to bet $1
    add_player_bet(big_blind_better, @current_bet) # Player forced to bet $2
    # Set player to big blind better's left as first to play
    @active_player = next_player(big_blind_better)
    # Print intro text for user
    hand_intro(small_blind_better, big_blind_better)
  end

  # Print info about the starting state of the hand to the screen for the user
  def hand_intro(small, big)
    # A lambda that prints "You" instead of "Player #x" if player is the user
    decide_name = lambda {
      |player| player.is_a?(User) ? "You      "
        : "Player ##{player.player_id+1}"
    }
    print get_divider + "\n\n%30s\n\n%34s\n%34s\n%34s\n%34s\n" % [
      "HAND STARTING!",
      "Dealer coin: #{decide_name.call(@has_dealer_coin)}",
      "Small blind: #{decide_name.call(small)}",
      "Big blind: #{decide_name.call(big)}",
      "Under the gun: #{decide_name.call(@active_player)}"
    ]
    gets # Pause to let player see the starting state of the hand
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
