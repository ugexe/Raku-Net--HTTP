use Net::HTTP::Interfaces;
use Net::HTTP::Dialer;
use Net::HTTP::Request;
use Net::HTTP::Response;
use Net::HTTP::URL;
use Net::HTTP::Utils;

class Net::HTTP::GET does RoundTripper {
    also does Net::HTTP::Dialer;

    # `GET` is already in the name, so lets just use CALL-ME() to access this namespace like a routine
    proto method CALL-ME(|) {*}
    multi method CALL-ME(Str $abs-url --> Response) {
        my $url = Net::HTTP::URL.new($abs-url);
        my $req = Net::HTTP::Request.new(:$url, :method<GET>);
        samewith($req);
    }
    multi method CALL-ME(Request $req --> Response) { self.round-trip($req) }

    # mix in a proxy role and the host and request target url are set appropriately automatically
    # method proxy { ::('Net::HTTP::URL').new("http://proxy-lord.org") }

    method round-trip(Request $req --> Response) {
        self!hijack($req);

        # MAKE REQUEST
        my $socket = self.dial($req) but IO::HTTPReader;
        $socket.print(~$req);

        # GET AND PARSE RESPONSE
        my @header-lines = $socket.header-supply.lines.grep(*.so).eager;
        # first line is the status line... maybe it should not be part of header-supply?
        my %rep-header = @header-lines[1..*].map({ my ($h, $f) = $_.split(/':' \s+/, 2); $h.lc => $f // '' });
        # todo: look at content-length and pass into body-supply reader?

        # We should return at this point and let the body continue to fill a buffer
        # or maybe not even read the rest of the socket depending on what the headers 
        # say and if any connections are waiting for that socket.
        my $rep-body = $socket.body-supply;
        $rep-body = $rep-body>>.decode.join; # TEMPORARY, content decoding belongs elsewhere
        $socket.close() if %rep-header<connection> ~~ /[:i close]/;

        my $rep = Net::HTTP::Response.new(:body($rep-body), :header(%rep-header));
    }
    
    
    method !hijack(Request $req) {
        my $header := $req.header;
        my $proxy   = self.?proxy;

        # set the host field to either an optional proxy's url host or the request's url host
        $header<host>  = $proxy ?? $proxy.host !! $req.url.host;

        # override any possible default start-line() method behavior of using a relative request target url if $proxy
        $req does role :: { method start-line {$ = "{~$req.method} {~$req.url} HTTP/1.1"} } if $proxy;

        # automatically handle content-length setting
        $header<content-length> = !$req.body ?? 0 !! $req.body ~~ Buf ?? $req.body.bytes !! $req.body.encode.bytes;

        # default to closed connections
        $header<connection> //= 'Close';
    }
}
