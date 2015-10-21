use Net::HTTP::Interfaces;
use Net::HTTP::Utils;
use Net::HTTP::Dialer;

# Higher level HTTP transport for creating a custom HTTP::Client
# similar to ::GET and ::POST but made for reuse (connection caching and other state control)
class Net::HTTP::Transport does RoundTripper {
    also does Net::HTTP::Dialer;

    method round-trip(Request $req --> Response) { }
}
