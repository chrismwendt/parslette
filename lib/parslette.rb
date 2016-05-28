require "parslette/version"
require "pp"

module Parslette
  def self.id; lambda { |x| x } end

  def self.ex
    is_alpha = lambda { |a| a <= 'z' && 'a' <= a }
    toi = lambda { |r| r.to_i }
    alpha = satisfy.call(is_alpha)
    z = pair.call(alpha).call(alpha)
    pp(parse_string.call(z).call("hi"))
    pp(parse_string.call(char.call('h')).call("h"))
    pp(parse_string.call(string.call("hello")).call("hell"))
  end

  def self.foldl; lambda { |f| lambda { |zero| lambda { |t| t.reduce(zero) { |accumulator, a| f.call(accumulator).call(a) } } } } end

  def self.foldr; lambda { |f| lambda { |a| lambda { |bs| foldl.call(lambda { |g| lambda { |b| lambda { |x| g.call(f.call(b).call(x)) } } }).call(id).call(bs).call(a) } } } end

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

  def self.pair; lambda { |a| lambda { |b|
    case key.call(a)
    when :success; fmap.call(lambda { |bval| [a[:success], bval] }).call(b)
    when :failure; a
    when :progress; { :progress => lambda { |x| pair.call(a[:progress].call(x)).call(b) } }
    end } } end

  def self.parse; lambda { |parser| lambda { |input|
    f = lambda { |accumulator| lambda { |a|
      case key.call(accumulator)
      when :success; { :failure => "Extra input starting at " + a.inspect }
      when :failure; accumulator
      when :progress; value.call(accumulator).call(a)
      end } }

    foldl.call(f).call(parser).call(input) } } end

  def self.parse_string; lambda { |parser| lambda { |string|
    r = parse.call(parser).call(string.split(""))
    case key.call(r)
    when :success; r
    when :failure; r
    when :progress; { :failure => "Expected more input" }
    end } } end

  def self.char; lambda { |c| satisfy.call(lambda { |a| a == c }) } end

  def self.string; lambda { |s|
    fmap
      .call(lambda { |x| x.string })
      .call(foldl
        .call(lambda { |sb| lambda { |c| fmap.call(lambda { |aa| aa[0] << aa[1] }).call(pair.call(sb).call(c)) } })
        .call(fmap.call(lambda { |x| StringIO.new }).call(unit))
        .call(s.split("").map &char)) } end
end
