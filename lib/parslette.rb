require "parslette/version"
require "pp"

module Parslette
  def self.id; lambda { |x| x } end

  def self.force; lambda { |v| v.class == Proc ? v.call : v } end

  def self.foldl; lambda { |f| lambda { |zero| lambda { |t| t.reduce(zero) { |accumulator, a| f.call(accumulator).call(a) } } } } end

  def self.key; lambda { |h| h.keys.first } end

  def self.value; lambda { |h| h[key.call(h)] } end

  def self.satisfy; lambda { |predicate| { :progress => lambda { |a|
    predicate.call(a) ?
      { :success => a } :
      { :failure => a.inspect + " did not satisfy the predicate" } } } } end

  def self.fmap; lambda { |f| lambda { |parser|
    case key.call(parser)
    when :success; { :success => f.call(parser[:success]) }
    when :failure; parser
    when :progress; { :progress => lambda { |a| fmap.call(f).call(parser[:progress].call(a)) } }
    end } } end

  def self.unit; { :success => nil } end

  def self.pure; lambda { |v| { :success => v } } end

  def self.pair; lambda { |a| lambda { |b|
    case key.call(a)
    when :success; fmap.call(lambda { |bval| [a[:success], bval] }).call(b)
    when :failure; a
    when :progress; { :progress => lambda { |x| pair.call(a[:progress].call(x)).call(b) } }
    end } } end

  def self.seqr; lambda { |a| lambda { |b| fmap.call(lambda { |p| p[1] }).call(pair.call(a).call(b)) } } end

  def self.apply; lambda { |a| lambda { |b| fmap.call(lambda { |p| p[0].call(p[1]) }).call(pair.call(a).call(b)) } } end

  def self.alt; lambda { |a| lambda { |b|
    case key.call(a)
    when :success; a
    when :failure; b
    when :progress; { :progress => lambda { |x| alt.call(a[:progress].call(x)).call(feed.call(b).call(x)) } }
    end } } end

  # TODO inline feed since success and failure stop consuming
  def self.feed; lambda { |p| lambda { |c|
    case key.call(p)
    when :success; p
    when :failure; p
    when :progress; p[:progress].call(c)
    end } } end

  def self.parse; lambda { |parser| lambda { |input|
    foldl.call(feed).call(parser).call(input + [nil]) } } end

  def self.parse_string; lambda { |parser| lambda { |string|
    r = parse.call(parser).call(string.split(""))
    case key.call(r)
    when :success; r
    when :failure; r
    when :progress; { :failure => "Expected more input" }
    end } } end

  def self.eof; satisfy.call(lambda { |a| a.nil? }) end

  def self.char; lambda { |c| satisfy.call(lambda { |a| a == c }) } end

  def self.match; lambda { |re| satisfy.call(lambda { |a| a =~ re }) } end

  def self.string; lambda { |s|
    foldl
      .call(lambda { |acc| lambda { |c| fmap.call(lambda { |v| v[0] + v[1] }).call(pair.call(acc).call(c)) } })
      .call(fmap.call(lambda { |_| "" }).call(unit))
      .call(s.split("").map &char) } end

  def self.many; lambda { |p|
    thing = lambda { |par|
      case key.call(par)
      when :success; fmap.call(lambda { |other| [par[:success]] + other }).call(many.call(p))
      when :failure; { :success => [] }
      when :progress; { :progress => lambda { |c| thing.call(par[:progress].call(c)) } }
      end }
    thing.call(p) } end

  def self.many1; lambda { |p|
    fmap.call(lambda { |v| [v[0]] + v[1] }).call(pair.call(p).call(many.call(p))) } end
end
