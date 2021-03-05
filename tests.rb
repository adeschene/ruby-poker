require_relative "table"
require_relative "players"
require_relative "deck"
require 'rspec/autorun'

describe Table do
  let(:table) { Table.new(2) }

  it "sets bet to 2" do
    expect(table.current_bet).to eq(2)
  end

  it "starts at preflop round" do
    expect(table.curr_round).to eq('preflop')
  end

  it "can set players" do
    expect(table).to respond_to(:players=)
  end
end

describe Card do
  let(:card) { Card.new(2,:H) }

  it "has a rank of 2" do
    expect(card.rank).to eq(2)
  end

  it "has a suit of hearts" do
    expect(card.suit).to eq(:H)
  end

  it "printable_card returns a string" do
    expect(card.printable_card).to be_instance_of(String)
  end
end

describe Deck do
  let(:deck) { Deck.new }

  it "has 52 cards" do
    expect(deck.cards.length).to eq(52)
  end

  it "has 4 suits" do
    expect(deck.cards.uniq{ |card| card.suit }.length).to eq(4)
  end

  it "has 13 of each suit" do
    expect(deck.cards.group_by{ |card| card.suit }.all?{ |k,v| v.length == 13 }).to eq(true)
  end

  it "has 4 of each rank" do
    expect(deck.cards.group_by{ |card| card.rank }.all?{ |k,v| v.length == 4 })
  end

  it "can be drawn from" do
    expect(deck).to respond_to(:draw_cards).with(1).arguments
  end

  it "can be shuffled" do
    expect(deck).to respond_to(:shuffle)
  end

  it "has different card order after shuffle" do
    expect{ deck.shuffle }.to change{ deck.cards }
  end

  it "returns a card when drawn from" do
    expect(deck.draw_cards(1)[0].is_a?(Card)).to eq(true)
  end

  it "has one less card after draw" do
    deck.draw_cards(1)
    expect(deck.cards.length).to eq(51)
  end
end
