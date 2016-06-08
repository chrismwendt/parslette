require "parslette/version"
require "pp"
require "pry-byebug"

module Parslette
  def self.id; lambda { |x| x } end

  def self.force; lambda { |v| v.class == Proc ? force.call(v.call) : v } end

  def self.foldl; lambda { |f| lambda { |zero| lambda { |t| t.reduce(zero) { |accumulator, a| f.call(accumulator).call(a) } } } } end

  def self.key; lambda { |h| h.keys.first } end

  def self.value; lambda { |h| h[key.call(h)] } end

  def self.satisfy; lambda { |predicate| { :progress => lambda { |a|
    predicate.call(a) ?
      [{ :success => a }] :
      [{ :failure => a.inspect + " did not satisfy the predicate" }] } } } end

  def self.fmap; lambda { |f| lambda { |parser| lambda {
    fparser = force.call(parser)
    case key.call(fparser)
    when :success; { :success => f.call(fparser[:success]) }
    when :failure; fparser
    when :progress; { :progress => lambda { |a| fparser[:progress].call(a).map { |pp| fmap.call(f).call(pp) } } }
    end } } } end

  def self.unit; { :success => nil } end

  def self.pure; lambda { |v| { :success => v } } end

  def self.pair; lambda { |a| lambda { |b| lambda {
    fa = force.call(a)
    case key.call(fa)
    when :success; fmap.call(lambda { |bval| [fa[:success], bval] }).call(force.call(b))
    when :failure; fa
    when :progress; { :progress => lambda { |x| fa[:progress].call(x).map { |pp| pair.call(pp).call(force.call(b)) } } }
    end } } } end

  def self.seqr; lambda { |a| lambda { |b| fmap.call(lambda { |p| p[1] }).call(pair.call(a).call(b)) } } end

  def self.apply; lambda { |a| lambda { |b| fmap.call(lambda { |p| p[0].call(p[1]) }).call(pair.call(a).call(b)) } } end

  def self.alt; lambda { |a| lambda { |b| lambda {
    fa = force.call(a)
    case key.call(fa)
    when :success; fa
    when :failure; force.call(b)
    when :progress; { :progress => lambda { |x| fa[:progress].call(x) + feed.call(force.call(b)).call(x) } }
    end } } } end

  # TODO inline feed since success and failure stop consuming
  def self.feed; lambda { |p| lambda { |c|
    fp = force.call(p)
    case key.call(fp)
    when :success; [fp]
    when :failure; [fp]
    when :progress; fp[:progress].call(c)
    end } } end

  def self.parse; lambda { |parser| lambda { |input|
    foldl.call(lambda { |p| lambda { |c| p.flat_map { |pp| feed.call(pp).call(c) } } }).call([parser]).call(input + [nil]) } } end

  def self.parse_string; lambda { |parser| lambda { |string|
    force.call(parse.call(parser).call(string.split("")))
      .map(&force)
      .map { |r|
        case key.call(r)
        when :success; r
        when :failure; r
        when :progress; { :failure => "Expected more input" }
        end } } } end

  def self.eof; satisfy.call(lambda { |a| a.nil? }) end

  def self.char; lambda { |c| satisfy.call(lambda { |a| a == c }) } end

  def self.match; lambda { |re| satisfy.call(lambda { |a| a =~ re }) } end

  def self.string; lambda { |s|
    foldl
      .call(lambda { |acc| lambda { |c| fmap.call(lambda { |v| v[0] + v[1] }).call(pair.call(acc).call(c)) } })
      .call(fmap.call(lambda { |_| "" }).call(unit))
      .call(s.split("").map &char) } end

  def self.many; lambda { |p|
    alt
      .call(fmap
        .call(lambda { |v| [v[0]] + v[1] })
        .call(pair.call(p).call(lambda { many.call(p) })))
      .call(pure.call([])) } end
end
