# -*- ruby -*-
# vi: set ft=ruby :

class Namae::Parser

token COMMA UWORD LWORD PWORD NICK AND APPELLATION TITLE SUFFIX

expect 0

rule

  names :                { result = [] }
        | name           { result = [val[0]] }
        | names AND name { result = val[0] << val[2] }

  name : word            { result = Name.new(:given => val[0]) }
       | display_order
       | honorific word          { result = val[0].merge(:family => val[1]) }
       | honorific display_order { result = val[1].merge(val[0]) }
       | sort_order

  honorific : APPELLATION { result = Name.new(:appellation => val[0]) }
            | TITLE       { result = Name.new(:title => val[0]) }

  display_order : u_words word opt_suffices opt_titles
       {
         result = Name.new(:given => val[0], :family => val[1],
           :suffix => val[2], :title => val[3])
       }
       | u_words NICK last opt_suffices opt_titles
       {
         result = Name.new(:given => val[0], :nick => val[1],
           :family => val[2], :suffix => val[3], :title => val[4])
       }
       | NICK u_words word word opt_suffices opt_titles
       {
         result = Name.new(:nick => val[0], :given => val[1,2].join(' '),
           :family => val[3], :suffix => val[4], :title => val[5])
       }
       | NICK u_words word opt_suffices opt_titles
       {
         result = Name.new(:nick => val[0], :given => val[1],
           :family => val[2], :suffix => val[3], :title => val[4])
       }
       | u_words NICK von last opt_suffices opt_titles
       {
         result = Name.new(:given => val[0], :nick => val[1],
           :particle => val[2], :family => val[3],
           :suffix => val[4], :title => val[5])
       }
       | u_words von last
       {
         result = Name.new(:given => val[0], :particle => val[1],
          :family => val[2])
       }
       | von last
       {
         result = Name.new(:particle => val[0], :family => val[1])
       }

  sort_order : last COMMA first
       {
         result = Name.new({ :family => val[0], :suffix => val[2][0],
           :given => val[2][1] }, !!val[2][0])
       }
       | von last COMMA first
       {
         result = Name.new({ :particle => val[0], :family => val[1],
           :suffix => val[3][0], :given => val[3][1] }, !!val[3][0])
       }
       | u_words von last COMMA first
       {
         result = Name.new({ :particle => val[0,2].join(' '), :family => val[2],
           :suffix => val[4][0], :given => val[4][1] }, !!val[4][0])
       }
       ;

  von : LWORD
      | von LWORD         { result = val.join(' ') }
      | von u_words LWORD { result = val.join(' ') }

  last : LWORD | u_words

  first : opt_words                 { result = [nil,val[0]] }
        | words opt_comma suffices  { result = [val[2],val[0]] }
        | suffices                  { result = [val[0],nil] }
        | suffices COMMA words      { result = [val[0],val[2]] }

  u_words : u_word
          | u_words u_word { result = val.join(' ') }

  u_word : UWORD | PWORD

  words : word
        | words word { result = val.join(' ') }

  opt_comma : /* empty */ | COMMA
  opt_words : /* empty */ | words

  word : LWORD | UWORD | PWORD

  opt_suffices : /* empty */ | suffices

  suffices : SUFFIX
           | suffices SUFFIX { result = val.join(' ') }

  opt_titles : /* empty */ | titles

  titles : TITLE
         | titles TITLE { result = val.join(' ') }

---- header
require 'strscan'

