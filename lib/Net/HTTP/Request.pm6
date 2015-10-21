use Net::HTTP::Interfaces;

class Net::HTTP::Request does Request {
    has URL $.url is rw;
    has $.method  is rw;
    has %.header  is rw; # HTTP::UserAgent::Request has `method hash` so should be interchangable already
    has %.trailer is rw;
    has $.body    is rw;

    method Stringy {self.Str}
    method Str {
        my $header-str  = ~%!header.kv.map(-> $f, $v { "{$f}: {$v}" }).join("\r\n");
        my $trailer-str = ~%!trailer.kv.map(-> $f, $v { "{$f}: {$v}" }).join("\r\n");
        $ = "{self.start-line}\r\n$header-str\r\n\r\n{$!body // ''}{$trailer-str // ''}";
    }

    method start-line {$ = "{$!method} {URL-ABS2REL($!url)} HTTP/1.1"}

    # this could go in the URL module itself but doing it outside of it and in the transport layer
    # means we can still use extremely basic URL interfaces that don't have such methods
    sub URL-ABS2REL(URL $url) {
        my $rel-url;
        $rel-url ~= $url.path // '/';
        with $url.query    { $rel-url ~= "?{$_}" }
        with $url.fragment { $rel-url ~= "#{$_}" }
        $rel-url;
    }
}
