use Net::HTTP::Interfaces;
use Net::HTTP::Utils;

# defaults
use Net::HTTP::Dialer;
use Net::HTTP::Response;
use Net::HTTP::Request;

# Higher level HTTP transport for creating a custom HTTP::Client
# similar to ::GET and ::POST but made for reuse (connection caching and other state control)

class Net::HTTP::Transport does RoundTripper {
    also does Net::HTTP::Dialer;

    # mix in a proxy role and the host and request target url are set appropriately automatically
    # method proxy { ::('Net::HTTP::URL').new("http://proxy-lord.org") }

    method round-trip(Request $req, Response ::RESPONSE = Net::HTTP::Response --> Response) {
        self.hijack($req);

        # MAKE REQUEST
        my $socket = self.dial($req) but IO::Socket::HTTP;
        $socket.write($req.?raw // $req.Str.encode);

        # GET AND PARSE RESPONSE
        # Realistically the header decoding will go into its own method so that HPACK and other
        # compressions can be applied as needed. For now (with just HTTP1.1) it helps to visualize
        # by having it grouped nicely here.
        my $status-line  = $socket.get(:bin).unpack('A*');
        my @header-lines = $socket.lines(:bin).map({$_ or last})>>.unpack('A*');
        my %header andthen do { %header{hc(.[0])}.append(.[1]) for @header-lines>>.split(/':' \s+/, 2) }

        # with %header<Content-Length> { $socket.content-length = +$_ }
        # with %header<Connection>     { $socket.keep-alive //= $res.header<Connection> ~~ /[:i close]/ }

        my $body = buf8.new andthen $socket.supply.tap: { $body ~= $_ }
        my $res  = RESPONSE.new(:$status-line, :$body, :%header);

        self.hijack($res);

        $res;
    }

    # no private multi methods :(
    multi method hijack(Request $req) {
        my $header := $req.header;
        my $proxy   = self.?proxy;

        # set the host field to either an optional proxy's url host or the request's url host
        $header<Host>  = $proxy ?? $proxy.host !! $req.url.host;

        # override any possible default start-line() method behavior of using a relative request target url if $proxy
        $req does role :: { method path {$ = ~$req.url } } if $proxy;

        # automatically handle content-length setting
        $header<Content-Length> = !$req.body ?? 0 !! $req.body ~~ Blob ?? $req.body.bytes !! $req.body.encode.bytes;

        # default to closed connections
        $header<Connection> //= 'close';
    }
    multi method hijack(Response $res) {
        my $header := $res.header;
        my $body   := $res.body;

        $body = ChunkedReader($body) if $header.grep(*.key.lc eq 'transfer-encoding').first({$_.value ~~ /[:i chunked]/});

        # content-type and hpack decoding would also go here
    }
}
