use Net::HTTP::Interfaces;

class Net::HTTP::Request does Request {
    has URL $.url is rw;
    has $.method  is rw;
    has %.header  is rw;
    has %.trailer is rw;
    has $.body    is rw;

    method Stringy {self.Str}
    method Str {
        my $header-str  = ~%!header.kv.map(-> $f, $v { "{$f}: {$v}" }).join("\r\n");
        my $trailer-str = ~%!trailer.kv.map(-> $f, $v { "{$f}: {$v}" }).join("\r\n");
        $ = "{self.start-line}\r\n$header-str\r\n\r\n{$!body // ''}{$trailer-str // ''}";
    }

    method start-line {$ = "{$!method} {self.path} {self.proto}" }

    method proto { 'HTTP/1.1' }

    method path {
        my $rel-url;
        $rel-url ~= $!url.path // '/';
        with $!url.?query    { $rel-url ~= "?{$_}" }
        with $!url.?fragment { $rel-url ~= "#{$_}" }
        $rel-url;
    }
}
