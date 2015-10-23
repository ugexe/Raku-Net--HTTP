use Net::HTTP::Interfaces;
use Net::HTTP::Dialer;
use Net::HTTP::Request;
use Net::HTTP::Response;
use Net::HTTP::URL;
use Net::HTTP::Utils;

# Most of this will be moved into Transport, this is just a convienient starting spot

class Net::HTTP::GET does RoundTripper {
    also does Net::HTTP::Dialer;

    # `GET` is already in the name, so lets just use CALL-ME() to access this namespace like a routine
    proto method CALL-ME(|) {*}
    multi method CALL-ME(Str $abs-url, |c --> Response) {
        my $url = Net::HTTP::URL.new($abs-url);
        my $req = Net::HTTP::Request.new(:$url, :method<GET>);
        samewith($req, |c);
    }
    multi method CALL-ME(Request $req, Response ::RESPONSE = Net::HTTP::Response --> Response) {
        self.round-trip($req, RESPONSE) 
    }

    # mix in a proxy role and the host and request target url are set appropriately automatically
    # method proxy { ::('Net::HTTP::URL').new("http://proxy-lord.org") }

    method round-trip(Request $req, Response ::RESPONSE = Net::HTTP::Response --> Response) {
        self!hijack($req);

        # MAKE REQUEST
        my $socket = self.dial($req) but IO::Socket::HTTP;
        $socket.print(~$req);

        # GET AND PARSE RESPONSE
        my ($start-line, @header) = $socket.lines(:bin).map: {$_ or last}
        my %res-header = @header>>.unpack('A*').map({ my ($h, $f) = .split(/':' \s+/, 2); $h.lc => $f // '' });
        my $res-body   = $socket.recv(:bin);

        $res-body = $res-body.decode.join; # TEMPORARY, content decoding belongs elsewhere

        $socket.close() if %res-header<connection>.defined && %res-header<connection> ~~ /[:i close]/;
        my $res = RESPONSE.new(:body($res-body), :header(%res-header));
    }

    
    method !hijack(Request $req) {
        my $header := $req.header;
        my $proxy   = self.?proxy;

        # set the host field to either an optional proxy's url host or the request's url host
        $header<host>  = $proxy ?? $proxy.host !! $req.url.host;

        # override any possible default start-line() method behavior of using a relative request target url if $proxy
        $req does role :: { method path {$ = ~$req.url } } if $proxy;

        # automatically handle content-length setting
        $header<content-length> = !$req.body ?? 0 !! $req.body ~~ Buf ?? $req.body.bytes !! $req.body.encode.bytes;

        # default to closed connections
        $header<connection> //= 'Close';
    }
}
