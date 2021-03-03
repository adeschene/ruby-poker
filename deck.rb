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
