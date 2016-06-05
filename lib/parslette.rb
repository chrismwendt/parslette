require "parslette/version"
require "pp"

module Parslette
  def self.id; lambda { |x| x } end

  def self.digit; satisfy.call(lambda { |c| "0" <= c && c <= "9" }) end

  def self.ex
    is_alpha = lambda { |a| a <= 'z' && 'a' <= a }
    toi = lambda { |r| r.to_i }
    alpha = satisfy.call(is_alpha)
    z = pair.call(alpha).call(alpha)
    pp(parse_string.call(z).call("hi"))
    pp(parse_string.call(char.call('h')).call("h"))
    pp(parse_string.call(string.call("hello")).call("hell"))
    pp(parse_string.call(alt.call(string.call("hello")).call(string.call("hell"))).call("hell"))
    pp(parse_string.call(apply.call(fmap.call(lambda { |a| lambda { |b| a.to_i + b.to_i } }).call(digit)).call(digit)).call("23"))
  end

  def self.json
    spaces = match.call(/\s/)
  end

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
    fmap
      .call(lambda { |x| x.string })
      .call(foldl
        .call(lambda { |sb| lambda { |c| fmap.call(lambda { |aa| aa[0] << aa[1] }).call(pair.call(sb).call(c)) } })
        .call(fmap.call(lambda { |_| StringIO.new }).call(unit))
        .call(s.split("").map &char)) } end
end
