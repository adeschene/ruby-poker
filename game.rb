require_relative "table"
require_relative "players"
require_relative "deck"

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
