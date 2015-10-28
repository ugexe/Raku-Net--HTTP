use Net::HTTP::Interfaces;
use Net::HTTP::Transport;
use Net::HTTP::Request;
use Net::HTTP::Response;
use Net::HTTP::URL;

# This will be changed to access the Client instead of the Transport later
class Net::HTTP::GET {
    proto method CALL-ME(|) {*}
    multi method CALL-ME(Str $abs-url, |c --> Response) {
        my $url = Net::HTTP::URL.new($abs-url);
        my $req = Net::HTTP::Request.new(:$url, :method<GET>, header => :User-Agent<perl6-net-http>);
        samewith($req, |c);
    }
    multi method CALL-ME(Request $req, Response ::RESPONSE = Net::HTTP::Response --> Response) {
        state $transport = Net::HTTP::Transport.new;

        # This is to help test the thread-safeness of Transport.
        # Ultimately the user will be able to just wrap their own 
        # Request with start { } if they wish, or use as-is for a
        # normal blocking http request.
        $ = await start { $transport.round-trip($req, RESPONSE) }
    }
}
