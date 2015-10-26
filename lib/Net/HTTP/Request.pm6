use Net::HTTP::Interfaces;
use Net::HTTP::Utils;

class Net::HTTP::Request does Request {
    has URL $.url is rw;
    has $.method  is rw;
    has %.header  is rw;
    has %.trailer is rw;
    has $.body    is rw;
    has $.nl = "\r\n";

    method proto { 'HTTP/1.1' }

    method start-line  {$ = "{$!method} {self.path} {self.proto}" }

    method Stringy {self.Str}
    method Str { $ = "{self.start-line}{$!nl}{self.header-str}{$!nl}{$!nl}{self.body-str}{self.trailer-str}" }
    method str { self.Str }
    method header-str  { header2str(%!header)  // ''    }
    method body-str    { body2str($!body)      // ''    }
    method trailer-str { header2str(%!trailer) // ''    }


    method raw { with $!nl.ords -> @sep {
        $ = Buf[uint8].new( grep * ~~ Int,
        |self.start-line.ords,
        |@sep,
        |self.header-raw.Slip,
        |@sep,
        |@sep,
        |self.body-raw,
        |self.trailer-raw,
    ) } }
    method header-raw  { Buf.new(self.header-str.ords)  }
    method body-raw    { body2raw($!body)               }
    method trailer-raw { Buf.new(self.trailer-str.ords) }

    method path {
        my $rel-url;
        $rel-url ~= $!url.path // '/';
        with $!url.?query    { $rel-url ~= "?{~$_}" }
        with $!url.?fragment { $rel-url ~= "#{~$_}" }
        $rel-url;
    }

    sub header2str(%_) { $ = ~%_.kv.map( -> $f, $v { "{hc ~$f}: {~$v}" }).join("\r\n") }
    sub body2str($_)   { $_ ~~ Buf ?? $_.unpack("A*") !! $_  }
    sub body2raw($_)   { $_ ~~ Buf ?? $_ !! $_ ~~ Str ?? $_.chars ?? Buf[uint8].new($_.ords) !! '' !! '' }
}
