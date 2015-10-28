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
    has %!connections;

    # mix in a proxy role and the host and request target url are set appropriately automatically
    # method proxy { ::('Net::HTTP::URL').new("http://proxy-lord.org") }

    method round-trip(Request $req, Response ::RESPONSE = Net::HTTP::Response --> Response) {
        self.hijack($req);

        # MAKE REQUEST
        my $socket = self.get-socket($req);
        $socket.write($req.?raw // $req.Str.encode);

        my $status-line  = $socket.get(:bin).unpack('A*');
        my @header-lines = $socket.lines(:bin).map({$_ or last})>>.unpack('A*');
        my %header andthen do { %header{hc(.[0])}.append(.[1]) for @header-lines>>.split(/':' \s+/, 2) }

        # these belong in a socket specific hijack method
        with %header<Content-Length> { $socket.content-length = $_[0] }
        with %header<Connection>     { $socket.keep-alive //= not @$_ ~~ /[:i close]/ }

        # this chunked conditional should be abstracted away in IO::Socket::HTTP itself, or by supply methods
        my $body-supply = %header.grep(*.key.lc eq 'transfer-encoding').first({$_.value ~~ /[:i chunked]/})
            ?? $socket.supply-dechunked !! $socket.supply;

        my $body = buf8.new andthen $body-supply.tap: { $body ~= $_ }

        my $res = RESPONSE.new(:$status-line, :$body, :%header);
        $res does role { has $.socket = $socket };

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

        $header<Connection> //= 'keep-alive';
    }

    method get-socket(Request $req) {
        with %!connections{$req.header<Host>.lc} -> $conns {
            my $reusable = @$conns.grep(*.keep-alive.so).first(*);
            return $reusable if $reusable;
        }
        %!connections{$req.header<Host>.lc} = self.dial($req) but IO::Socket::HTTP;
    }
}