---- inner

  @defaults = {
    :debug => false,
    :prefer_comma_as_separator => false,
    :comma => ',',
    :stops => ',;',
    :separator => /\s*(\band\b|\&|;)\s*/i,
    :title => /\s*\b(sir|lord|count(ess)?|(hon|judge|sen||rep|representative|senator|gen|adm|col|maj|capt|cmdr|lt|sgt|cpl|pvt|pastor|pr|reverend|rev|elder|deacon|deaconess|father|fr|rabbi|cantor|vicar|prof|do|pharmd|rph|dr|md|ph\.?d)\.?)(\s+|$)/i,
    :suffix => /\s*\b(JR|Jr|jr|SR|Sr|sr|[IVX]{2,})(\.|\b)/,
    :appellation => /\s*\b((mrs?|ms|fr|hr)\.?|miss|herr|frau)(\s+|$)/i
  }

  class << self
    attr_reader :defaults

    def instance
      Thread.current[:namae] ||= new
    end
  end

  attr_reader :options, :input

  def initialize(options = {})
    @options = self.class.defaults.merge(options)
  end

  def debug?
    options[:debug] || ENV['DEBUG']
  end

  def separator
    options[:separator]
  end

  def comma
    options[:comma]
  end

  def stops
    options[:stops]
  end

  def title
    options[:title]
  end

  def suffix
    options[:suffix]
  end

  def appellation
    options[:appellation]
  end

  def prefer_comma_as_separator?
    options[:prefer_comma_as_separator]
  end

  def parse(string)
    parse!(string)
  rescue => e
    warn e.message if debug?
    []
  end

  def parse!(string)
    @input = StringScanner.new(normalize(string))
    reset
    do_parse
  end

  def normalize(string)
    string.scrub.strip
  end

  def reset
    @commas, @words, @initials, @suffices, @yydebug = 0, 0, 0, 0, debug?
    self
  end

  private

  def stack
    @vstack || @racc_vstack || []
  end

  def last_token
    stack[-1]
  end

  def consume_separator
    return next_token if seen_separator?
    @commas, @words, @initials, @suffices = 0, 0, 0, 0
    [:AND, :AND]
  end

  def consume_comma
    @commas += 1
    [:COMMA, :COMMA]
  end

  def consume_word(type, word)
    @words += 1

    case type
    when :UWORD
      @initials += 1 if word =~ /^[[:upper:]]+\b/
    when :SUFFIX
      @suffices += 1
    end

    [type, word]
  end

  def seen_separator?
    !stack.empty? && last_token == :AND
  end

  def suffix?
    !@suffices.zero? || will_see_suffix?
  end

  def will_see_suffix?
    input.peek(8).to_s.strip.split(/\s+/)[0] =~ suffix
  end

  def will_see_initial?
    input.peek(6).to_s.strip.split(/\s+/)[0] =~ /^[[:upper:]]+\b/
  end

  def seen_full_name?
    prefer_comma_as_separator? && @words > 1 &&
      (@initials > 0 || !will_see_initial?) && !will_see_suffix?
  end

  def next_token
    case
    when input.nil?, input.eos?
      nil
    when input.scan(separator)
      consume_separator
    when input.scan(/\s*#{comma}\s*/)
      if @commas.zero? && !seen_full_name? || @commas == 1 && suffix?
        consume_comma
      else
        consume_separator
      end
    when input.scan(/\s+/)
      next_token
    when input.scan(title)
      consume_word(:TITLE, input.matched.strip)
    when input.scan(suffix)
      consume_word(:SUFFIX, input.matched.strip)
    when input.scan(appellation)
      if @words.zero?
        [:APPELLATION, input.matched.strip]
      else
        consume_word(:UWORD, input.matched)
      end
    when input.scan(/((\\\w+)?\{[^\}]*\})*[[:upper:]][^\s#{stops}]*/)
      consume_word(:UWORD, input.matched)
    when input.scan(/((\\\w+)?\{[^\}]*\})*[[:lower:]][^\s#{stops}]*/)
      consume_word(:LWORD, input.matched)
    when input.scan(/(\\\w+)?\{[^\}]*\}[^\s#{stops}]*/)
      consume_word(:PWORD, input.matched)
    when input.scan(/('[^'\n]+')|("[^"\n]+")/)
      consume_word(:NICK, input.matched[1...-1])
    else
      raise ArgumentError,
        "Failed to parse name #{input.string.inspect}: unmatched data at offset #{input.pos}"
    end
  end

  def on_error(tid, value, stack)
    raise ArgumentError,
      "Failed to parse name: unexpected '#{value}' at #{stack.inspect}"
  end

# -*- racc -*-
