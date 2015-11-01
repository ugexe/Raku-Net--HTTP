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
    has $!lock = Lock.new;

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
        with %header<Content-Length>    { $socket.content-length = $_[0] }
        with %header<Connection>        { $socket.keep-alive = not @$_ ~~ /[:i close]/ }
        with %header<Transfer-Encoding> { $socket.is-chunked = so @$_.first({$_ ~~ /[:i chunked]/}) }

        my $body = buf8.new andthen $socket.supply.tap: { $body ~= $_ }

        my $res = RESPONSE.new(:$status-line, :$body, :%header);

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
        $!lock.protect({
            my $connection;
            my $usable := %!connections{$*THREAD.id}{$req.header<Host>.lc}{$req.url.scheme};

            with $usable -> $conns {
                for $conns.grep(*.keep-alive.so) -> $sock {
                    # this needs a timeout, but spawning another thread to do it causes problems
                    await $sock.promise;

                    # crazy attempt to only assign sockets that are still open (should be tied into $sock.promise)
                    try {
                        $sock.read(0);
                        # if the socket is closed it will give a different error for read(0)
                        CATCH { when /'Out of range'/ { $connection = $sock and last; } }
                    }
                }
            }

            if $connection.not && $usable.not {
                $connection = self.dial($req) but IO::Socket::HTTP;
                $usable.append($connection);
            }

            $connection;
        });
    }
}
